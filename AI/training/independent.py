"""Evaluate a frozen classifier only after explicit identity review and overlap checks."""
import hashlib
import json
from pathlib import Path
import numpy as np
from sklearn.metrics import accuracy_score, f1_score, confusion_matrix
from analyzers.contour_classifier import ContourClassifier
from .dataset import AnnotationStore, write_json
from .train import read_training_data


def freeze_reference(directory, model_path, training_directory):
    store=AnnotationStore(directory)
    if store.dataset.get('purpose')!='independent_test' or store.annotations:
        raise ValueError('라벨 저장 전의 독립 시험 예약 묶음만 모델을 고정할 수 있습니다.')
    if 'evaluation_reference' in store.dataset:
        raise ValueError('이미 고정한 평가 모델은 바꾸지 않습니다.')
    model=ContourClassifier(model_path)
    artifact=json.loads(Path(model_path).read_text())
    source={key:hashlib.sha256((Path(training_directory)/filename).read_bytes()).hexdigest()
            for key,filename in [('annotation_sha256','annotations.json'),('training_dataset_sha256','dataset.json')]}
    if any(artifact.get(k)!=v for k,v in source.items()):
        raise ValueError('모델과 학습 출처가 일치하지 않습니다.')
    raw=Path(model_path).read_bytes()
    if hashlib.sha256(raw).hexdigest()!=model.model_sha256:
        raise ValueError('모델이 작업 중 변경됐습니다.')
    frozen=store.directory/'frozen-model.json'
    if frozen.exists():
        raise ValueError('기존 고정 모델 파일은 덮어쓰지 않습니다.')
    frozen.write_bytes(raw)
    dataset=dict(store.dataset,evaluation_reference={**source,'model_sha256':model.model_sha256,
                 'frozen_before_labels':True,'model_file':'frozen-model.json'})
    write_json(store.directory/'dataset.json',dataset)
    return dataset['evaluation_reference']


def evaluate_independent(model_path, training_directory, test_directory, output, *, identities_confirmed=False):
    identity_record=Path(test_directory)/'identity-review.json'
    if identity_record.exists():
        audit=json.loads(identity_record.read_text())
        if (not isinstance(audit,dict) or audit.get('status')!='confirmed_independent'
                or audit.get('dataset_sha256')!=hashlib.sha256((Path(test_directory)/'dataset.json').read_bytes()).hexdigest()):
            raise ValueError('인물 중복·미확인 또는 자료와 불일치하는 검수 기록이 있어 독립 평가를 차단했습니다.')
    if not identities_confirmed:
        raise ValueError('실제 인물 동일성·학습 자료와의 독립성을 사람이 먼저 확인해야 합니다.')
    output = Path(output)
    if output.exists():
        raise ValueError('기존 평가 보고서를 덮어쓰지 않습니다.')
    model = ContourClassifier(model_path)
    test_store=AnnotationStore(test_directory)
    if test_store.dataset.get('purpose')=='independent_test':
        reference=test_store.dataset.get('evaluation_reference',{})
        if reference.get('frozen_before_labels') is not True or reference.get('model_sha256')!=model.model_sha256:
            raise ValueError('라벨 저장 전에 고정한 시험 모델과 일치하지 않습니다.')
    artifact = json.loads(Path(model_path).read_text())
    for key, filename in [('annotation_sha256','annotations.json'),('training_dataset_sha256','dataset.json')]:
        if artifact.get(key) != hashlib.sha256((Path(training_directory)/filename).read_bytes()).hexdigest():
            raise ValueError('모델에 기록된 학습 자료와 일치하지 않습니다. 출처를 기록한 모델로 평가하세요.')
    train_groups, _, train_counts = read_training_data(training_directory, enforce_holdout=False)
    test_groups, classes, test_counts = read_training_data(test_directory, enforce_holdout=False, allow_reserved_test=True)
    if train_counts['pending'] or test_counts['pending']:
        raise ValueError('학습·시험 자료의 검수를 먼저 완료하세요.')
    training = [r for rows in train_groups.values() for r in rows]
    test = [r for rows in test_groups.values() for r in rows]
    if set(classes) != set(model.labels):
        raise ValueError('시험 자료에는 모델의 모든 등급이 필요합니다.')
    source_hashes = []
    for directory in (training_directory, test_directory):
        store = AnnotationStore(directory)
        source_hashes.append({entry['source_sha256'] for entry in store.entries.values()})
    if source_hashes[0] & source_hashes[1]:
        raise ValueError('학습·시험 자료에 같은 원본 사진이 있습니다. ID 변경으로 분리할 수 없습니다.')
    if {r[2] for r in training} & {r[2] for r in test}:
        raise ValueError('학습·시험에 같은 인물 ID가 있습니다.')
    digests = [{hashlib.sha256(r[0].tobytes()).hexdigest() for r in rows} for rows in (training,test)]
    if digests[0] & digests[1]:
        raise ValueError('학습·시험에 같은 특징이 있습니다.')
    predictions = [model.predict(row[0]) for row in test]
    truth = np.array([r[1] for r in test])
    candidates = np.array([r['candidate_label'] for r in predictions])
    accepted = np.array([r['status']=='predicted' for r in predictions])
    report = {'protocol':'frozen model; independently reviewed test collection',
              'model_sha256':model.model_sha256,'identity_confirmation':'human_declaration',
              'identity_automatically_verified':False,'samples':len(test),
              'subject_groups':len({r[2] for r in test}), 'classes':model.labels,
              'label_counts':{c:int(sum(truth==c)) for c in model.labels},
              'candidate_accuracy':float(accuracy_score(truth,candidates)),
              'candidate_macro_f1':float(f1_score(truth,candidates,labels=model.labels,average='macro',zero_division=0)),
              'confusion_matrix':confusion_matrix(truth,candidates,labels=model.labels).tolist(),
              'accepted_coverage':float(accepted.mean()),
              'accepted_accuracy':float(accuracy_score(truth[accepted],candidates[accepted])) if accepted.any() else None,
              'threshold':model.threshold,'clinical_validity':False,
              'limitations':['No automatic identity verification; renamed IDs cannot prove different people.',
                             'Exact file/feature checks cannot detect all near-duplicate images.',
                             'One test collection does not establish general or clinical accuracy.']}
    write_json(output,report)
    return report
