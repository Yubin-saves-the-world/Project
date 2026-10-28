import json, pathlib, re, subprocess, html

HERE = pathlib.Path(__file__).resolve().parent
FE = pathlib.Path("/Users/essay/Desktop/capstone-2/FE")
FONT_R = (FE / "assets/fonts/CapstoneUI-Regular.ttf").as_uri()
FONT_M = (FE / "assets/fonts/CapstoneUI-Medium.ttf").as_uri()
BACK = (FE / "assets/icons/figma/figma-655_768.svg").as_uri()
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

BLUE, INK, MUTED, BORDER, RED = "#4361EE", "#1C1C1C", "#808791", "#E3E0D6", "#F44336"
BG, LINE, TRACK, SOFT = "#FAF9F6", "#EFECE4", "#E8E4DA", "#EEF1FE"

CSS = f"""
@font-face {{ font-family: CapstoneUI; src: url('{FONT_R}'); }}
@font-face {{ font-family: CapstoneUIMedium; src: url('{FONT_M}'); }}
* {{ box-sizing: border-box; margin: 0; padding: 0; }}
body {{ font-family: CapstoneUI, 'Apple SD Gothic Neo', sans-serif; color: {INK}; }}
.phone {{ position: relative; width: 393px; height: 852px; background: {BG}; overflow: hidden; font-size: 16px; }}
.phone.tall {{ height: auto; min-height: 852px; }}
.phone.w320 {{ width: 320px; }}
.status {{ position: absolute; top: 0; left: 0; right: 0; height: 48px; background: {BG}; z-index: 5; }}
.status i {{ position: absolute; top: 14px; left: 34px; font-style: normal; font-family: CapstoneUIMedium; font-size: 16px; }}
.status i.r {{ left: auto; right: 30px; letter-spacing: 3px; }}
.home {{ position: absolute; bottom: 8px; left: 50%; margin-left: -67px; width: 134px; height: 5px; border-radius: 3px; background: #111; z-index: 6; }}
.page {{ padding: 48px 20px 44px; }}
.scroller.bottom {{ position: absolute; left: 0; right: 0; bottom: 0; }}
.bar {{ position: relative; height: 62px; display: flex; align-items: center; justify-content: space-between; }}
.back {{ width: 46px; height: 46px; border: 1px solid {BORDER}; border-radius: 14px; background: #fff; display: flex; align-items: center; justify-content: center; flex: none; }}
.back img {{ width: 28px; height: 28px; }}
.bar .cap {{ position: absolute; left: 0; right: 0; text-align: center; font-size: .75em; letter-spacing: 2px; color: {MUTED}; pointer-events: none; }}
.bar .sp {{ width: 46px; flex: none; }}
h1 {{ font-family: CapstoneUIMedium; font-weight: 400; font-size: 1.875em; line-height: 1.3; letter-spacing: -.7px; margin: 6px 0 18px; overflow-wrap: anywhere; }}
.card {{ background: #fff; border: 1px solid {BORDER}; border-radius: 24px; overflow: hidden; }}
.profile {{ display: flex; align-items: center; gap: 12px; padding: 16px 16px 16px 18px; flex-wrap: wrap; }}
.avatar {{ width: 52px; height: 52px; border-radius: 50%; background: #1F3A93; border: 2px solid {BLUE}; color: #fff; font-family: CapstoneUIMedium; font-size: 1.3em; display: flex; align-items: center; justify-content: center; flex: none; }}
.who {{ flex: 1 1 100px; min-width: 0; }}
.who b {{ display: block; font-family: CapstoneUIMedium; font-weight: 400; font-size: 1.125em; line-height: 1.35; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }}
.who span {{ display: block; margin-top: 2px; font-size: .875em; line-height: 1.4; color: {MUTED}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }}
.pill {{ flex: none; border: 1px solid {BORDER}; border-radius: 999px; padding: 8px 12px; font-size: .8125em; line-height: 1.3; white-space: nowrap; background: #fff; margin-left: auto; }}
.sec {{ margin: 28px 4px 10px; font-size: .75em; letter-spacing: 1.8px; color: {MUTED}; text-transform: uppercase; }}
.row {{ position: relative; display: flex; align-items: center; gap: 12px; min-height: 56px; padding: 12px 20px; }}
.row + .row {{ border-top: 1px solid {LINE}; }}
.row .l {{ flex: 1 1 auto; min-width: 0; font-size: 1.0625em; line-height: 1.4; overflow-wrap: anywhere; }}
.row .l small {{ display: block; margin-top: 2px; font-size: .8125em; line-height: 1.45; color: {MUTED}; }}
.row .v {{ flex: 0 1 auto; max-width: 58%; text-align: right; font-size: .875em; line-height: 1.4; color: {MUTED}; overflow-wrap: anywhere; }}
.row .v.ok {{ color: {BLUE}; }}
.row .chev {{ flex: none; width: 16px; height: 16px; }}
.row.danger .l {{ color: {RED}; }}
.toggle {{ flex: none; width: 52px; height: 32px; border-radius: 16px; background: {TRACK}; position: relative; }}
.toggle::after {{ content: ''; position: absolute; top: 3px; left: 3px; width: 26px; height: 26px; border-radius: 50%; background: #fff; box-shadow: 0 1px 3px rgba(0,0,0,.25); }}
.toggle.on {{ background: {BLUE}; }}
.toggle.on::after {{ left: 23px; }}
.toggle.lock {{ opacity: .45; }}
.foot {{ margin: 28px 0 0; text-align: center; font-size: .75em; letter-spacing: 1.6px; color: {MUTED}; }}
.sk {{ background: {LINE}; border-radius: 8px; }}
.notice {{ display: flex; align-items: center; gap: 14px; padding: 18px 20px; }}
.notice .ico {{ flex: none; width: 40px; height: 40px; border-radius: 50%; background: #FDECEA; display: flex; align-items: center; justify-content: center; }}
.notice .tx {{ flex: 1 1 0; min-width: 0; }}
.notice .tx b {{ display: block; font-family: CapstoneUIMedium; font-weight: 400; font-size: .9375em; line-height: 1.4; }}
.notice .tx span {{ display: block; margin-top: 2px; font-size: .8125em; line-height: 1.45; color: {MUTED}; }}
.btn {{ height: 54px; border-radius: 14px; background: {BLUE}; color: #fff; display: flex; align-items: center; justify-content: center; font-family: CapstoneUIMedium; font-size: .9375em; padding: 0 12px; text-align: center; }}
.btn.off {{ background: rgba(67,97,238,.4); }}
.btn.ghost {{ background: #fff; color: {INK}; border: 1px solid {BORDER}; }}
.btn.red {{ background: {RED}; }}
.btn.red.off {{ background: rgba(244,67,54,.4); }}
.btn.sm {{ height: 40px; border-radius: 12px; padding: 0 16px; font-size: .875em; flex: none; }}
.scrim {{ position: absolute; inset: 0; background: rgba(0,0,0,.45); z-index: 10; }}
.dialog {{ position: absolute; left: 32px; right: 32px; top: 50%; transform: translateY(-50%); background: #fff; border-radius: 24px; padding: 28px 22px 22px; text-align: center; box-shadow: 0 12px 40px rgba(0,0,0,.18); z-index: 11; }}
.dialog .ico {{ width: 60px; height: 60px; border-radius: 50%; background: {SOFT}; margin: 0 auto 16px; display: flex; align-items: center; justify-content: center; }}
.dialog .ico.red {{ background: #FDECEA; }}
.dialog h3 {{ font-family: CapstoneUIMedium; font-weight: 400; font-size: 1.25em; line-height: 1.4; letter-spacing: -.3px; overflow-wrap: anywhere; }}
.dialog .desc {{ margin-top: 8px; font-size: .875em; line-height: 1.55; color: {MUTED}; overflow-wrap: anywhere; }}
.dialog .info {{ margin-top: 16px; background: #F6F7FB; border-radius: 12px; padding: 4px 16px; text-align: left; }}
.dialog .info div {{ display: flex; gap: 10px; align-items: flex-start; padding: 10px 0; font-size: .8125em; line-height: 1.5; }}
.dialog .info div + div {{ border-top: 1px solid #E6E8F0; }}
.dialog .info div i {{ flex: none; width: 6px; height: 6px; border-radius: 50%; background: {RED}; margin-top: 8px; }}
.dialog .agree {{ margin-top: 14px; display: flex; gap: 10px; align-items: flex-start; text-align: left; font-size: .8125em; line-height: 1.5; }}
.dialog .agree .box {{ flex: none; width: 22px; height: 22px; border-radius: 7px; background: {RED}; display: flex; align-items: center; justify-content: center; }}
.dialog .btns {{ margin-top: 20px; display: flex; gap: 10px; }}
.dialog .btns .btn {{ flex: 1 1 0; min-width: 0; height: 50px; }}
.field {{ margin-bottom: 18px; }}
.label {{ display: flex; justify-content: space-between; font-family: CapstoneUIMedium; font-size: .9375em; line-height: 1.3; letter-spacing: 1px; }}
.label em {{ font-style: normal; font-family: CapstoneUI; letter-spacing: 0; font-size: .8125em; color: {MUTED}; }}
.input {{ margin-top: 8px; min-height: 54px; border: 1px solid {BORDER}; border-radius: 14px; padding: 14px 16px; display: flex; align-items: center; justify-content: space-between; gap: 10px; font-size: .875em; line-height: 1.5; background: #fff; overflow-wrap: anywhere; }}
.input.err {{ border-color: {RED}; }}
.input.focus {{ border-color: {BLUE}; }}
.input.ro {{ background: #F4F2EC; color: {MUTED}; }}
.help {{ margin-top: 6px; padding: 0 4px; font-size: .75em; line-height: 1.5; color: {MUTED}; }}
.error {{ margin-top: 6px; padding: 0 4px; font-size: .75em; line-height: 1.5; color: {RED}; }}
.grid {{ display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 10px; }}
.ph {{ position: relative; aspect-ratio: 3 / 4; border-radius: 16px; background: #EDEAE2; overflow: hidden; border: 1px solid {BORDER}; }}
.ph svg.p {{ position: absolute; left: 50%; bottom: 0; transform: translateX(-50%); width: 62%; }}
.ph .tag {{ position: absolute; left: 8px; bottom: 8px; background: rgba(0,0,0,.55); color: #fff; border-radius: 999px; padding: 3px 8px; font-size: .6875em; line-height: 1.3; }}
.ph .x {{ position: absolute; right: 6px; top: 6px; width: 26px; height: 26px; border-radius: 50%; background: rgba(255,255,255,.92); display: flex; align-items: center; justify-content: center; }}
.ph.add {{ background: #fff; border: 1px dashed #C9C5BA; display: flex; align-items: center; justify-content: center; color: {MUTED}; font-size: .8125em; }}
.summary {{ display: flex; align-items: center; justify-content: space-between; gap: 12px; padding: 16px 20px; margin-bottom: 14px; }}
.summary b {{ font-family: CapstoneUIMedium; font-weight: 400; font-size: 1.0625em; }}
.summary span {{ display: block; margin-top: 2px; font-size: .8125em; color: {MUTED}; line-height: 1.45; }}
.link {{ flex: none; font-size: .875em; color: {RED}; white-space: nowrap; }}
.lockicon {{ flex: none; width: 16px; height: 16px; }}
"""

