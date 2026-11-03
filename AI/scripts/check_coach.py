"""Check local Qwen3 availability without storing or transmitting a conversation."""
from pathlib import Path
import argparse
import json
import sys
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
from coach import LocalCoach,ChatRequest,CoachFailure

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--smoke',action='store_true',help='실제 짧은 한국어 답변 한 건 확인')
    args=parser.parse_args();client=LocalCoach();health=client.health();print(json.dumps(health,ensure_ascii=False,indent=2))
    if health['status']!='ready':
        raise SystemExit('Ollama 실행과 ollama pull qwen3:4b를 확인하세요. 자동 다운로드나 대체 모델 호출은 하지 않습니다.')
    if args.smoke:
        try:
            result=client.chat(ChatRequest(messages=[{'role':'user','content':'운동 습관을 꾸준히 유지하는 팁을 짧게 알려주세요.'}]))
            print(json.dumps(result,ensure_ascii=False,indent=2))
        except CoachFailure as exc:raise SystemExit(exc.code+': '+exc.message)
