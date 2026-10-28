# AGENTS.md — MOVID Flutter app (MVP)

> How to use: copy this file to `FE/AGENTS.md` in the repo root of the Flutter app, then prompt Codex with
> `Read AGENTS.md. Do task T3 only.` (one task per run). User-facing strings in the app are Korean; keep them Korean.

## 0. Mission

Implement the MVP of the MOVID app (Flutter) against the existing backend. The backend for all MVP endpoints is DONE and tested. Your job is the app side only: screens, view models, repositories, models, tests.

MVP loop that must work end to end on a device/simulator:

`sign up -> body profile -> upload photo -> body analysis result -> goal body -> today's routine -> workout (sets) -> finish -> history`

Do NOT touch the backend, `docs/final-specs/**`, or `docs/api-baseline/**`. Do NOT run `git commit` / `git push` unless the prompt says so.

**Preserve what already exists.** The app already has working features: manual weekly schedule (user picks training/rest days per week, repeats weekly), rest-day overrides, local persistence of workout records, workout calendar, and a finished visual design. Server integration must be added around them, not replace them. Keep the current app design (colors, borders, error color, layout) unless a task explicitly says otherwise. When this file and the existing code disagree on look-and-feel, the existing code wins.

**Precondition.** The checkout must already contain the real email-verification and password-reset integration (`ServerOnboardingRepository.sendEmailCode/confirmEmailCode`, `PasswordResetRepository` calling `reset-verification`). If those are missing, STOP and report; do not re-implement them from scratch on an old base.

## 1. Stack facts (verified in the repo)

- Flutter app, Dart `^3.11.4` (`pubspec.yaml`). Use the Flutter on PATH; if `flutter --version` is too old for `^3.11.4`, STOP and report instead of editing `pubspec.yaml`.
- Allowed packages already in `pubspec.yaml`: `http`, `shared_preferences`, `image_picker`, `image`, `path_provider`, `flutter_svg`. Add a new package only if a task cannot be done without it, and say so in your final message.
- **State management = `ChangeNotifier` view models** (see `lib/app/onboarding/onboarding_view_model.dart`). **HTTP = `package:http`** (see `lib/features/auth/data/server_onboarding_repository.dart`).
- IMPORTANT: `docs/frontend-architecture/*.md` propose Riverpod, Dio, `AsyncValue`, `go_router`. **Ignore those proposals. Follow the code that exists.** Use those docs only for folder/file naming and for the data-flow reasoning in `03-state-and-work-plan.md` (still valid).
- Routing = `MaterialApp` named routes in `lib/app/router/app_router.dart`, constants in `route_paths.dart`. Do not add `go_router`.
- Server address: `AppConfig.apiBaseUrl` from `--dart-define=API_BASE_URL=...` (`lib/core/config/app_config.dart`). `--dart-define=USE_LOCAL_PREVIEW=true` selects the local fake repository.
- Token storage: `TokenStore` interface in `lib/features/auth/data/token_store.dart` (`PreferencesTokenStore`, `MemoryTokenStore`).

Run commands:

```bash
flutter pub get
flutter analyze
flutter test
flutter run --dart-define=API_BASE_URL=http://localhost:8080          # iOS simulator
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080           # Android emulator
```

Test baseline: before you start, run `flutter test` once and record the failing tests (if any) and the Flutter version used. Golden-image tests can differ between Flutter versions (a newer Flutter produced about 14 differing goldens in one environment; in another environment everything passed). **Never update golden files on your own.** Your change must add zero new failures compared with the baseline you recorded. The team should agree on one Flutter version (open decision D4).

## 2. Architecture rules (follow existing patterns)

Feature folder layout (already present under `lib/features/<feature>/`):

```
data/models/*.dart               immutable models, fromJson/toJson
data/<feature>_repository.dart   abstract interface class
data/server_<feature>_repository.dart   real implementation (http)
data/local_<feature>_repository.dart    in-memory fake used by USE_LOCAL_PREVIEW and tests
presentation/pages/*_page.dart   layout + wiring only
presentation/view_models/*.dart  ChangeNotifier, user actions, state transitions
presentation/widgets/*.dart      feature-specific small widgets
```

Rules:

1. Pages never call `http` and never build another feature's view model. Pages talk to their own view model; view models talk to repository interfaces injected via constructor.
2. Every repository interface needs a fake in `test/fakes/` (pattern: `fake_onboarding_repository.dart`). Write view-model tests against the fake.
3. **One shared API client.** Task T0 creates `lib/core/network/api_client.dart` (wraps `http.Client`, adds `Authorization: Bearer`, parses error envelope into `ApiFailure`, calls a 401 callback once). All new repositories use it. Extend `ApiContract` (`lib/core/network/api_contract.dart`) with every path you use; never inline `'/api/...'` strings elsewhere.
4. JSON is `snake_case`; Dart is `camelCase`. Map explicitly in `fromJson`.
5. **`null` is real missing data. Never write `value ?? 0` for measurements, scores, or volumes.** Show "측정하지 못했어요" instead.
6. Unknown enum values must not crash: parse to an `unknown` member.
7. Loading/error states: reads are `loading | data | error`; writes are `idle | submitting | success | error`. A network error is NOT the same as analysis `failed`.
8. Reuse `lib/ui/core/theme/*` (`AppColors`, `AppSpacing`, `AppRadii`, `AppTypography`) and `lib/ui/core/widgets/*`. No hard-coded colors, no new fonts. **The app tokens are the source of truth** (for example `AppColors.border`, `AppColors.error`). Hex values in design handoff files (`design/**`) are reference only; map them to the nearest existing token and do not introduce new colors.
9. Layout must not break at 320 px wide and at 130% system text size. Rows grow in height (min height, never fixed), long text wraps or ellipsizes as specified, everything scrolls, use `SafeArea`. Do not lock `textScaler`.
10. Match surrounding code style. Do not add redundant comments. No `print`; no TODOs left behind.
11. Do not create empty placeholder files for future features.

## 3. Backend contract (MVP, all implemented)

Source of truth: `openapi.yaml` (backend repo, `api/openapi.yaml`) — the copy under `docs/final-specs/` may be older. If you doubt a field, ask; do not guess.

General:
- All paths start with `/api`. Auth: `Authorization: Bearer <access_token>`. Token lifetime 7 days, **no refresh API**.
- **401 handling.** Treat HTTP 401 as "session expired" (clear token and personal caches, go to login, once, globally) ONLY for requests that were sent with a token. A 401 from `POST /auth/login` (`INVALID_CREDENTIALS`) is a normal input error shown on the login form. Public endpoints (signup, email verification, login, password reset) never trigger the global logout.
- Error body: `{"code": "...", "message": "한글 문구", "status": 400, "fields": [{"field","reason"}]}`. Branch on `code`. `message` is safe to show.
- Lists: `?page=1&page_size=20` (max 50) -> `{items, page, page_size, total}`.
- Times are ISO with `+09:00`. Dates are `YYYY-MM-DD`.
- First screen after login/app start: `GET /users/me` -> `consent_completed=false` -> consent; `onboarding_completed=false` -> profile; else home.
- Global errors: `ONBOARDING_REQUIRED`(403) -> profile screen; `CONSENT_REQUIRED`(403) -> settings/consent; `VALIDATION_FAILED`(400) -> show `fields[].reason` on matching inputs.