CHEV = '<svg class="chev" viewBox="0 0 16 16" fill="none"><path d="M6 3l5 5-5 5" stroke="#9AA0A8" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"/></svg>'
LOCK = '<svg class="lockicon" viewBox="0 0 16 16" fill="none"><rect x="3" y="7" width="10" height="7" rx="2" stroke="#9AA0A8" stroke-width="1.5"/><path d="M5.5 7V5.5a2.5 2.5 0 015 0V7" stroke="#9AA0A8" stroke-width="1.5"/></svg>'
CHECK = '<svg width="14" height="14" viewBox="0 0 14 14" fill="none"><path d="M3 7.5l3 3 5-6" stroke="#fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>'
PERSON = '<svg class="p" viewBox="0 0 60 80" fill="#D3CEC2"><circle cx="30" cy="20" r="11"/><path d="M6 80c0-20 10-34 24-34s24 14 24 34z"/></svg>'
XICON = '<svg width="12" height="12" viewBox="0 0 12 12" fill="none"><path d="M2.5 2.5l7 7M9.5 2.5l-7 7" stroke="#1C1C1C" stroke-width="1.8" stroke-linecap="round"/></svg>'
WARN = '<svg width="20" height="20" viewBox="0 0 20 20" fill="none"><path d="M10 3l8 14H2L10 3z" stroke="#F44336" stroke-width="1.8" stroke-linejoin="round"/><path d="M10 8v4M10 14.2v.1" stroke="#F44336" stroke-width="1.8" stroke-linecap="round"/></svg>'

