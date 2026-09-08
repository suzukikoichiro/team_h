# Refactoring Roadmap

## Scope

This roadmap primarily covers the Godot project at `C:\卒業制作\2-dmetaverse`, which is the project exported by `tools/export_windows_desktop.ps1`.

The repository root also contains the Django backend Git repository at `C:\卒業制作\team_h`, a Python virtual environment, generated builds, expanded SDKs, and documents. The backend and Godot client should be managed as separate source boundaries so client exports do not depend on unrelated working files.

## Current Technical Debt

### 1. Oversized Godot scripts

Several scripts combine UI construction, API orchestration, state management, formatting, and persistence in one file:

| File | Lines | Main issue |
| --- | ---: | --- |
| `scenes/chat.gd` | 326 | Contact list and realtime event handling are still coupled, but thin lobby-room and room-peer lookup wrappers, local Global/LocalLog access wrappers, and an unused chat-delete send wrapper were removed, and root HUD/World lookup and lobby-room naming, single-message add/remove view operations, send-success side effects, thin fit/font/fetch/input-height wrappers, current-room history rendering, auto-open unread-room selection, room message merge-state updates, incoming realtime message state updates, realtime message cache insertion, room-state creation, unread count mutation, duplicate read-state clearing, chat input Enter-key handling, realtime connection checks, empty-state UI reflection, strong-font application, Django chat API calls, chat-history clear state reset, contact-list entry collection, UI/Network/DjangoApi/Global signal wiring, send-payload validation/construction, chat input height calculation, private-chat permission checks, temporary reply policy, chat UI rendering, local contact cache persistence/lookup, room-state collection, latest-unread selection, message merging, room-name parsing/construction, unread sender extraction, common node clearing, and centered panel sizing now live behind helpers/accessors. |
| `scenes/network.gd` | 321 | Nakama transport, fallback WebSocket transport, chat relay, and reconnect policy are still coupled, but thin temporary-reply sender, state-request, and world-packet cache wrappers, unused state-sync retry, and ping timer state were removed, and Nakama/World root lookup, Nakama sender-to-app-user tracking, timeout/reconnect state mutation, connection-attempt state setup, thin transport reset wrappers, process-loop fallback transition handling, Nakama disconnect checks, Nakama connected-state updates, world-event send routing, Nakama room join result normalization, fallback transport setup/connected-state updates, Nakama session path lookup, Nakama received-event action classification, fallback WebSocket packet parsing, process-loop connection state checks, transport/runtime state resets, Nakama channel payload normalization, Nakama presence-leave cache cleanup, Nakama channel readiness/room registration, room naming, player state cache updates, Nakama event payload parsing/construction, channel-message context parsing, shared transport close/state/send checks, and connection flag resets now live behind helpers. |
| `scripts/memo_panel.gd` | 324 | Personal memo UI, status transitions, and API handling are still coupled, but thin teacher-distribution signal wrappers, status-state UI reflection, thin API/filter/schedule wrappers, selected-memo clear-state reset, memo-list scroll/grid construction, editor layout/action rows, memo fetch/teacher-target loading, selected-memo state comparison, panel shell/layout rows, teacher distribution submit/success UI handling, editor reset/edit UI state reflection, API signal wiring, selected-memo status/delete/edit validation and submission, personal save/autosave validation and submit branching, teacher distribution validation/request payload creation, personal schedule picker wiring, personal schedule option synchronization, personal schedule ISO construction, personal schedule calendar rendering, memo status normalization, status-button/input styling, schedule visibility updates, memo list rendering/empty states, memo card rendering, teacher distribution form/list rendering, schedule/date calculations, teacher schedule option/date handling, editor widgets, list filter toolbar, panel-state UI updates, memo payload construction, popup sizing, option selection, common text-edit handling, common node clearing, responsive grid sizing, panel sizing, and display styling have moved to helper scripts. |
| `scripts/hud.gd` | 274 | HUD panel selection, unread chat state, nearby talk UI, and logout flow are still coupled, but thin memo-button styling and temporary-reply forwarding wrappers were removed, and root World lookup and lobby-room naming, HUD child front-order handling, unread room mutation/badge reflection, nearby-talk button state, menu open/close UI state, color-filter state mapping, logged-in UI state, active-HUD UI detection, reusable panel attach/focus/open/exit lifecycle, settings-panel opening, HUD signal wiring, unread chat message/room-state collection, panel login checks, talk-choice rendering, quick-button styling, talk-button construction, and unread badge construction now live behind helper scripts. |
| `scripts/lesson_panel.gd` | 307 | Live lessons, recordings, comments, file upload, and growth events are still coupled, but thin lesson-card, URL-open, and live-stream ownership wrappers were removed, and teacher live/recording form actions and reset behavior, detail-panel construction, teacher live/recording forms, common labels, buttons, input widgets, child clearing, panel/card styles, lesson-card rendering, and comment rendering now use shared helper scripts. |
| `scripts/api_client.gd` | 312 | All backend endpoints still share one autoload, but login/auto-login response handling, HTTPRequest registration, login-state reset/cookie extraction, endpoint path/query and payload construction, lesson-recording upload request preparation, multipart body construction, authenticated/unauthenticated GET, JSON POST, raw multipart POST setup, auth-header construction, busy-request cancellation, start-failure reporting, response parsing/failure handling, response-handler dispatch, chat/profile/lesson response emission, profile-avatar response handling, and endpoint domain grouping now sit behind helpers. |
| `scripts/profile_panel.gd` | 298 | Profile editor state, avatar picker, profile search drawer, and locate-user behavior are still coupled, but thin search-result clear/card and drawer-request wrappers were removed, and edit-form construction, common labels, styles, child clearing, centered panel sizing, search-result card rendering, skin-choice UI, avatar texture lookup, and profile form widgets now use helper scripts. |
| `world.gd` | 264 | World scene setup, player spawning, room transitions, and UI singleton coordination still live in one scene script, but direct HUD root lookup and thin player-meta wrapper were removed, and player meta/contact normalization plus nearby-chat permission checks now live behind helpers/accessors. |
| `scripts/player.gd` | 227 | Player input, network sync, chat bubbles, and stamps are still coupled in the player controller, but avatar SpriteFrames construction now lives in `scripts/player_avatar.gd`. |
| `scripts/calendar_panel.gd` | 235 | Calendar memo filtering, popup sizing, and API handling still share one panel script, but event-card, day-button, event-time, and time-option UI construction now live in `scripts/calendar_widgets.gd`. |

