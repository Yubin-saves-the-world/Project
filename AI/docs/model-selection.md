# 근육 윤곽 분석 모델 선정

## 선정 결과

우선 개발 모델은 DINOv3 ViT-S/16, 경량 비교 기준은 EfficientNet-B0입니다. 현재 코드에 적용된 결과가 아니라 공식 자료를 검토한 개발 계획입니다.

| 후보 | 검토 결과 |
|---|---|
| DINOv3 ViT-S/16 | 공간별 특징 추출과 약 2,100만 파라미터 소형 모델을 활용해 우선 실험 |
| DINOv2 ViT-S/14 | 범용 특징 추출 비교 후보 |
| EfficientNet-B0 | 약 530만 파라미터의 경량 기준 모델 |
| SigLIP 2 Base | 이미지·문장 연결을 활용하는 보조 후보 |
| Sapiens2 | 인체 부위 분할·표면 추정 고도화 후보 |

## 선정 이유와 적용 계획

MediaPipe로 부위를 찾고 원본에서 잘라낸 뒤, DINOv3 특징 추출기를 고정하여 작은 판정기를 학습합니다. 공간별 특징을 활용할 수 있고 작은 모델부터 시작할 수 있다는 점으로 선정했습니다. 근육 사진에서의 정확도와 Mac 실행 성능은 미측정입니다.

처음에는 한 부위로 범위를 좁혀 윤곽 약함·중간·뚜렷함을 정의합니다. 흐림·가림·해상도 부족은 품질 검사에서 판정을 보류합니다. 원본에 없는 근육선을 생성형 보정으로 만들지 않습니다.

## 비교 방법

인물 단위로 학습·평가를 분리하고 같은 부위 사진과 라벨을 사용합니다. Macro-F1·혼동행렬·조명 변화에 대한 안정성·전체 처리 시간·최대 메모리를 비교합니다. 성능 개선이 작고 실행 부담이 크면 EfficientNet-B0로 변경할 수 있습니다. 이 모델들은 근육량 kg을 바로 제공하지 않습니다.

## 공식 자료

- [DINOv3](https://github.com/facebookresearch/dinov3)
- [DINOv2](https://github.com/facebookresearch/dinov2)
- [EfficientNet-B0](https://docs.pytorch.org/vision/main/models/generated/torchvision.models.efficientnet_b0.html)
- [SigLIP 2](https://huggingface.co/google/siglip2-base-patch16-384)
- [Sapiens2](https://github.com/facebookresearch/sapiens2)
- [DINOv3 논문](https://arxiv.org/abs/2508.10104)

상세 비교는 함께 제공한 Word 보고서를 참고하세요.