def e(t): return html.escape(t)

def chrome(): return '<div class="status"><i>9:41</i><i class="r">●●●</i></div><div class="home"></div>'
def bar(cap, back=True): return f'<div class="bar"><div class="back"><img src="{BACK}"></div><div class="cap">{cap}</div><div class="sp"></div></div>'

def row(label, value=None, sub=None, chev=True, toggle=None, danger=False, ok=False):
    l = f'<div class="l">{e(label)}' + (f'<small>{e(sub)}</small>' if sub else '') + '</div>'
    v = f'<div class="v{" ok" if ok else ""}">{e(value)}</div>' if value else ''
    t = f'<div class="toggle{" on" if toggle in ("on", "lock-on") else ""}{" lock" if toggle == "lock-on" else ""}"></div>' if toggle else ''
    c = CHEV if chev and not toggle else ''
    return f'<div class="row{" danger" if danger else ""}">{l}{v}{t}{c}</div>'

def profile(name="지한", email="name@example.com"):
    return f'<div class="card profile"><div class="avatar">{e(name[:1])}</div><div class="who"><b>{e(name)}</b><span>{e(email)}</span></div><div class="pill">프로필 수정</div></div>'

def lst(*rows): return '<div class="card">' + ''.join(rows) + '</div>'

def settings_body(name="지한", email="name@example.com", body="174cm · 68kg · 18세", goal="근육 키우기", freq="주 3회",
                  exp="1년 미만", target="설정됨", analyses="1회", photo_sub="올린 사진 2장 · 직접 삭제할 수 있어요",
                  w_on=True, d_on=False, w_time="매일 18:00", d_time="매일 12:00"):
    return f"""<div class="page">{bar("SETTINGS")}<h1>설정</h1>{profile(name, email)}
<div class="sec">My body</div>{lst(row("신체 정보", body), row("운동 목적", goal), row("주 운동 횟수", freq), row("운동 경력", exp), row("목표 체형", target), row("분석 기록", analyses))}
<div class="sec">Notifications</div>{lst(row("운동 알림", sub=w_time, toggle="on" if w_on else "off"), row("식단 알림", sub=d_time, toggle="on" if d_on else "off"))}
<div class="sec">Account</div>{lst(row("사진 데이터 관리", sub=photo_sub), row("동의 관리", sub="사진 · AI 분석 동의"), row("개인정보 처리방침"), row("로그아웃", chev=False), row("회원 탈퇴", chev=False, danger=True))}
<div class="foot">VERSION 1.0.0</div></div>"""

