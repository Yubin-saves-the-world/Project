"""Report human label consistency without modifying labels or training a model."""
import argparse
import hashlib
import json
from pathlib import Path
import sys
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
from training.dataset import AnnotationStore,write_json,LABELS
from training.reviewed_crops import validate_release


def score(directory, output):
    directory,output=Path(directory).resolve(),Path(output).resolve()
    for path in (directory,output):
        if not path.is_relative_to(ROOT/'.runtime') or any(x.startswith('quarantine_web_') for x in path.parts):
            raise ValueError('격리되지 않은 AI/.runtime만 허용합니다.')
    if output.exists():raise ValueError('기존 보고서를 덮어쓰지 않습니다.')
    store=AnnotationStore(directory)
    if store.dataset.get('purpose')!='label_audit':raise ValueError('라벨 재검수 묶음만 비교합니다.')
    validate_release(store)
    reference=json.loads((directory/'audit-reference.json').read_text())
    if (not store.entries or set(reference.get('entries',{}))!=set(store.entries)
            or any(v.get('previous_label') not in LABELS for v in reference['entries'].values())):
        raise ValueError('원래 라벨과 재검수 항목의 대응이 올바르지 않습니다.')
    source=Path(reference['source_directory']).resolve()
    if not source.is_relative_to(ROOT/'.runtime') or any(x.startswith('quarantine_web_') for x in source.parts):
        raise ValueError('잘못된 원본 라벨 경로입니다.')
    if hashlib.sha256((source/'annotations.json').read_bytes()).hexdigest()!=reference['source_annotation_sha256']:
        raise ValueError('원본 라벨이 변경됐습니다. 재검수 출처를 확인하세요.')
    if set(store.annotations)!=set(store.entries):raise ValueError('모든 항목의 재검수를 먼저 저장하세요.')
    changes=[];counts={label:{'items':0,'same':0} for label in LABELS};matrix={a:{b:0 for b in (*LABELS,'exclude')} for a in LABELS}
    for key,old in reference['entries'].items():
        a=store.annotations[key]
        if not a.get('reviewed') or a['label'] not in (*LABELS,'exclude') or a.get('split')!='test':
            raise ValueError('유효한 사람 검수가 필요합니다.')
        previous,new=old['previous_label'],a['label'];counts[previous]['items']+=1;counts[previous]['same']+=previous==new;matrix[previous][new]+=1
        if previous!=new:changes.append({'audit_entry_id':key,'source_entry_id':old['source_entry_id'],'previous_label':previous,'new_label':new})
    same=sum(v['same'] for v in counts.values())
    report={'purpose':'human label consistency, not classifier accuracy','samples':len(store.entries),'unchanged':same,
            'agreement_fraction':same/len(store.entries),'per_previous_label':counts,'confusion_matrix':matrix,
            'changed_items':changes,'original_labels_modified':False,'model_trained':False,
            'next_step':'불일치는 사람이 원본을 비교해 판단하세요. 새 라벨이 자동 정답이 되는 것은 아닙니다.'}
    write_json(output,report);return report


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--dataset',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
    try:print(json.dumps(score(a.dataset,a.output),ensure_ascii=False,indent=2))
    except (OSError,ValueError) as exc:raise SystemExit(str(exc))