### Auth / user
| Call | Notes |
|---|---|
| `POST /auth/email-verifications` `{email}` -> 204 | 6-digit code, valid 5 min. 60 s resend cooldown. Errors `EMAIL_DUPLICATED`, `EMAIL_CODE_TOO_FREQUENT`(429), `EMAIL_SEND_FAILED`(503) |
| `POST /auth/email-verifications/confirm` `{email,code}` -> `{verification_token, expires_in}` | Errors `EMAIL_CODE_INVALID`, `EMAIL_CODE_EXPIRED`, `EMAIL_CODE_LOCKED`(429, 5 wrong tries) |
| `POST /users` -> 201 `{user_id,email,nickname,created_at}` | body: `email,password(8-64),nickname(2-20),terms_agreed,privacy_agreed,body_photo_agreed,ai_processing_agreed,policy_version?,email_verification_token`. No token returned: call login next. Errors `TERMS_REQUIRED`, `EMAIL_NOT_VERIFIED`, `EMAIL_DUPLICATED`, `NICKNAME_DUPLICATED` |
| `POST /auth/login` `{email,password}` -> `{access_token,token_type,expires_in,onboarding_completed}` | `INVALID_CREDENTIALS`(401) does not reveal which field is wrong |
| `POST /auth/logout` -> 204 | Server does nothing. App deletes the token. |
| `POST /auth/password/reset-request` `{email}` -> 204 | Sends a 6-digit code (same limits as email verification) |
| `POST /auth/password/reset-verification` `{email, code}` -> `{reset_token, expires_in}` | Errors `EMAIL_CODE_INVALID`, `EMAIL_CODE_EXPIRED`, `EMAIL_CODE_LOCKED`(429) |
| `PATCH /auth/password/reset` `{token(20-200), new_password(8-64)}` -> 204 | `RESET_TOKEN_INVALID`(400). Flow: request -> verification -> reset |
| `GET /users/me` | `{user_id,email|null,nickname,role,onboarding_completed,consent_completed,body_photo_agreed,ai_processing_agreed,created_at}` |
| `PATCH /users/me` | any of `nickname(2-20), terms_agreed, privacy_agreed, body_photo_agreed, ai_processing_agreed`. terms/privacy can only become true. `body_photo_agreed=false` blocks new uploads; `ai_processing_agreed=false` cancels running AI work and blocks new AI. `NICKNAME_DUPLICATED`(409) |
| `DELETE /users/me` -> 204 | Immediate; same email may register again. App clears token + local data. |

### Profile
| Call | Notes |
|---|---|
| `POST /users/me/profile` -> 201 | `height_cm(100-250), weight_kg(30-250), age(10-100), gender?(male/female/none), goal_type(muscle/diet/posture), weekly_frequency(1-7), experience_level(under3m/under1y/over1y)`. 409 `PROFILE_ALREADY_EXISTS` -> use PATCH |
| `GET /users/me/profile` | 404 `PROFILE_NOT_FOUND` = not registered yet |
| `PATCH /users/me/profile` | same fields, all optional. Response adds `routine_refresh_recommended` (true if goal/frequency/experience changed) -> offer to regenerate routines |

### Photos
| Call | Notes |
|---|---|
| `POST /photos` multipart `image`, `type=current|goal`, `side?=front|side|back` -> 201 `{photo_id,type,side,url,url_expires_at,created_at}` | **Before upload: resize long edge <= 1024 px and bake EXIF rotation into pixels (JPEG).** Otherwise analysis fails with `NO_PERSON`/`NOT_FULL_BODY`. Max 10 MB (413 `IMAGE_TOO_LARGE`), JPG/PNG only (415 `IMAGE_INVALID_TYPE`), max 20 photos (409 `PHOTO_LIMIT_EXCEEDED`). `CONSENT_REQUIRED` if photo consent withdrawn |
| `GET /photos?type=` | `url` is a signed URL valid 1 h; refetch to refresh |
| `DELETE /photos/{id}` -> 204 | 409 `PHOTO_IN_USE` only while a goal-body job uses it |
| `DELETE /photos?type=` | `{deleted_count, skipped_count}` |

Existing helpers: `lib/core/media/image_preprocessor.dart`, `image_picker_service.dart`, `lib/features/photos/presentation/widgets/photo_input_field.dart`.

### Body analysis (async)
| Call | Notes |
|---|---|
| `POST /body-analyses/photo` `{photo_id, side_photo_id?, goal_body_id?}` -> 202 `{analysis_id,status:"pending",poll_after_ms,created_at}` | `photo_id` = my `type=current, side=front` photo; `side_photo_id` = `side=side`. Errors `PHOTO_TYPE_MISMATCH`(400), `GOAL_NOT_READY`(409), `ANALYSIS_IN_PROGRESS`(409), `ANALYSIS_QUOTA_EXCEEDED`(429, 3/day), `CONSENT_REQUIRED` |
| `GET /body-analyses/{id}` | Poll every 2 s, give up after 60 s with "잠시 후 다시 확인해 주세요" (resume later by `analysis_id`). Fields: `status(pending/done/failed)`, `error_code`, `error_message`, `measures{shoulder_tilt_deg,pelvis_tilt_deg,neck_forward_deg,shoulder_hip_ratio,torso_leg_ratio (all nullable), unavailable[]}`, `balance_score(nullable)`, `body_type(nullable)`, `judgements[{item,label,value|null,unit,level(good/caution/unavailable),reason}]`, `goal_comparison{priority_parts,summary,detail}|null`, `measurement_version` |
| `GET /body-analyses` | history, newest first: `{analysis_id,status,source,balance_score,body_type,goal_body_id,created_at}` |
| `GET /body-analyses/usage` | `{used,limit,remaining,reset_at}` |