def skeleton():
    def sk(w, h=14, mt=0): return f'<div class="sk" style="width:{w};height:{h}px;margin-top:{mt}px"></div>'
    prof = f'<div class="card profile"><div class="avatar" style="background:{LINE};border-color:{LINE}"></div><div class="who">{sk("40%",18)}{sk("70%",14,8)}</div></div>'
    def srow(): return f'<div class="row"><div class="l">{sk("34%",16)}</div>{sk("28%",14)}</div>'
    return f"""<div class="page">{bar("SETTINGS")}<h1>설정</h1>{prof}
<div class="sec">My body</div>{lst(*[srow() for _ in range(6)])}
<div class="sec">Notifications</div>{lst(row("운동 알림", sub="매일 18:00", toggle="off"), row("식단 알림", sub="매일 12:00", toggle="off"))}
<div class="sec">Account</div>{lst(row("사진 데이터 관리"), row("동의 관리"), row("개인정보 처리방침"), row("로그아웃", chev=False), row("회원 탈퇴", chev=False, danger=True))}
<div class="foot">VERSION 1.0.0</div></div>"""

def error_state():
    err = f'<div class="card notice"><div class="ico">{WARN}</div><div class="tx"><b>불러오지 못했어요</b><span>네트워크를 확인하고 다시 시도해 주세요.</span></div><div class="btn sm">다시 시도</div></div>'
    return f"""<div class="page">{bar("SETTINGS")}<h1>설정</h1>{err}
<div class="sec">Account</div>{lst(row("개인정보 처리방침"), row("로그아웃", chev=False), row("회원 탈퇴", chev=False, danger=True))}
<div class="foot">VERSION 1.0.0</div></div>"""

