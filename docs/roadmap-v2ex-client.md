# V2Next Long-Term Roadmap

This document defines the product and engineering plan for turning V2Next into a full V2EX client on HarmonyOS NEXT. It is intentionally broader than the current implementation, and should be used as the working checklist for long unattended development sessions.

## Baseline

Current implemented capabilities:

- Public topic browsing through existing V2EX v1 endpoints and parsed tab pages.
- Topic detail page with Markdown rendering.
- User profile page and node topic page.
- Personal Access Token storage and read-only verification.
- Read-only notification list.
- Local saved topics.
- Local saved nodes.
- Recently viewed topics.
- Topic list/detail cache and cache status.
- Basic UI spacing pass for profile and settings cards.

Important gaps:

- No username/password login flow.
- No WebView-based official login flow.
- API v2 is only partially wrapped.
- Cookie session is not implemented.
- Account write operations are not implemented.
- Topic/reply pagination is incomplete.
- Image links and common image hosts are not rendered inline.
- Search is incomplete.
- UI still feels like a functional prototype rather than a system-grade Harmony app.

## External References

- V2EX API 2.0 Beta: https://v2ex.com/help/api
- V2EX Personal Access Token: https://www.v2ex.com/help/personal-access-token
- V2er product page: https://v2er.app/
- V2er App Store description: https://apps.apple.com/cn/app/v2er-%E5%A5%BD%E7%94%A8%E7%9A%84v2ex%E5%AE%A2%E6%88%B7%E7%AB%AF/id1596137027
- Historical V2EX login discussion: https://v2ex.com/t/379024
- Historical Android login implementation notes: https://blog.csdn.net/u012339794/article/details/53264129

The official API v2 uses Personal Access Token authentication. It exposes `member`, `token`, `notifications`, `nodes/:node_name`, `nodes/:node_name/topics`, `topics/:topic_id`, and `topics/:topic_id/replies`, plus limited write operations such as deleting notifications, creating tokens, sticky, and boost. It does not provide a public username/password login API.

## Product Principles

1. Normal users should be able to log in with their V2EX username and password or through the official web login page.
2. Personal Access Token should remain available, but it is an advanced/API mode, not the only login path.
3. All account write operations must be explicit, visible, and guarded by confirmation. Reply/post submission stays disabled until the user asks to enable it.
4. Prefer official API v2 when it provides a feature. Use webpage parsing only for user-facing features that V2EX clients commonly support and that the API does not expose.
5. Keep credentials and session material out of git, logs, screenshots, and commit messages.
6. Device validation is required for every shipped phase.

## Login Architecture

### Login Methods

1. WebView login, recommended default:
   - Open `https://www.v2ex.com/signin` inside a controlled WebView.
   - Let the user complete the official login page.
   - Extract and persist session cookies after success.
   - Validate by loading a known signed-in page or profile signal.
   - This path should tolerate captcha, 2FA, anti-flood changes, and field changes.

2. Native username/password login:
   - Fetch `/signin`.
   - Parse hidden fields, especially `once` and `next`.
   - POST username, password, `once`, and `next`.
   - Persist returned cookies through a shared CookieJar.
   - Detect failure by response URL, page text, and absence of signed-in user signals.
   - This path is convenient but fragile; keep WebView login as fallback.

3. Personal Access Token login:
   - Store token securely.
   - Verify with `GET /api/v2/member`.
   - Show token scope and expiration with `GET /api/v2/token`.
   - Use it for API v2 read-only operations when available.

### Session Storage

Required storage units:

- `AuthSessionSettings`: login mode, username, avatar, session validation time.
- `CookieJar`: V2EX session cookies, domain, path, expiration.
- `AuthSettings`: PAT token, token metadata, expiration.

Security requirements:

- Never commit credentials, tokens, or cookies.
- Never log full token, password, or cookie values.
- Mask sensitive values in UI.
- Provide logout that clears cookies, PAT, cached account profile, and notification state.

## API v2 Coverage Plan