Additional audited scripts are now below the main oversized-file threshold: `scripts/settings_panel.gd` is 123 lines after moving chat option/history UI construction into `scripts/settings_chat_options.gd`, and `scenes/login.gd` is 110 lines after moving the mood/permission chooser into `scripts/login_mood_panel.gd`.

### 2. Runtime configuration is still partly hardcoded

`scripts/app_config.gd` centralizes the main endpoints, but the default values still include local loopback URLs, a public ngrok URL, placeholder Nakama host values, and default keys. Environment overrides exist, but export profiles and deployment documentation do not yet make those settings explicit.

### 3. UI code is created imperatively in large panels

Memo, chat, calendar, lesson, and profile panels create many controls in script. This makes layout changes risky and makes it hard to test logic without rendering the entire panel.

### 4. API response handling is repetitive

`scripts/api_client.gd` repeatedly parses JSON, checks status codes, emits request failures, and builds auth headers. Small inconsistencies can become bugs as more endpoints are added.

### 5. Global singletons are tightly coupled

Many scripts directly use `Global`, `DjangoApi`, `Network`, `LocalLog`, and `/root/Main/...`. This is normal for a small Godot project, but it now makes panels hard to reuse or test independently.

### 6. Repository boundary is unclear

At `C:\卒業制作`, generated folders and dependencies are mixed with source folders: `build`, `venv`, expanded `nakama-godot-v3.4.0`, generated `staticfiles`, local `db.sqlite3`, and documents. The actual Git repository currently detected is `C:\卒業制作\team_h`, not `C:\卒業制作\2-dmetaverse`.

The backend repository already ignores `staticfiles/`, `media/backups/`, `media/lesson_videos/`, and `db.sqlite3`, but those generated artifacts still appear in the current Git working tree because they were previously tracked or modified. They should be removed from version control in a dedicated cleanup pass, after confirming deployment still collects static files and builds the Godot web package reproducibly.

### 7. Backend API module decomposition

`C:\卒業制作\team_h\core\views\manage_api_views.py` is now a 2-line compatibility module. The former oversized API surface has been split by domain: student management lives in `core/views/student_manage_api_views.py`, Godot auto-login/Nakama/logout lives in `core/views/godot_session_api_views.py`, chat users/rooms/messages/read/clear lives in `core/views/chat_api_views.py`, growth summary/event endpoints live in `core/views/growth_api_views.py`, profile endpoints live in `core/views/profile_api_views.py`, memo endpoints live in `core/views/memo_api_views.py`, lesson endpoints and lesson video upload handling live in `core/views/lesson_api_views.py`, backup pages already live in `core/views/backup_views.py`, and shared request/user payload helpers live in `core/views/api_common.py`.

`core/consumers.py` still uses in-memory world/chat state (`CHAT_HISTORY`, `WORLD_STATE`) suitable for local development but fragile for multiple workers or restarts. It now uses module logging instead of direct `print()` calls, but the state backend remains a future scaling concern.

## Refactoring Phases

### Phase 0: Guardrails and low-risk cleanup

Status: completed.

- Keep the Windows Desktop export as the verification gate after edits.
- Document the debt and intended sequence in this file.
- Route debug output through `LocalLog` and add a config switch for console logs.
- Avoid behavior-changing edits in oversized scripts until helper seams are in place.

### Phase 1: API client extraction

Status: started.

Goal: reduce `scripts/api_client.gd` without changing endpoint behavior.

- Add small helpers for JSON parsing, request failure emission, and authenticated JSON requests.
- Group endpoint methods by domain in clearly marked sections: auth, chat, profile, memo, lessons, growth.
- Only after helpers stabilize, split domain API clients into child nodes or small helper scripts.

### Phase 2: Reusable UI builders

Status: started.

Goal: reduce duplicated imperative UI code.

- Extract common UI helpers for panel headers, buttons, cards, status labels, empty states, and confirmation dialogs.
- Apply first to `memo_panel.gd` and `calendar_panel.gd`, because both contain date/event UI.
- Keep scene files stable while helpers are introduced.

