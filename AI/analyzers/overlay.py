"""A compact body-only overlay without face indices or segmentation masks."""
import cv2
from analyzers.photo_geometry import point


def draw_overlay(image, landmarks):
    canvas = image.copy()
    height, width = canvas.shape[:2]
    edges = [('left_shoulder', 'right_shoulder'), ('left_hip', 'right_hip')]
    for side in ('left', 'right'):
        for chain in [('shoulder', 'elbow', 'wrist'), ('shoulder', 'hip', 'knee', 'ankle')]:
            edges.extend((f'{side}_{a}', f'{side}_{b}') for a, b in zip(chain, chain[1:]))
    for first, last in edges:
        a, b = (point(landmarks, name, width, height) for name in (first, last))
        if a is not None and b is not None:
            aa, bb = tuple(round(v) for v in a), tuple(round(v) for v in b)
            cv2.line(canvas, aa, bb, (238, 97, 67), 3, cv2.LINE_AA)
            for pos in (aa, bb):
                cv2.circle(canvas, pos, 5, (255, 255, 255), -1, cv2.LINE_AA)
                cv2.circle(canvas, pos, 5, (238, 97, 67), 2, cv2.LINE_AA)
    ok, data = cv2.imencode('.jpg', canvas, [cv2.IMWRITE_JPEG_QUALITY, 85])
    if not ok:
        raise RuntimeError('Overlay encoding failed')
    return data.tobytes()