def dlg(icon_html, title, desc, extra="", btns=""):
    return f'<div class="scrim"></div><div class="dialog">{icon_html}<h3>{title}</h3><div class="desc">{desc}</div>{extra}<div class="btns">{btns}</div></div>'

OUT_ICON = '<svg width="28" height="28" viewBox="0 0 28 28" fill="none"><path d="M11 5H7.5A2.5 2.5 0 005 7.5v13A2.5 2.5 0 007.5 23H11M17 9l5 5-5 5M22 14H11" stroke="#4361EE" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></svg>'
TRASH_ICON = '<svg width="28" height="28" viewBox="0 0 28 28" fill="none"><path d="M6 8h16M11 8V6h6v2M8.5 8l1 14h9l1-14M12 12v6M16 12v6" stroke="#F44336" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></svg>'
AI_ICON = '<svg width="28" height="28" viewBox="0 0 28 28" fill="none"><path d="M14 4l2.2 5.8L22 12l-5.8 2.2L14 20l-2.2-5.8L6 12l5.8-2.2L14 4z" stroke="#4361EE" stroke-width="2.2" stroke-linejoin="round"/></svg>'

def logout_dialog():
    return dlg(f'<div class="ico">{OUT_ICON}</div>', "로그아웃할까요?", "다시 로그인하면 기록은 그대로 남아 있어요.",
               btns='<div class="btn ghost">취소</div><div class="btn">로그아웃</div>')

def withdraw_dialog():
    info = '<div class="info"><div><i></i><span>신체 정보와 올린 사진</span></div><div><i></i><span>체형 분석 결과와 목표 체형</span></div><div><i></i><span>루틴과 운동 기록</span></div><div><i></i><span>작성한 글과 댓글</span></div></div>'
    agree = f'<div class="agree"><div class="box">{CHECK}</div><span>삭제된 정보는 되돌릴 수 없다는 것을 확인했어요.</span></div>'
    return dlg(f'<div class="ico red">{TRASH_ICON}</div>', "정말 탈퇴할까요?", "탈퇴하면 바로 로그아웃되고, 아래 정보가 모두 삭제돼요. 같은 이메일로 다시 가입할 수 있어요.",
               extra=info + agree, btns='<div class="btn ghost">취소</div><div class="btn red">탈퇴하기</div>')

def profile_edit():
    return f"""<div class="page">{bar("PROFILE")}<h1>프로필 수정</h1>
<div class="field"><div class="label">닉네임<em>5 / 20</em></div><div class="input err"><span>지한이</span></div><div class="error">이미 사용 중인 닉네임이에요.</div></div>
<div class="field"><div class="label">이메일</div><div class="input ro"><span>name@example.com</span>{LOCK}</div><div class="help">이메일은 바꿀 수 없어요.</div></div>
<div class="btn" style="margin-top:28px">저장</div></div>"""

def photos():
    def ph(tag): return f'<div class="ph">{PERSON}<div class="tag">{tag}</div><div class="x">{XICON}</div></div>'
    return f"""<div class="page">{bar("PHOTOS")}<h1>사진 데이터 관리</h1>
<div class="card summary"><div><b>올린 사진 2 / 20장</b><span>직접 삭제할 수 있어요</span></div><div class="link">전체 삭제</div></div>
<div class="grid">{ph("정면")}{ph("측면")}<div class="ph add">+ 추가</div></div>
<div class="help" style="margin-top:16px;line-height:1.6">체형 분석에 쓴 사진을 지워도 분석 결과는 그대로 남아요. 목표 체형 사진은 특징을 읽은 직후 자동으로 삭제돼요.</div></div>"""

def consent_page():
    return f"""<div class="page">{bar("CONSENT")}<h1>동의 관리</h1>
<div class="sec" style="margin-top:6px">Required</div>{lst(row("서비스 이용약관", sub="동의함", toggle="lock-on"), row("개인정보 처리방침", sub="동의함", toggle="lock-on"))}
<div class="help" style="margin-top:8px">필수 동의는 회원 탈퇴로만 철회할 수 있어요.</div>
<div class="sec">Optional use</div>{lst(row("체형 사진 사용", sub="끄면 새 사진을 올릴 수 없어요", toggle="on"), row("AI 분석", sub="끄면 체형 분석과 AI 코치를 쓸 수 없어요", toggle="on"))}</div>"""

