"""Prepare manually approved, clothed arm photos without full-body measurement gates."""
import argparse
import hashlib
import json
from pathlib import Path
import sys

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))

def prepare(manifest_path, output):
    import mediapipe as mp
    import numpy as np
    from analyzers.dinov3_features import DinoFeatureExtractor, upper_arm_box, MODEL_REVISION
    from training.dataset import normalize_image, feature_vector, write_json, SCHEMA
    manifest_path=Path(manifest_path).resolve();output=Path(output).resolve()
    for path in [manifest_path,output]:
        if not path.is_relative_to(ROOT/'.runtime') or any(p.startswith('quarantine_web_') for p in path.parts):
            raise ValueError('격리 자료를 사용하지 않고 AI/.runtime의 새 검수 자료만 사용합니다.')
    if output.exists():raise ValueError('기존 데이터셋은 덮어쓰지 않습니다.')
    rows=json.loads(manifest_path.read_text())
    if not rows or any(row.get('review_status')!='approved_for_arm_labeling' or not row.get('review_reason') for row in rows):
        raise ValueError('원본 전체의 명시적인 사전검수 승인이 필요합니다.')
    for row in rows:
        path=(manifest_path.parent/row['file']).resolve()
        if not path.is_relative_to(manifest_path.parent) or hashlib.sha256(path.read_bytes()).hexdigest()!=row['sha256']:
            raise ValueError('검수한 원본과 일치하지 않습니다.')
    model=json.loads((ROOT/'.runtime/model.json').read_text())['path']
    dino=DinoFeatureExtractor(model,device='cpu',local_only=True)
    output.mkdir(parents=True);entries=[];failures=[]
    with mp.solutions.pose.Pose(static_image_mode=True,model_complexity=1,min_detection_confidence=.7) as pose:
        for row in rows:
            path=manifest_path.parent/row['file'];image=normalize_image(path)
            boxes=[]
            if row.get('manual_boxes'):
                from PIL import Image
                with Image.open(path) as original:ow,oh=original.size
                for manual in row['manual_boxes']:
                    coordinates=manual['box']
                    if not manual.get('visually_reviewed') or len(coordinates)!=4:
                        raise ValueError('수동 영역의 육안 확인과 좌표가 필요합니다.')
                    x0,y0,x1,y1=coordinates
                    if not (0<=x0<x1<=ow and 0<=y0<y1<=oh):raise ValueError('잘못된 수동 영역')
                    box=[round(x0*image.width/ow),round(y0*image.height/oh),round(x1*image.width/ow),round(y1*image.height/oh)]
                    boxes.append(('visible_upper_arm',box,'assistant_manual_roi'))
            else:
                result=pose.process(np.asarray(image))
                if not result.pose_landmarks:
                    failures.append({'image_name':path.name,'code':'NO_POSE'});continue
                points=result.pose_landmarks.landmark
                lm={name.lower():{'x':points[value].x,'y':points[value].y,'visibility':points[value].visibility}
                    for name,value in mp.solutions.pose.PoseLandmark.__members__.items()}
                for side in ['left','right']:
                    box=upper_arm_box(lm,side,*image.size,min_visibility=.7)
                    if box is None:
                        failures.append({'image_name':path.name,'part':side+'_upper_arm','code':'LOW_CONFIDENCE'});continue
                    boxes.append((side+'_upper_arm',box,'pose_shoulder_elbow'))
            sha=row['sha256'];image_rel='images/'+sha+'.jpg';(output/'images').mkdir(exist_ok=True);image.save(output/image_rel,quality=95)
            for part,box,method in boxes:
                if min(box[2]-box[0],box[3]-box[1])<128:
                    failures.append({'image_name':path.name,'part':part,'code':'LOW_CROP_RESOLUTION'});continue
                crop=image.crop(box);values,_=dino.extract(crop)
                vector=feature_vector({'cls':values['cls'].tolist(),'patch_mean':values['patch_mean'].tolist()})
                key=hashlib.sha256((sha+part+json.dumps(list(box))+MODEL_REVISION).encode()).hexdigest()[:24]
                crop_rel='crops/'+key+'.jpg';feat_rel='features/'+key+'.npz'
                for sub in ['crops','features']:(output/sub).mkdir(exist_ok=True)
                crop.save(output/crop_rel,quality=95);np.savez_compressed(output/feat_rel,vector=vector)
                entries.append({'id':key,'image_name':path.name,'image':image_rel,'crop':crop_rel,'features':feat_rel,
                    'source_sha256':sha,'part':part,'crop_method':method,'crop_box':list(box),'feature_schema':SCHEMA,'model_revision':MODEL_REVISION,
                    'preparation_scope':'upper_arm_only_no_body_measurements'})
            print('Prepared',path.name,flush=True)
    if not entries:raise ValueError('사용 가능한 상완 영역이 없습니다.')
    write_json(output/'dataset.json',{'schema_version':1,'entries':entries,'input_images':len(rows),'duplicates':0,'failures':failures})
    write_json(output/'source-licenses.json',rows)
    write_json(output/'pre_screening.json',{e['id']:{'status':'candidate','reason':'원본 전체의 의복·노출·인물 수를 직접 확인했습니다. 상완 크롭도 검수한 뒤 제공하며 최종 윤곽 등급은 사람이 입력합니다.','reviewer':'assistant_visual_review','scope':'source_and_crop','human_confirmation_required':True} for e in entries})
    print('Regions',len(entries),'failures',len(failures),flush=True)

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--manifest',required=True,type=Path);parser.add_argument('--output',required=True,type=Path);args=parser.parse_args();prepare(args.manifest,args.output)