**`status=failed` arrives as HTTP 200**, not an error. Map `error_code`: `IMAGE_BLURRY` blurry; `NO_PERSON`/`NOT_FULL_BODY` full body not visible; `MULTIPLE_PEOPLE`; `NOT_FRONTAL`; `AI_FAILED`/`AI_TIMEOUT` retry later. After `done`, routines are **not** auto-created: the app calls `POST /routines`.
`measurement_version == "stub-v0"` means the AI is still a stub; render it exactly like real data.

### Goal body
`POST /goal-bodies {photo_id?, description?(1-200)}` -> 201 `{goal_body_id,status(pending/done/failed),summary|null,error_message|null,poll_after_ms|null,description|null,created_at}`; `GET /goal-bodies` (404 `GOAL_NOT_FOUND` = none); `PATCH /goal-bodies/{id}` same body; `DELETE /goal-bodies/{id}` -> 204.
Goal photo = `POST /photos` with `type=goal`. Description only -> `done` immediately. With photo -> `pending`, poll `GET /goal-bodies` every 2 s. The server deletes the goal photo after processing (never show a goal photo preview after registration). One goal per user (409 `GOAL_ALREADY_EXISTS` -> PATCH). Finished analyses do not change when the goal changes.

### Exercises, routines
- `GET /exercises?target_part=&difficulty=&equipment=&q=&page=&page_size=` -> items `{exercise_id,name,target_part(chest/back/leg/shoulder/arm/core),equipment(barbell/dumbbell/machine/bodyweight),difficulty(1-5),min_sets,max_sets,media_url|null}`; `GET /exercises/{id}` adds `description`. `min_sets/max_sets` depend on the user's experience level.
- `POST /routines {analysis_id}` -> 201 `{analysis_id, routines[]}`: 7 days from today, `weekly_frequency` training days, replaces future `planned` routines, keeps `done/skipped`. 409 `ANALYSIS_NOT_READY`.
- `GET /routines/weekly?week_start=` (Monday only, default this week) -> `{week_start, days[{date,is_rest_day,routine|null}]}` where routine = `{routine_id,scheduled_date,title,target_part,estimated_minutes,status,item_count,done_count}`.
- `GET /routines/today?date=` -> `{date,is_rest_day,routine|null}` (rest day is NOT an error).
- `GET /routines/{id}` -> `{routine_id,analysis_id,scheduled_date,title,target_part,estimated_minutes,status(planned/done/skipped),items[{item_id,order_no,exercise,target_sets,target_reps,target_weight_kg|null,rest_sec,reason|null,done}]}`.
- `PATCH /routines/{id} {status:"skipped"|"planned"}` -> routine. `planned -> skipped` skips; `skipped -> planned` restores, **only for routines dated today or later** (past dates -> 400 `VALIDATION_FAILED`). `done` routines cannot be changed (400 `VALIDATION_FAILED`). Sending the current status again is not an error. Use it only to sync the user's rest-day choice (see D1).
- The server has NO API to store a manual weekly schedule, repeat rules, or user-chosen rest days. Those stay local (see D1).