def consent_dialog():
    return consent_page() + dlg(f'<div class="ico">{AI_ICON}</div>', "AI 분석을 끌까요?", "진행 중인 분석이 있으면 취소돼요. 새 분석과 AI 코치는 다시 동의해야 쓸 수 있어요. 이미 만든 결과는 계속 볼 수 있어요.",
               btns='<div class="btn ghost">취소</div><div class="btn">끄기</div>')

LONG_NAME = "아주아주긴닉네임이름이십자입니다"
LONG_MAIL = "very.long.email.address.example@subdomain.example-company.co.kr"

# (key, title, note, body, kwargs)  kwargs: tall / bottom / w320 / fs
SCREENS = [
    ("1_settings", "① 설정 (전체 길이)", "화면보다 길면 스크롤. 섹션 4개: 프로필 · 내 몸 · 알림 · 계정", settings_body(), dict(tall=True)),
    ("2_stress", "② 긴 글자 · 작은 화면 · 큰 글씨", "폭 320, 글씨 130%, 20자 닉네임. 긴 글은 말줄임 또는 줄바꿈, 행은 늘어남", settings_body(name=LONG_NAME, email=LONG_MAIL, body="174.5cm · 68.5kg · 18세", goal="근육 키우기", target="분석 중", analyses="128회", photo_sub="올린 사진 20장 · 직접 삭제할 수 있어요", w_time="매일 18:00에 알려드려요"), dict(tall=True, w320=True, fs=20.8)),
    ("3_loading", "③ 불러오는 중", "값이 올 자리만 회색 막대로. 알림·계정은 바로 사용 가능", skeleton(), dict(tall=True)),
    ("4_error", "④ 불러오기 실패", "프로필 블록만 오류 안내. 로그아웃·탈퇴는 항상 가능", error_state(), dict()),
    ("5_logout", "⑤ 로그아웃 확인", "스크롤 맨 아래 상태에서 안내 창. 서버 처리 없이 앱이 토큰만 삭제", settings_body(), dict(bottom=True, overlay=logout_dialog())),
    ("6_withdraw", "⑥ 회원 탈퇴 확인", "삭제 항목을 보여 주고, 확인 체크 후에만 ‘탈퇴하기’ 활성", settings_body(), dict(bottom=True, overlay=withdraw_dialog())),
    ("7_profile", "⑦ 프로필 수정", "닉네임만 수정. 중복이면 칸 아래 빨간 글씨. 이메일은 읽기 전용", profile_edit(), dict()),
    ("8_photos", "⑧ 사진 데이터 관리", "올린 사진 개수(최대 20), 개별·전체 삭제", photos(), dict()),
    ("9_consent", "⑨ 동의 관리 · AI 끄기 확인", "필수 동의는 잠금. 선택 동의를 끌 때 영향을 안내", consent_page(), dict(overlay=dlg(f'<div class="ico">{AI_ICON}</div>', "AI 분석을 끌까요?", "진행 중인 분석이 있으면 취소돼요. 새 분석과 AI 코치는 다시 동의해야 쓸 수 있어요. 이미 만든 결과는 계속 볼 수 있어요.", btns='<div class="btn ghost">취소</div><div class="btn">끄기</div>'))),
]

CHECK_JS = """
<script>
window.addEventListener('load', function () {
  var phone = document.querySelector('.phone'), pr = phone.getBoundingClientRect(), bad = [];
  document.querySelectorAll('.phone *').forEach(function (el) {
    var cs = getComputedStyle(el);
    if (cs.display === 'none' || el.tagName === 'svg' || el.closest('svg')) return;
    var r = el.getBoundingClientRect();
    if (r.width === 0 || r.height === 0) return;
    var ell = cs.textOverflow === 'ellipsis';
    if (!ell && el.scrollWidth > el.clientWidth + 1 && cs.overflow !== 'visible') bad.push('가로넘침:' + el.className + ':' + (el.textContent||'').slice(0,20));
    if (r.right > pr.right + 0.5 || r.left < pr.left - 0.5) bad.push('화면밖:' + el.className + ':' + (el.textContent||'').slice(0,20));
    if (cs.overflow === 'hidden' && !ell && el.scrollHeight > el.clientHeight + 1 && !el.classList.contains('phone') && !el.classList.contains('card') && !el.classList.contains('ph')) bad.push('세로잘림:' + el.className);
  });
  var inner = phone.classList.contains('tall') ? phone.scrollHeight : 852;
  document.body.setAttribute('data-check', JSON.stringify({bad: bad, h: Math.ceil(phone.getBoundingClientRect().height), w: Math.ceil(pr.width)}));
});
</script>"""

