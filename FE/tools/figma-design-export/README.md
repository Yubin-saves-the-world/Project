# 현재 디자인의 읽기 전용 추출

`code.js`는 현재 페이지에서 지정한 네 프레임의 속성·SVG·PNG만 읽으며 노드를 수정하지 않는다. `server.py`는 127.0.0.1:8766에만 수신한다. 작업 중 추출한 자료는 `docs/figma-reference/current`와 `assets/icons/figma`에 보관했다.

재사용하려면 서버를 실행해 생성된 `key.txt` 값을 플러그인 코드의 `LOCAL_EXPORT_KEY`에 임시로 넣고 `manifest.json`을 Figma 개발 플러그인으로 실행한다. 작업 뒤 서버를 종료하고 키를 지운다. 현재 코드에는 세션 키가 남아 있지 않다.