### Workout logs (one log per exercise)
| Call | Notes |
|---|---|
| `POST /workout-logs {exercise_id, routine_id?}` | 201 new, **200 + `resumed=true`** if an `in_progress` log for that exercise exists. Response `{log_id,exercise_id,routine_id,started_at,status,resumed}`. `routine_id` must be mine and contain that exercise (else 400) |
| `POST /workout-logs/{log_id}/sets` `{client_set_id(UUID,36), set_no(1-20), weight_kg(0-500), reps(1-100), rest_sec?(0-3600), is_done?}` | 201 new, **200 if same `client_set_id` was already saved**. Do NOT send `exercise_id`. 409 `WORKOUT_ALREADY_COMPLETED`, `SET_DUPLICATED` |
| `PATCH /workout-logs/{log_id}/sets/{set_id}` `{version, weight_kg?, reps?, is_done?, rest_sec?}` | 409 `VERSION_CONFLICT`: refetch the log, let the user re-edit; never auto-resend |
| `DELETE /workout-logs/{log_id}/sets/{set_id}` -> 204 | other `set_no`s are not renumbered |
| `PATCH /workout-logs/{log_id}/complete {duration_sec?(1-21600), memo?}` | -> `{log_id,completed_at,duration_sec,total_volume_kg,set_count,routine_progress{done,total}|null,routine_status|null}`. 400 `WORKOUT_EMPTY` (0 done sets) -> app then `DELETE /workout-logs/{log_id}` |
| `DELETE /workout-logs/{log_id}` -> 204 | cancels/removes the log and its sets |
| `GET /workout-logs?start_date=&end_date=&status=&page=&page_size=` | both dates required, **range <= 92 days**. `summary{log_count,workout_days,total_sets,total_volume_kg,total_duration_sec,workout_dates[]}` covers the whole range (completed logs only), independent of paging. `status`: `in_progress/completed/aborted` |
| `GET /workout-logs/{log_id}` | adds `memo`, `sets[{set_id,client_set_id,set_no,version,weight_kg,reps,rest_sec,is_done}]` |

Server rules the app must respect: `started_at` is server time (compute elapsed as `now - started_at`); `in_progress` logs older than 6 h become `aborted`; aborted logs are excluded from stats/streaks.

## 4. Pitfalls checklist (verify before saying "done")

1. EXIF rotation baked in before photo upload.
2. Analysis `failed` handled as a normal 200 result.
3. Analysis/measurement `null` shown as "측정하지 못했어요", never 0.
4. Set retry re-sends the SAME `client_set_id`; persist `{client_set_id, payload}` locally before sending.
5. Elapsed workout time derived from `started_at`; rest timer stores `restEndsAt` (absolute time), not a countdown number.
6. After analysis `done`, the user presses a button to call `POST /routines`.
7. Workout history calls never exceed 92 days.
8. 401 handled in one place.
9. No `.env`/secrets in the app; no AI keys; no DB access.
10. Layout verified at 320 px width and 130% text.

## 5. Tasks

Each task = one run. Order matters; dependencies in brackets. For every task: add/extend `ApiContract`, models, repository interface + server impl + fake, view model, page, widget/unit tests, and run `flutter analyze` + `flutter test` (no new failures vs. baseline).

### T0 — Shared API client and global 401 [none]
Create `lib/core/network/api_client.dart`; extend `ApiContract` for all MVP paths; move `ServerOnboardingRepository._send` logic onto it without behavior change; add `SessionExpired` callback wired in `bootstrap.dart` -> clears `TokenStore` and navigates to login.
Done when: existing auth tests pass unchanged; unit test for `ApiClient` (header, error parsing, 401 callback fires once, multipart helper for photos).

### T1 — Session, real email verification, password reset, start routing [T0]
1. `GET /users/me` decides the first screen; consent page calls `PATCH /users/me` (all four true); logout deletes the token and goes to login; app restart restores the session.
2. Real email verification in signup (server mode): `sendEmailCode` -> `confirmEmailCode` -> pass `email_verification_token` in `POST /users`. Remove the development code (`DevelopmentEmailVerification`) from the server-mode path; keep it only for `USE_LOCAL_PREVIEW`. Handle `EMAIL_CODE_TOO_FREQUENT`, `EMAIL_CODE_LOCKED`, `EMAIL_CODE_EXPIRED`, `EMAIL_NOT_VERIFIED`, 5-minute countdown, 60-second resend cooldown, spam-folder hint.
3. Password reset (server mode) uses the code flow: `reset-request` -> `reset-verification` (code) -> `PATCH reset` (reset_token + new password). Remove any email-link-token-only path from server mode (a deep-link entry may stay, but it must still end in the same `PATCH /auth/password/reset`).
4. Login errors: `INVALID_CREDENTIALS` is shown on the form and must NOT trigger the global session-expired handler (see the 401 rule).
Done when: tests cover each start-routing branch (no token, token expired on an authenticated call, consent missing, onboarding missing, home), signup with token passes `email_verification_token`, and a login 401 does not log out or navigate.