def page(body, bg="#fff", extra=""):
    return f"<!doctype html><html><head><meta charset='utf-8'><style>{CSS}body{{background:{bg}}}</style></head><body>{body}{extra}</body></html>"

def phone_html(body, tall=False, bottom=False, w320=False, fs=None, overlay=""):
    cls = "phone" + (" tall" if tall else "") + (" w320" if w320 else "")
    st = f' style="font-size:{fs}px"' if fs else ""
    inner = f'<div class="scroller{" bottom" if bottom else ""}">{body}</div>'
    return f'<div class="{cls}"{st}>{chrome()}{inner}{overlay}</div>'

def run_chrome(args):
    return subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--allow-file-access-from-files",
                           "--virtual-time-budget=4000", *args], check=True, capture_output=True, text=True)

def measure(html_path):
    dom = run_chrome(["--dump-dom", html_path.as_uri()]).stdout
    m = re.search(r"data-check='([^']*)'|data-check=\"([^\"]*)\"", dom)
    raw = html.unescape(m.group(1) or m.group(2)) if m else "{}"
    return json.loads(raw)

def render(html_path, png_path, w, h, scale=2):
    run_chrome([f"--force-device-scale-factor={scale}", f"--window-size={w},{h}", f"--screenshot={png_path}", html_path.as_uri()])

report = []
cards = []
for key, title, note, body, kw in SCREENS:
    ph = phone_html(body, **kw)
    p = HERE / f"{key}.html"
    p.write_text(page(ph, extra=CHECK_JS), encoding="utf-8")
    info = measure(p)
    w, h = info.get("w", 393), info.get("h", 852)
    render(p, HERE / f"{key}.png", w, h)
    report.append((key, w, h, info.get("bad", [])))
    cards.append((title, note, ph, w, h))

board_css = """
.board{display:grid;grid-template-columns:repeat(3,393px);gap:36px 32px;padding:36px;background:#F2F3F7;align-items:start;width:max-content}
.cd{width:393px}.cp{min-height:64px;font-size:13px;line-height:19px;color:#555}.cp b{display:block;font-family:CapstoneUIMedium;font-size:16px;color:#111;margin-bottom:2px;font-weight:400}
.fr{border-radius:44px;overflow:hidden;box-shadow:0 8px 28px rgba(0,0,0,.14);border:1px solid #D9DCE4;background:#fff;width:max-content}
.hd{padding:36px 36px 0;background:#F2F3F7;font-family:CapstoneUIMedium;font-size:26px}
.hd small{display:block;font-family:CapstoneUI;font-size:14px;color:#666;margin-top:6px}
"""
board = ''.join(f'<div class="cd"><div class="cp"><b>{t}</b>{n}</div><div class="fr">{ph}</div></div>' for t, n, ph, w, h in cards)
board_html = (f"<!doctype html><html><head><meta charset='utf-8'><style>{CSS}{board_css}body{{background:#F2F3F7}}</style></head><body>"
              f'<div class="hd">MOVID · 설정 화면 설계<small>프로필 · 내 몸 · 알림 · 계정. 로그아웃은 토큰 삭제만, 회원 탈퇴는 확인 체크 후 진행</small></div>'
              f'<div class="board">{board}</div></body></html>')
bp = HERE / "board.html"
bp.write_text(board_html, encoding="utf-8")
run_chrome([f"--force-device-scale-factor=1", "--window-size=1400,10", f"--screenshot={HERE/'_probe.png'}", bp.as_uri()])
(HERE / "_probe.png").unlink(missing_ok=True)
BW = 36 * 2 + 3 * 393 + 2 * 32
rows_h = []
for i in range(0, len(cards), 3):
    rows_h.append(max(c[4] for c in cards[i:i + 3]) + 64 + 36)
BH = 110 + 36 + sum(rows_h) + 40
render(bp, HERE / "settings_board.png", BW, BH, scale=1)

print("검사 결과 (넘침·잘림·화면 밖):")
ok = True
for key, w, h, bad in report:
    print(f"  {key}: {w}x{h}", "OK" if not bad else bad)
    ok = ok and not bad
print("전체", "통과" if ok else "문제 있음")
