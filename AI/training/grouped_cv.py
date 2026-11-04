"""Initial fixed-parameter grouped cross-validation; no independent test claim."""
from collections import Counter
from pathlib import Path
import hashlib
import numpy as np
from sklearn.linear_model import LogisticRegression
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import Normalizer
from sklearn.model_selection import StratifiedGroupKFold
from sklearn.metrics import accuracy_score, f1_score, confusion_matrix, classification_report
from analyzers.dinov3_features import MODEL_ID,MODEL_REVISION
from .dataset import SCHEMA,write_json
from .train import read_training_data

def train_grouped_cv(directory, validate_only=False):
    directory=Path(directory)
    grouped,classes,review=read_training_data(directory,enforce_holdout=False)
    rows=[row for split in ('train','val','test') for row in grouped[split]]
    x=np.stack([row[0] for row in rows]);y=np.array([row[1] for row in rows]);groups=np.array([row[2] for row in rows])
    for label in classes:
        if len(set(groups[y==label]))<3:raise ValueError('3분할 교차검증에는 각 등급에서 서로 다른 인물 최소 3명이 필요합니다.')
    feature_subjects={}
    for vector,_,subject in rows:
        digest=hashlib.sha256(vector.tobytes()).hexdigest()
        if feature_subjects.setdefault(digest,subject)!=subject:raise ValueError('동일 특징이 서로 다른 인물에 중복됐습니다.')
    folds=None
    for seed in range(42,142):
        proposed=list(StratifiedGroupKFold(n_splits=3,shuffle=True,random_state=seed).split(x,y,groups))
        if all(all(len(set(groups[train][y[train]==c]))>=2 and len(set(groups[test][y[test]==c]))>=1 for c in classes) for train,test in proposed):folds=proposed;break
    if folds is None:raise ValueError('등급별 인물이 포함된 교차검증 분할을 구성하지 못했습니다.')
    plan=[{'train_subjects':sorted(set(groups[tr])),'held_out_subjects':sorted(set(groups[te]))} for tr,te in folds]
    if validate_only:
        return {'classes':classes,'samples':len(y),'subjects':len(set(groups)),'protocol':'3-fold grouped CV','seed':seed}
    write_json(directory/'cv-plan.json',{'protocol':'3-fold stratified grouped CV; fixed C=1, threshold=0.6','seed':seed,'folds':plan,'partition_selection':'label coverage only; no feature scores','independent_external_test':False})
    predicted=np.empty(len(y),dtype=object);baseline=np.empty(len(y),dtype=object);confident=np.zeros(len(y),dtype=bool)
    for tr,te in folds:
        assert not set(groups[tr]) & set(groups[te])
        model=make_pipeline(Normalizer(),LogisticRegression(C=1,class_weight='balanced',max_iter=2000,random_state=42))
        model.fit(x[tr],y[tr]);predicted[te]=model.predict(x[te]);confident[te]=model.predict_proba(x[te]).max(axis=1)>=.6
        baseline[te]=Counter(y[tr]).most_common(1)[0][0]
    final=make_pipeline(Normalizer(),LogisticRegression(C=1,class_weight='balanced',max_iter=2000,random_state=42));final.fit(x,y);clf=final.steps[-1][1]
    artifact={'schema_version':1,'task':'upper_arm_contour_visibility','feature_schema':SCHEMA,'model_id':MODEL_ID,'model_revision':MODEL_REVISION,'classes':clf.classes_.tolist(),'coefficients':clf.coef_.tolist(),'intercepts':clf.intercept_.tolist(),'abstain_threshold':.6,'experimental':True}
    report={'status':'trained_experimental','protocol':'3-fold grouped cross-validation; fixed hyperparameters','independent_test':False,'classes':classes,'samples':len(y),'subjects':len(set(groups)),'label_counts':dict(Counter(y)),
        'out_of_fold_accuracy':float(accuracy_score(y,predicted)),'out_of_fold_macro_f1':float(f1_score(y,predicted,labels=classes,average='macro',zero_division=0)),
        'majority_baseline_accuracy':float(accuracy_score(y,baseline)),'confusion_matrix':confusion_matrix(y,predicted,labels=classes).tolist(),
        'per_class':classification_report(y,predicted,labels=classes,output_dict=True,zero_division=0),'accepted_coverage':float(confident.mean()),'review_counts':review,
        'limitations':['Small human-reviewed dataset; no independent external test.','Photo contour visibility only; not muscle mass, strength, posture score or health.','Final deployed experimental model is fitted on all reviewed samples; CV scores describe held-out fold predictions.']}
    write_json(directory/'model.json',artifact);write_json(directory/'training-report.json',report)
    return report