### Phase 3: Memo panel decomposition

Status: started.

Goal: split the largest script safely.

- Extract schedule/date-picker logic from `memo_panel.gd`.
- Extract teacher distribution target selection.
- Extract memo card rendering.
- Leave `memo_panel.gd` as a coordinator that owns the existing scene contract.

### Phase 4: Chat and HUD lifecycle cleanup

Status: started.

Goal: make panel opening, closing, and unread-state behavior predictable.

- Introduce one panel lifecycle helper in `hud.gd`.
- Extract chat message rendering and room/contact cache helpers from `scenes/chat.gd`.
- Replace repeated `/root/Main/...` lookups with small accessor methods first, then consider dependency injection later.

### Phase 5: Network transport separation

Status: started.

Goal: separate realtime transport concerns.

- Extract packet cache and room naming helpers from `scenes/network.gd`.
- Separate Nakama-specific logic from fallback WebSocket logic behind a common send/receive contract.
- Keep signals unchanged until both transports are covered by manual export checks.

### Phase 6: Repository hygiene

Goal: make the project boundary obvious.

- Decide whether `2-dmetaverse` should become its own Git repository or be imported into the existing repo.
- Ignore generated folders and local state: `.godot`, `build`, `venv`, `staticfiles`, `db.sqlite3`, generated logs, and expanded SDK archives.
- Keep third-party SDK source in a clear vendor directory or document how to reinstall it.

### Phase 7: Backend API decomposition

Status: completed for view-module decomposition; realtime state backend remains a scaling follow-up.

Goal: reduce risk in the Django backend without changing API contracts used by the Godot client.

- Split `core/views/manage_api_views.py` into domain modules: student management, Godot auth/Nakama/logout, chat, growth, profile, memo, lesson, and backup.
- Use `core/views/student_manage_api_views.py`, `core/views/godot_session_api_views.py`, `core/views/chat_api_views.py`, `core/views/growth_api_views.py`, `core/views/profile_api_views.py`, `core/views/memo_api_views.py`, `core/views/lesson_api_views.py`, and `core/views/api_common.py` as the completed split pattern.
- Keep URL names and JSON response shapes stable while moving code.
- Replace local in-memory realtime state with a documented cache/channel-layer strategy if the app is deployed with multiple workers.
- Keep generated `staticfiles`, local SQLite, media uploads, and exported Godot web artifacts out of source control once deployment/build reproduction is documented.

## Completed in this pass