### T2 — Body profile create/edit [T0]
`profile_form_page` supports `mode=create|edit`; edit uses `GET` + `PATCH`; show regenerate-routines prompt when `routine_refresh_recommended` is true; validate ranges client-side (server ranges in section 3).
Done when: tests for validation, 409 -> PATCH fallback, refresh prompt.

### T3 — Photos: upload and management [T0]
`features/photos`: models, repository, upload view model (uses `image_preprocessor`), photo management page (grid 3 columns, aspect 3:4, delete one/all with confirm, count `N / 20`). Reuse `photo_input_field.dart`.
Done when: preprocess step is called before upload (test with fake); errors 413/415/409/403 map to messages; list refreshes signed URLs.

### T4 — Body analysis: entry, progress, result, history [T3]
Pages: entry (front required, side optional), progress (poll 2 s, 60 s cap, resumable by `analysis_id`), result (measures/judgements/goal comparison, failed variants, usage), history. Button "맞춤 루틴 만들기" -> `POST /routines` -> routine screen.
Done when: tests for pending->done, pending->failed (each `error_code`), poll timeout, null values, 429 quota, 409 in-progress resume.

### T5 — Goal body [T3]
`features/goal_body`: form (description + optional photo), status handling with polling, edit, delete. Wire into analysis entry (optional `goal_body_id`, only when `done`).
Done when: description-only path is immediate; photo path polls; failed shows `error_message` and retry; 409 -> PATCH.

### T6 — Exercise catalog [T0]
`features/exercises`: list with part chips + equipment filter + search `q`, detail page. Selecting an exercise starts a free workout (T9) with no `routine_id`.
Done when: filters map to query params; paging works; `media_url == null` handled.

### T7 — Routines: generate, weekly, detail [T4]
`features/routines`: generation view model, weekly view (7 days incl. rest days), detail page (items with `reason`, `done`, `target_weight_kg == null` shows "직접 입력"). Start button per item -> T9 with `routine_id`.
Done when: rest day (`routine == null`) renders; replace-on-regenerate refreshes UI; tests for weekly parsing.

### T8 — Home: connect to the server, keep existing features [T7, D1 decided]
Do NOT rewrite the home screen. Keep the manual weekly schedule, repeat, rest-day overrides, local workout records, calendar, and the current design. Add server data behind the existing `HomeViewModel`/repositories (server implementations next to the local ones, selected like the onboarding repository):
- Today's exercises: if today is a training day in the local schedule and a server routine exists for that date (`/routines/today`), show the routine items; otherwise show the free-workout entry.
- Progress from `items[].done`; calendar marks from `summary.workout_dates`; today's volume from `/workout-logs` for today; "이어하기" when an `in_progress` log exists.
- When the user marks a date that has a `planned` server routine as a rest day, call `PATCH /routines/{id}` with `skipped`; when the rest day is released, apply D1-b (`planned` for today-or-later, otherwise manual pick). Best effort; local state stays authoritative; no retry storm.
- When a server routine is generated for a date that already has hand-picked exercises, apply D1-a.
- No sample/preview data in server mode. Remove "서비스 연결 준비 중" copy only where it is replaced by real data.
Done when: existing home tests still pass unchanged; new tests cover (no routine / rest day / routine present / in progress / done) and the skip sync; local-preview mode behaves exactly as before.

### T9 — Workout execution [T7, T6]
`features/workout` execution page: start log (handle 200 resumed), set input rows (weight/reps/done), rest timer (`restEndsAt`), elapsed from `started_at`, edit/delete set, cancel (DELETE log). Local draft store (`workout/data/local/`) persisting `{log_id, pending sets with client_set_id, restEndsAt}` so an app restart restores the screen. Foreground resume re-queries `GET /workout-logs?status=in_progress`.
Done when: tests for idempotent retry (same `client_set_id`), `VERSION_CONFLICT` flow, restore after restart, unsent sets block finishing.