| Feature | API v2 endpoint | Status | Priority |
| --- | --- | --- | --- |
| Me profile | `GET /api/v2/member` | partial | P0 |
| Token info | `GET /api/v2/token` | partial | P0 |
| Notifications | `GET /api/v2/notifications?p=` | partial, no pagination | P0 |
| Delete notification | `DELETE /api/v2/notifications/:id` | missing | P1 |
| Node detail | `GET /api/v2/nodes/:name` | missing | P0 |
| Node topics | `GET /api/v2/nodes/:name/topics?p=` | missing | P0 |
| Topic detail | `GET /api/v2/topics/:id` | missing | P0 |
| Topic replies | `GET /api/v2/topics/:id/replies?p=` | missing | P0 |
| Create token | `POST /api/v2/tokens` | missing | P2 |
| Sticky own topic | `POST /api/v2/topics/:id/set-sticky` | missing, gated | P3 |
| Boost own topic | `POST /api/v2/topics/:id/boost` | missing, gated | P3 |

Implementation notes:

- Introduce `ApiV2Service` separate from the current public `ApiService`.
- Keep v1 public endpoints where they are still useful.
- Normalize v1/v2 topic/reply models at repository boundaries.
- Read rate-limit headers and expose remaining quota in debug/settings UI.

## Cookie/Web Capabilities

Capabilities likely requiring Cookie session and/or HTML parsing:

- Username/password login.
- Daily sign-in reward.
- Reply submission.
- Topic creation.
- Thank reply/topic.
- Favorite/unfavorite topic.
- Ignore topic.
- My topics.
- My replies.
- Balance and account navigation.
- Web settings links.

Safety policy:

- Login and read operations can be automated after implementation.
- Destructive or write operations require confirmation.
- Reply/post submit buttons stay behind a global `Enable account write actions` setting until explicitly approved.
- Drafts and previews can be built before submit is enabled.

## Feature Gap Matrix

### Browse

- Home tabs with correct category content.
- Hot/latest support.
- Node discovery and search.
- Node topic pagination.
- Topic detail pagination.
- Reply pagination.
- Pull refresh.
- Load more.
- Empty/error/retry states.
- Rate-limit and network degradation display.

### Account

- Username/password login.
- WebView login fallback.
- PAT login advanced mode.
- Account profile.
- Notifications with pagination.
- Notification tap-to-topic.
- Delete notification with confirmation.
- My topics.
- My replies.
- Local account data clear.

### Reading

- Recently viewed topics.
- Saved topics.
- Saved nodes.
- Local read/unread state.
- Last read position.
- Jump to latest reply.
- Jump to floor.
- Only original poster.
- Copy title/link/content.
- Share topic.
- Open in browser.

### Writing

- Reply editor.
- Topic editor.
- Markdown preview.
- Draft autosave.
- Node picker.
- Image link insertion.
- Submit confirmation.
- Failure recovery.
- Write action kill switch.

### Media

- Inline Markdown images.
- Inline bare image URLs.
- Common image host recognition.
- Full-screen image viewer.
- Pinch zoom.
- Long image support.
- GIF/WebP support where platform allows.
- Save image, after permission research.
- Setting: auto-load images on/off.
- Setting: only load images on Wi-Fi.

Common URL patterns to support first:

- `.jpg`, `.jpeg`, `.png`, `.webp`, `.gif`
- `i.imgur.com`
- `sm.ms`
- `s2.loli.net`
- `v2ex.assets.uxengine.net`
- `github.com/user-attachments/assets`
- `raw.githubusercontent.com`
- `pbs.twimg.com`

Non-direct image pages such as `postimg.cc` should become link preview cards first. Do not build brittle host-specific scraping until needed.

### Search

- Local search across saved topics, recently viewed topics, cached topics, and saved nodes.
- Node search.
- Topic search through V2EX web or third-party source after reliability review.
- Search history.
- Search source setting.

### UI and Settings

- Replace large card-heavy settings with system-style list rows.
- Keep cards for actual content items, not every setting.
- HDS component usage notes.
- Dark mode audit.
- Font size setting.
- Image loading setting.
- Cache settings.
- Account settings.
- Developer/debug settings.
- Error and empty-state design language.

## Development Phases

### Phase 1: Login Foundation

Goal: a normal user can sign in without manually creating PAT.

Tasks:

- Add CookieJar and session persistence.
- Implement WebView login flow.
- Implement login-state detection.
- Implement logout.
- Implement native username/password login prototype.
- Add account status card/page.
- Keep PAT login as advanced option.

Validation:

- Fresh install shows logged-out state.
- WebView login succeeds and persists across app restart.
- Username/password login succeeds for a test account when no captcha is required.
- Logout clears cookies and account state.
- No password/cookie/token appears in logs, git diff, screenshots, or commits.

### Phase 2: API v2 Read Completion

Goal: all read endpoints exposed by API v2 are implemented.

Tasks:

- Create `ApiV2Service`.
- Add v2 node detail.
- Add v2 node topics pagination.
- Add v2 topic detail.
- Add v2 replies pagination.
- Add notifications pagination.
- Normalize model mapping.
- Add rate-limit parsing.

Validation:

- Node page loads page 1 and page 2.
- Topic detail loads replies page 1 and page 2.
- Notifications load multiple pages when available.
- Build and device screenshots for home, node, detail, notification.

### Phase 3: Notification Actions

Goal: notification center behaves like a client, not a placeholder.

Tasks:

- Notification card tap opens topic.
- Show actor, action text, topic title, and time.
- Add delete notification with confirmation.
- Add batch clear draft UI, disabled by default.
- Cache last loaded notifications.

Validation:

- Tapping a notification opens the correct topic.
- Delete requires confirmation.
- Deleting one notification updates list without full reload.

### Phase 4: Media Rendering

Goal: V2EX topics with image links are readable inside the app.

Tasks:

- Add URL extraction for Markdown and bare links.
- Add image URL classifier.
- Render inline images in topic and reply content.
- Add placeholder, loading, failure, retry.
- Add full-screen image preview.
- Add image auto-load setting.

Validation:

- Markdown images render.
- Bare direct image links render.
- Non-image links remain links.
- Full-screen preview works on device.
- Image failure does not break content layout.

### Phase 5: Reading Experience

Goal: efficient repeated use.

Tasks:

- Last read position.
- Read/unread state.
- Jump to latest reply.
- Jump to floor.
- Only original poster filter.
- Topic action menu.
- Share/copy/open browser.
- Improve local saved topics/nodes/history management.

Validation:

- Reopening a topic can restore position.
- Topic menu actions work.
- Filters do not corrupt reply order.

### Phase 6: Writing Drafts

Goal: prepare account write UI without unsafe auto-submission.

Tasks:

- Reply editor.
- Topic editor.
- Markdown preview.
- Draft autosave.
- Node picker.
- Submit API/web adapter behind disabled global switch.
- Explicit confirmation dialog.

Validation:

- Draft survives app restart.
- Preview matches basic Markdown.
- Submit controls remain disabled unless write switch is enabled.

### Phase 7: Search

Goal: fast discovery.

Tasks:

- Local search page.
- Node search improvements.
- Topic search source research.
- Pluggable search source.
- Search history.

Validation:

- Local search returns saved/history/cache results.
- Node search remains fast.
- Remote search failures are isolated.

### Phase 8: UI System Pass

Goal: closer to a first-party Harmony app.

Tasks:

- Rebuild My page as a settings/list layout.
- Rebuild Settings page.
- Audit all paddings and text sizes.
- Dark mode screenshots.
- Compact and regular density variants.
- HDS usage document.

Validation:

- Screenshots for home, discover, notifications, my, detail, node, user.
- No overlapping text.
- Buttons and controls use stable dimensions.
- UI does not read as a one-off card stack.

## Verification Protocol

Every implementation phase must include:

1. `bash dev.sh --build-only`
2. Install to `192.168.50.237:12345`
3. Launch app
4. Device screenshot checks
5. At least one interaction test for the feature
6. `git diff --check`
7. Review actual diff before commit
8. Accurate commit message

Suggested screenshot set:

- Home tab list
- Topic detail
- Reply area
- Node list
- Node topic page
- User profile
- Notification page
- My page
- Login page
- Settings page

## Commit Policy

- One coherent phase per commit.
- Commit messages must describe the actual diff, not the intended roadmap.
- Do not commit `.env.local`, cookies, tokens, screenshots, device dumps, or external tool folders.
- Keep generated or external directories such as `.claude/`, `.cursor/skills/`, and `.opencode/` out of commits unless explicitly requested.

## Open Questions

- Which Harmony WebView Cookie API is stable on the current SDK?
- Whether V2EX login sometimes requires captcha or 2FA for this account/device.
- Whether native username/password login should store password at all; preferred answer is no, only use password for the immediate login request.
- Which HTML parser strategy is safest in ArkTS for login and account pages.
- Whether image saving requires photo permissions or system picker integration.
- Which remote search source is acceptable, if any.

## Near-Term Next Step

Start Phase 1 with a narrow vertical slice:

1. Add CookieJar storage.
2. Add a login service that can fetch `/signin` and parse `once`.
3. Add native username/password login request.
4. Add session validation.
5. Add WebView login fallback if native login hits anti-flood/captcha.
6. Build, install, screenshot, and commit.