- Added `AppConfig.console_logging_enabled()` with `METAVERSE_CONSOLE_LOGS` override.
- Changed `LocalLog.write()` so console output is optional while file logging remains enabled.
- Replaced direct debug `print()` calls in core Godot scripts with `LocalLog.write()`.
- Started Phase 1 by adding `api_client.gd` response helpers and applying them to simple chat, memo, lesson, profile search, and growth response handlers.
- Extended Phase 1 by adding shared JSON auth headers, a `_post_json()` helper, body-error response handling, and by reducing `scripts/api_client.gd` from 845 to 721 lines.
- Continued Phase 1 by adding authenticated GET and busy-request cancellation helpers, grouping endpoint methods by domain, centralizing simple response-field signal emission, and reducing repeated HTTPRequest setup loops in `scripts/api_client.gd`.
- Added `scripts/api_response.gd` and moved JSON parsing, response failure handling, body-error field emission, and profile response failure handling out of `scripts/api_client.gd`, reducing it to 698 lines.
- Started Phase 2 by adding `scripts/ui_factory.gd` and routing common label, filled-button, and style creation through it in memo, calendar, profile, and lesson panels.
- Started Phase 3 by adding `scripts/memo_schedule.gd`, extracting date, ISO timestamp, month movement, and day-count calculations from `memo_panel.gd`, reducing it to 1316 lines.
- Continued Phase 3 by adding `scripts/memo_status_style.gd` and moving memo status colors, input colors, border colors, and status-button styling out of `memo_panel.gd`, reducing it to 1258 lines.
- Continued Phase 3 by adding `scripts/memo_text.gd` and moving memo preview/time formatting out of `memo_panel.gd`, reducing it to 1247 lines.
- Continued Phase 3 by adding `scripts/memo_card.gd` and moving memo card construction out of `memo_panel.gd`, reducing it to 1204 lines.
- Continued Phase 3 by adding `scripts/memo_teacher_targets.gd` and moving teacher class/student target list rendering out of `memo_panel.gd`, reducing it to 1160 lines.
- Continued Phase 3 by adding `scripts/memo_schedule_widgets.gd` and moving schedule option, weekday label, spacer, and calendar day button creation out of `memo_panel.gd`, reducing it to 1123 lines.
- Extended `scripts/memo_schedule_widgets.gd` with schedule picker construction, leaving `memo_panel.gd` to wire returned controls and callbacks, reducing it to 1091 lines.
- Added `scripts/memo_teacher_form.gd` and moved teacher distribution form construction out of `memo_panel.gd`; also moved schedule calendar grid rendering into `memo_schedule_widgets.gd`, reducing `memo_panel.gd` to 995 lines.
- Added `scripts/memo_editor_widgets.gd` and moved memo editor text input and mode-button construction out of `memo_panel.gd`, reducing it to 969 lines.
- Started Phase 4 by consolidating HUD panel login checks, panel focus, add-to-HUD behavior, and menu button state helpers in `scripts/hud.gd`, reducing it from 662 to 643 lines.
- Continued Phase 4 by adding `scripts/hud_talk_choices.gd`, moving nearby-talk choice rendering out of `scripts/hud.gd`, and centralizing HUD login UI state, world-node lookup, and lobby-room naming; `hud.gd` is now 615 lines.
- Added `scripts/chat_widgets.gd` and moved chat contact button, message bubble, and unread divider rendering out of `scenes/chat.gd`, reducing it from 840 to 744 lines.
- Added `scripts/chat_contacts.gd` and moved chat contact normalization, local JSON load/save, and room-to-contact lookup out of `scenes/chat.gd`, reducing it further to 697 lines.
- Added `scripts/chat_room_state.gd` and moved chat room-state collection, latest-unread selection, message merging, and message existence checks out of `scenes/chat.gd`, reducing it to 656 lines.
- Started Phase 5 by adding `scripts/network_rooms.gd` and `scripts/network_state_cache.gd`, moving room-name construction and player-state cache updates out of `scenes/network.gd`, reducing it from 579 to 553 lines.
- Continued Phase 5 by adding `scripts/network_events.gd`, moving Nakama event payload construction out of `scenes/network.gd`, and cleaning a presence-leave indentation issue, reducing it to 536 lines.
- Extended `scripts/network_events.gd` with received-event accessors and moved Nakama event field parsing out of `scenes/network.gd`, reducing it to 532 lines.
- Continued Phase 2 by adding `scripts/lesson_card.gd` and `scripts/profile_result_card.gd`, moving lesson cards and profile search-result cards out of their panel coordinators; `lesson_panel.gd` is now 549 lines and `profile_panel.gd` is now 534 lines.
- Extended `scripts/ui_factory.gd` with shared `LineEdit` and `TextEdit` builders and routed lesson/profile inputs through them, reducing `lesson_panel.gd` to 536 lines.
- Added `scripts/lesson_comments.gd` and `scripts/profile_skin_choices.gd`, moving lesson comment rendering and profile skin-choice popup construction out of their panel coordinators; `lesson_panel.gd` is now 525 lines and `profile_panel.gd` is now 519 lines.
- Added `scripts/memo_filter.gd` and moved memo list toolbar construction, filter-state conversion, visible-memo filtering, and selected memo detail formatting out of `memo_panel.gd`, reducing it to 904 lines.
- Added `scripts/memo_payload.gd` and moved personal save/update payloads, planned-status fallback scheduling, and teacher distribution payload construction out of `memo_panel.gd`, reducing it to 888 lines.
- Added `scripts/memo_panel_state.gd` and moved memo view switching, personal screen switching, and selected-memo control/detail updates out of `memo_panel.gd`; also removed the now-unused filter detail formatter, reducing `memo_panel.gd` to 848 lines.
- Added `scripts/api_http_registry.gd` and collapsed duplicated HTTPRequest node/handler registration tables in `scripts/api_client.gd` into one registry table, reducing it to 682 lines.
- Added `scripts/api_login_state.gd` and moved repeated login, auto-login, and local-guest state application into a shared helper, reducing `scripts/api_client.gd` to 631 lines.
- Added `scripts/api_paths.gd` and moved repeated query-string construction plus simple memo/id payload construction out of `scripts/api_client.gd`, reducing it to 620 lines.
- Added `scripts/api_multipart.gd` and moved lesson-recording multipart body/header construction out of `scripts/api_client.gd`, reducing it to 596 lines.
- Extended `scripts/api_response.gd` with typed multi-field signal emission and applied it to memo, teacher memo, and lesson comment response handlers, reducing `scripts/api_client.gd` to 591 lines.
- Moved login cookie extraction into `scripts/api_login_state.gd`, reducing `scripts/api_client.gd` to 578 lines.
- Moved memo panel's remaining local label/button/style wrappers to direct shared helper usage and extracted OptionButton popup sizing into `scripts/ui_factory.gd`, reducing `scripts/memo_panel.gd` to 796 lines.
- Added shared `UiFactory` helpers for option selection, child clearing, text-edit menu/caret handling, responsive grid columns, and centered panel sizing; `scripts/memo_panel.gd` now delegates those details and is down to 738 lines.
- Applied the shared `UiFactory` and `MemoSchedule` helpers to `scripts/calendar_panel.gd`, removing local label/button/style, popup, option-selection, panel-sizing, month/day, and minute-rounding helpers; `calendar_panel.gd` is down to 355 lines.
- Applied shared `UiFactory` label, style, child-clearing, and centered-panel sizing helpers to `scripts/profile_panel.gd`, reducing it to 503 lines.
- Removed remaining input and child-clearing wrappers from `scripts/lesson_panel.gd` in favor of direct `UiFactory` calls, reducing it to 512 lines.
- Routed chat contact/message clearing and centered panel sizing through `scripts/ui_factory.gd`, and centralized `World` node access in `scenes/chat.gd`; `chat.gd` is now 644 lines.
- Centralized repeated HUD panel-exit cleanup for memo, calendar, chat, profile, and lesson panels in `scripts/hud.gd`; `hud.gd` is now 614 lines.
- Added `scripts/network_transport_state.gd` and moved repeated WebSocket ready-state checks, fallback send, and transport close handling out of `scenes/network.gd`, reducing it to 520 lines.
- Centralized connection-attempt setup plus transport/runtime reset flags in `scenes/network.gd`, reducing it to 519 lines.
- Extended `scripts/network_events.gd` with Nakama channel-message context and dictionary payload helpers, moving JSON parse/source-room/message-id normalization out of `scenes/network.gd`; `network.gd` is now 523 lines.
- Extended `scripts/api_paths.gd` with chat read/clear, lesson stream/comment, and growth-event payload builders, reducing inline endpoint payload construction in `scripts/api_client.gd`; `api_client.gd` is now 577 lines.
- Extended the shared `_post_json()` request helper with optional busy-request cancellation and start-failure reporting, and applied the matching GET helper path to chat-message loading; `api_client.gd` is now 578 lines.
- Moved login payload construction into `scripts/api_paths.gd` and routed `login()` through the shared POST helper while preserving login-specific logging and failure signals; `api_client.gd` is now 576 lines.
- Added an unauthenticated shared `_get_request()` helper and moved the auto-login path into `scripts/api_paths.gd`, leaving direct request calls only in shared request helpers and multipart upload; `api_client.gd` is now 580 lines.
- Added a shared `_post_raw()` helper and moved the lesson-recording upload path into `scripts/api_paths.gd`, leaving HTTPRequest calls centralized inside request helpers; `api_client.gd` is now 579 lines.
- Moved the remaining fixed API endpoint paths out of `scripts/api_client.gd` and into `scripts/api_paths.gd`, so the client no longer contains direct `/api/` path literals; `api_client.gd` remains 579 lines.
- Added local response dictionary wrappers in `scripts/api_client.gd`, leaving direct `ApiResponse.dictionary_or_fail*` calls centralized behind helper methods; `api_client.gd` is now 587 lines.
- Added `ApiResponse` helpers for chat message emission, chat-history-clear emission, and lesson-stream-end emission, reducing response-specific branching in `scripts/api_client.gd`; `api_client.gd` is now 571 lines.
- Added `ApiResponse` helpers for chat-save follow-up emission and profile response/avatar emission, reducing more endpoint-specific response branching in `scripts/api_client.gd`; `api_client.gd` is now 562 lines.
- Added `scripts/profile_avatar.gd` and `scripts/profile_form_widgets.gd`, moving avatar texture lookup and profile form/search button construction out of `scripts/profile_panel.gd`; `profile_panel.gd` is now 425 lines.
- Added `scripts/lesson_widgets.gd` and moved lesson panel labels, buttons, icon buttons, and panel/card styles out of `scripts/lesson_panel.gd`; `lesson_panel.gd` is now 479 lines.
- Extended `scripts/chat_room_state.gd` with private-room construction, direct-message room parsing, lobby-room checks, and unread sender extraction; `scenes/chat.gd` is now 616 lines.
- Added `scripts/hud_widgets.gd` and moved HUD talk-button, quick-button, quick-memo styling, and unread badge construction out of `scripts/hud.gd`; `hud.gd` is now 533 lines.
- Extended `scripts/memo_schedule_widgets.gd` with teacher schedule option initialization, day-list refresh, and teacher schedule ISO construction; `scripts/memo_panel.gd` is now 721 lines.
- Added `scripts/memo_list.gd` and moved memo list clearing, visible-list rendering, empty-state labels, and memo card insertion out of `scripts/memo_panel.gd`; `scripts/memo_panel.gd` is now 699 lines.
- Extended `scripts/memo_panel_state.gd` with memo status normalization, status-button styling, memo input styling, and schedule visibility updates; `scripts/memo_panel.gd` is now 668 lines.
- Extended `scripts/memo_schedule_widgets.gd` with personal schedule option synchronization, personal schedule ISO construction, and personal calendar rendering; `scripts/memo_panel.gd` is now 654 lines.
- Added `scripts/chat_policy.gd` and moved private-chat permission checks, teacher detection, send-permission checks, and temporary reply allowance handling out of `scenes/chat.gd`; `scenes/chat.gd` is now 573 lines.
- Added `scripts/memo_teacher_distribution.gd` and moved teacher distribution validation plus request payload creation out of `scripts/memo_panel.gd`; `scripts/memo_panel.gd` is now 649 lines.
- Added `scripts/api_request.gd` and moved auth-header construction, JSON/raw POST startup, authenticated/unauthenticated GET startup, busy-request cancellation, and start-failure reporting out of `scripts/api_client.gd`; also removed the unused client-side `json_auth_headers()` wrapper. `scripts/api_client.gd` is now 535 lines.
- Added `scripts/memo_personal_actions.gd` and moved personal memo save/autosave validation plus create/update submit branching out of `scripts/memo_panel.gd`; `scripts/memo_panel.gd` is now 644 lines.
- Added `scripts/memo_selected_actions.gd` and moved selected-memo status/delete/edit validation plus status/delete submission out of `scripts/memo_panel.gd`; `scripts/memo_panel.gd` is now 640 lines.
- Added `scripts/chat_message_actions.gd` and moved chat send-payload validation/construction out of `scenes/chat.gd`; also moved chat input height calculation into `scripts/chat_widgets.gd`. `scenes/chat.gd` is now 568 lines.
- Added `scripts/hud_unread_state.gd` and moved HUD unread chat message/room update collection out of `scripts/hud.gd`; `scripts/hud.gd` is now 527 lines.
- Added `scripts/network_nakama_channels.gd` and moved Nakama channel readiness checks, channel lookup, and room registration helpers out of `scenes/network.gd`; `scenes/network.gd` is now 522 lines.
- Added `scripts/memo_api_connections.gd` and moved memo API signal wiring out of `scripts/memo_panel.gd`; `scripts/memo_panel.gd` is now 630 lines.
- Extended `scripts/memo_panel_state.gd` with editor reset/edit/clear helpers, moving more editor UI state reflection out of `scripts/memo_panel.gd`; `scripts/memo_panel.gd` is now 621 lines.
- Extended `scripts/memo_teacher_distribution.gd` with teacher distribution submit and success UI helpers, reducing `scripts/memo_panel.gd` to 619 lines.
- Added `scripts/chat_connections.gd` and moved chat UI/Network/DjangoApi/Global signal wiring out of `scenes/chat.gd`; `scenes/chat.gd` is now 555 lines.
- Added `scripts/memo_panel_layout.gd` and moved memo panel shell, teacher-mode row, personal-screen row, and shared section container construction out of `scripts/memo_panel.gd`; current top file counts were refreshed and `scripts/memo_panel.gd` is now 437 lines.
- Added `scripts/chat_contact_entries.gd` and moved chat contact-list entry collection out of `scenes/chat.gd`; `scenes/chat.gd` is now 423 lines.
- Added `scripts/network_process_state.gd` and moved network process-loop timeout/reconnect/fallback WebSocket state checks out of `scenes/network.gd`; `scenes/network.gd` is now 424 lines.
- Added `scripts/hud_connections.gd` and moved HUD DjangoApi/Global/Network signal wiring out of `scripts/hud.gd`; `scripts/hud.gd` is now 407 lines.
- Extended `scripts/memo_selected_actions.gd` with selected-memo state comparison so `scripts/memo_panel.gd` no longer owns the repeated-selection decision; `scripts/memo_panel.gd` remains 437 lines.
- Extended `scripts/chat_room_state.gd` with single/multi-room history-clear state reset helpers and removed duplicate dictionary reset code from `scenes/chat.gd`; `scenes/chat.gd` is now 411 lines.
- Extended `scripts/network_state_cache.gd` with Nakama presence-leave cache cleanup and leave-packet construction, reducing `scenes/network.gd` to 420 lines.
- Added `scripts/lesson_teacher_forms.gd` and moved teacher live/recording form construction out of `scripts/lesson_panel.gd`, reducing it to 359 lines.
- Added `scripts/hud_panel_lifecycle.gd` and moved repeated HUD panel focus/open/exit wiring out of `scripts/hud.gd`, reducing it to 386 lines.
- Extended `scripts/network_events.gd` with Nakama channel payload normalization, reducing `scenes/network.gd` to 414 lines.
- Added `scripts/chat_api.gd` and moved Django chat API call guards out of `scenes/chat.gd`, reducing it to 407 lines.
- Extended `scripts/api_login_state.gd` with logout-state reset handling, reducing `scripts/api_client.gd` to 364 lines.
- Extended `scripts/chat_widgets.gd` with empty-state UI and strong-font application helpers, reducing `scenes/chat.gd` to 402 lines.
- Extended `scripts/network_transport_state.gd` with transport/runtime reset helpers, reducing `scenes/network.gd` to 402 lines.
- Added `scripts/memo_fetch.gd` and moved memo fetch/teacher-target loading conditions out of `scripts/memo_panel.gd`, reducing it to 433 lines.
- Added `scripts/chat_realtime.gd` and moved chat realtime connection checks/connect call guards out of `scenes/chat.gd`, reducing it to 397 lines.
- Extended `scripts/network_transport_state.gd` with fallback WebSocket packet parsing, reducing `scenes/network.gd` to 399 lines.
- Added `scripts/hud_ui_state.gd` and moved logged-in HUD visibility plus active-HUD UI detection out of `scripts/hud.gd`, reducing it to 374 lines.
- Extended `scripts/memo_editor_widgets.gd` with status-row, editor-layout, and primary-action builders, reducing `scripts/memo_panel.gd` to 406 lines.
- Extended `scripts/network_events.gd` with Nakama received-event action classification, reducing `scenes/network.gd` to 389 lines.
- Extended `scripts/chat_widgets.gd` with chat input enter-key handling, reducing `scenes/chat.gd` to 386 lines.
- Added `scripts/lesson_detail_widgets.gd` and moved lesson detail-panel construction out of `scripts/lesson_panel.gd`, reducing it to 335 lines.
- Added `scripts/profile_edit_widgets.gd` and moved the public-profile edit form, avatar preview frame, and save-button construction out of `scripts/profile_panel.gd`, reducing it from 425 to 373 lines.
- Added `scripts/api_response_handlers.gd` and moved response-handler dispatch for chat, profile, memo, lesson, and growth endpoints out of `scripts/api_client.gd`, reducing it from 518 to 489 lines.
- Extended `scripts/hud_ui_state.gd` with color-filter mode mapping and routed `scripts/hud.gd` through it, reducing `hud.gd` from 485 to 472 lines.
- Added `scripts/settings_chat_options.gd` and moved settings-panel chat option/history-delete UI construction plus chat-room target formatting out of `scripts/settings_panel.gd`, reducing it from 208 to 123 lines.
- Added `scripts/login_mood_panel.gd` and moved login mood/permission chooser UI construction out of `scenes/login.gd`, reducing it from 190 to 110 lines.
- Added the Nakama session endpoint to `scripts/api_paths.gd` and removed the remaining direct `/api/nakama_session/` literal from `scenes/network.gd`; direct `/api/` path literals are now centralized in `scripts/api_paths.gd`.
- Extended `scripts/chat_room_state.gd` with realtime message cache insertion, room-state initialization, and unread count mutation helpers, reducing `scenes/chat.gd` from 492 to 475 lines.
- Extended `scripts/memo_panel_layout.gd` with memo-list scroll/grid construction and removed that UI setup block from `scripts/memo_panel.gd`, reducing it from 521 to 510 lines.
- Extended `scripts/network_transport_state.gd` with fallback transport setup and connected-state helpers, reducing `scenes/network.gd` from 490 to 483 lines.
- Extended `scripts/hud_panel_lifecycle.gd` with settings-panel opening and close-signal wiring, reducing `scripts/hud.gd` from 472 to 462 lines.
- Extended `scripts/memo_schedule_widgets.gd` with personal schedule picker owner wiring and removed an unused memo status-style preload, reducing `scripts/memo_panel.gd` from 510 to 476 lines.
- Consolidated `send_move`/`send_stamp` world-event routing and moved Nakama room join result normalization into `scripts/network_nakama_channels.gd`, reducing `scenes/network.gd` from 483 to 470 lines.
- Added `scripts/api_lesson_upload.gd` and moved lesson-recording file read plus upload request preparation out of `scripts/api_client.gd`, reducing it from 489 to 487 lines.
- Extended `scripts/chat_room_state.gd` with incoming realtime message state updates, restored the pre-state-update lobby guard, and removed duplicate read-state clearing in `scenes/chat.gd`; `scenes/chat.gd` is now 476 lines.
- Extended `scripts/memo_panel_state.gd` with selected-memo clear-state reset handling, reducing `scripts/memo_panel.gd` from 476 to 472 lines.
- Extended `scripts/chat_room_state.gd` with room message merge-state updates, reducing `scenes/chat.gd` from 476 to 474 lines.
- Extended `scripts/network_transport_state.gd` with Nakama connected-state updates and routed the primary room join through `scripts/network_nakama_channels.gd`, reducing `scenes/network.gd` to 369 lines.
- Added `scripts/world_player_state.gd` and moved player meta/contact normalization plus nearby-chat permission checks out of `world.gd`, reducing it from 303 to 265 lines.
- Extended `scripts/network_process_state.gd` with Nakama disconnect checks and fallback transition application, reducing `scenes/network.gd` from 369 to 356 lines.
- Extended `scripts/chat_widgets.gd` with current-room history rendering and `scripts/chat_room_state.gd` with unread auto-open selection, reducing `scenes/chat.gd` from 370 to 365 lines.
- Extended `scripts/hud_ui_state.gd` with menu open/close UI state application, reducing `scripts/hud.gd` from 359 to 353 lines.
- Extended `scripts/memo_schedule_widgets.gd` with personal date selection handling and removed thin fit/caret/schedule wrappers from `scripts/memo_panel.gd`, reducing it from 359 to 348 lines.
- Removed thin fit/font/API-fetch/input-height wrappers from `scenes/chat.gd`, routing directly through existing shared helpers and reducing the current working-tree file from 467 to 442 lines.
- Extended `scripts/hud_talk_choices.gd` with nearby-talk button state application, reducing the current working-tree `scripts/hud.gd` from 456 to 449 lines.
- Extended `scripts/api_login_state.gd` with login, auto-login, and local-guest response application helpers, reducing the current working-tree `scripts/api_client.gd` from 487 to 448 lines.
- Extended `scripts/network_transport_state.gd` with connection-attempt state setup and removed thin reset wrappers from `scenes/network.gd`, reducing it from 448 to 434 lines.
- Extended `scripts/memo_schedule_widgets.gd` with direct personal picker initialization/month movement and removed thin API/filter/schedule wrappers from `scripts/memo_panel.gd`, reducing it from 452 to 418 lines.
- Extended `scripts/hud_unread_state.gd` with unread-room mutation and badge reflection helpers, reducing `scripts/hud.gd` from 449 to 438 lines.
- Extended `scripts/chat_message_actions.gd` with send-success side effects, reducing the current working-tree `scenes/chat.gd` from 352 to 351 lines, and refreshed the hotspot table with current measured counts.
- Extended `scripts/network_transport_state.gd` with timeout and reconnect state mutation helpers, reducing `scenes/network.gd` from 348 to 341 lines.
- Added `scripts/lesson_actions.gd` and moved teacher live/recording form validation, payload construction, and saved-form reset behavior out of `scripts/lesson_panel.gd`, reducing it from 335 to 314 lines.
- Extended `scripts/memo_panel_state.gd` with status-state UI reflection, reducing `scripts/memo_panel.gd` from 329 to 328 lines.
- Extended `scripts/chat_widgets.gd` with single-message add/remove view operations, reducing `scenes/chat.gd` from 351 to 345 lines.
- Extended `scripts/network_state_cache.gd` with Nakama sender-to-app-user tracking, reducing `scenes/network.gd` from 341 to 334 lines.
- Extended `scripts/hud_ui_state.gd` with HUD child front-order handling, reducing `scripts/hud.gd` from 337 to 327 lines.
- Added `scripts/app_nodes.gd` to centralize root HUD/World lookups and lobby-room naming, reducing `scenes/chat.gd` from 345 to 342 lines and `scripts/hud.gd` from 327 to 324 lines; also restored deferred validity checks for HUD child front-order handling.
- Extended `scripts/app_nodes.gd` to cover the Nakama autoload and routed Network's temporary reply forwarding through `scripts/chat_policy.gd`, reducing `scenes/network.gd` from 334 to 330 lines.
- Routed HUD's temporary reply forwarding through `scripts/chat_policy.gd`, reducing `scripts/hud.gd` from 324 to 321 lines.
- Removed the unused `_send_delete()` wrapper from `scenes/chat.gd`, reducing it from 342 to 339 lines.
- Extended `scripts/app_nodes.gd` with shared LocalLog writing and global-value access helpers, removing local wrappers from `scenes/chat.gd` and reducing it from 339 to 330 lines.
- Removed unused `STATE_SYNC_RETRY_DELAY` and `ping_timer` state from `scenes/network.gd`, reducing it from 330 to 328 lines.
- Removed thin state-request and world-packet cache wrappers from `scenes/network.gd`, reducing it from 328 to 324 lines.
- Removed thin teacher-distribution signal wrappers from `scripts/memo_panel.gd`, reducing it from 328 to 324 lines.
- Removed thin lobby-room and room-peer lookup wrappers from `scenes/chat.gd`, reducing it from 330 to 326 lines.
- Removed thin memo-button styling and temporary-reply forwarding wrappers from `scripts/hud.gd`, reducing it from 321 to 317 lines.
- Removed thin lesson-card, URL-open, and live-stream ownership wrappers from `scripts/lesson_panel.gd`, reducing it from 314 to 307 lines.
- Removed thin search-result clear/card and drawer-request wrappers from `scripts/profile_panel.gd`, reducing it from 303 to 298 lines.
- Added `scripts/calendar_widgets.gd` and moved calendar event-card, day-button, event-time, and time-option UI construction out of `scripts/calendar_panel.gd`, reducing it from 293 to 235 lines.
- Removed `world.gd`'s thin player-meta wrapper and routed HUD lookup through `scripts/app_nodes.gd`, reducing it from 265 to 264 lines.
- Added `scripts/player_avatar.gd` and moved avatar SpriteFrames construction out of `scripts/player.gd`, reducing it from 258 to 227 lines.
- Removed `scenes/network.gd`'s thin temporary-reply sender wrapper, reducing it from 324 to 321 lines.
- Extended `scripts/hud_panel_lifecycle.gd` so HUD panel attach/focus/exit/menu-button behavior is fully owned by the lifecycle helper, and removed the unused `nearby_talk_contact` state; `scripts/hud.gd` is now 274 lines.
- Audited the Django backend repository at `C:\卒業制作\team_h`; replaced remaining direct debug `print()` calls in `core/consumers.py` and `core/views/manage_api_views.py` with module loggers, and documented the oversized backend API module plus tracked/generated artifact cleanup as future phases.
- Started Phase 7 by moving backend growth summary/event endpoints into `core/views/growth_api_views.py` while preserving the existing `core.views` import surface and URL names; `core/views/manage_api_views.py` is now 1254 lines and the new growth module is 44 lines.
- Continued Phase 7 by adding `core/views/api_common.py` for shared session/user payload helpers and moving profile endpoints into `core/views/profile_api_views.py`; `core/views/manage_api_views.py` is now 1122 lines.
- Continued Phase 7 by moving personal and teacher memo endpoints into `core/views/memo_api_views.py` and moving session position parsing into `core/views/api_common.py`; `core/views/manage_api_views.py` is now 919 lines.
- Continued Phase 7 by moving lesson stream/comment/recording endpoints plus lesson video upload handling into `core/views/lesson_api_views.py` and removing now-unused imports from `core/views/manage_api_views.py`; `core/views/manage_api_views.py` is now 664 lines.
- Continued Phase 7 by moving chat users/rooms/messages/read/clear endpoints into `core/views/chat_api_views.py`; `core/views/manage_api_views.py` dropped to 379 lines.
- Finished the current Phase 7 view split by moving student management endpoints into `core/views/student_manage_api_views.py` and Godot auto-login/Nakama/logout endpoints into `core/views/godot_session_api_views.py`; `core/views/manage_api_views.py` is now a 2-line compatibility module.
- Added generated runtime-state exclusions to the backend `.gitignore` for local SQLite, collected static files, backup uploads, lesson videos, virtual environments, and tool caches. Already tracked generated files were left in place for a dedicated source-control cleanup after deployment reproduction is confirmed.
- Kept hardcoded endpoint defaults unchanged to avoid silently changing runtime behavior.