### T10 — Workout finish summary [T9]
Complete call, summary screen (time, volume, sets, routine progress "3/4", memo), `WORKOUT_EMPTY` -> delete log + message, routine done screen when `routine_status == done`, next-exercise navigation.
Done when: tests for empty workout and routine completion.

### T11 — Workout history [T9]
Calendar (month, <=92 days per request), list, detail, edit set (with `version`), delete log. Aborted logs shown muted and excluded from totals.
Done when: tests for range limit, summary vs page independence, edit conflict, delete refreshes home.

### T12 — Settings [T1, T2, T3]
Implement `design/settings` spec (`design/settings/앱팀_전달용_스펙.md`, images `settings_board.png`): main page, profile edit, photo management (reuse T3), consent management, logout and withdrawal dialogs (withdraw requires confirm checkbox). Hide the notifications section (not MVP).
Colors and radii come from existing tokens (the hex values in the design files are reference only). The privacy-policy link and the withdrawal copy depend on open decisions D2 and D3: put them behind constants, use the values from the decision, and do not invent a URL. Until D3 is decided, keep the list item "작성한 글과 댓글" in the withdrawal dialog (the server currently deletes posts and comments).
Done when: widget tests at 320 px width and text scale 1.3 show no overflow; all rows grow, none clipped.

### T13 — Integration pass [all]
Run the full loop on a test server; fix navigation dead ends; verify pitfalls checklist (section 4); verify 401 from every screen; verify 320 px / 130% text on every new page.
Done when: a written checklist in the PR description lists each loop step with pass/fail.

## 5b. Decisions (ask before implementing the affected task)

| ID | Decision | Default to use until answered |
|---|---|---|
| D1 | Manual weekly schedule vs server routines. The app lets users pick training/rest days and repeat weekly; the server has no API for that. | Keep the manual schedule 100% local. Server routines are an optional "추천 루틴" that provides the exercise list for a day. Rest-day choice on a day with a server routine is synced with `PATCH /routines/{id}` (`skipped` / `planned`). No other server API in MVP. |
| D1-a | A date already has exercises the user picked by hand and a server routine is generated for it. | The user chooses ONE of two (never merge/append): "내 운동 유지" (default; the server routine for that date is set to `skipped`) or "추천 루틴으로 바꾸기" (confirm dialog: the hand-picked exercises of that day are removed). |
| D1-b | The user turns a rest day back into a training day. | If the date has a server routine with status `skipped` and the date is today or later: restore it with `PATCH planned` and show it. If the date is in the past, or no server routine exists: let the user pick exercises by hand (free workout). If the restore call fails, fall back to the manual pick and do not block the user. |
| D2 | Privacy-policy URL for settings | Do not invent one; leave the row disabled with a TODO constant and report it. |
| D3 | What happens to posts/comments when a user withdraws | Server deletes them. MVP has no community screens, so keep dialog copy as is and report. |
| D4 | One shared Flutter version for the team (golden tests depend on it). Proposed: **Flutter 3.41.6 / Dart 3.11.4** (all tests pass there; equals the minimum Dart in `pubspec.yaml`). Awaiting the project lead's confirmation. | Use Flutter 3.41.6 if it is installed. If `flutter --version` differs, record it and report; never update goldens on your own. |

## 6. Out of scope for MVP (do not build, keep "준비 중")

AI coach tab, community tab, diet plans, allergies, workout statistics screens, text analysis, correction exercises, streak screen, partner products, missions, coupons, push notifications, Google/Kakao login, password change (no API), profile photo, admin features.
(Password reset exists and is connected; leave it as is.)

## 7. When unsure

- Contract unclear -> read `openapi.yaml`; still unclear -> ask, do not invent fields.
- Design unclear -> follow `design/settings` and existing screens; keep Korean copy consistent with existing strings.
- Scope creep -> do the task as written; list extra ideas in the final message instead of implementing them.

Final message of every task must include: files changed, tests added, `flutter analyze` result, `flutter test` result vs. baseline, and any assumption you made.
