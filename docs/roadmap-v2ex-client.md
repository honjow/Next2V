# V2Next V2EX Client Roadmap

This document is the handoff guide for continuing V2Next development in a new
session. It is based on the current V2Next implementation, the V2EX website, and
two mature open-source clients used as product references:

- V2Fun: https://github.com/liaoliao666/v2ex
- VVEX: https://github.com/guozhigq/flutter_v2ex

The target is a complete daily-use HarmonyOS NEXT V2EX client, not just a
read-only browser. The product direction is HDS-first and concise: use system
components, keep surfaces quiet, and remove explanatory text that does not help
the immediate decision.

## Non-Negotiable UI Rules

The detailed implementation contract is `docs/ui-guidelines.md`. Follow that
document before changing page UI. This roadmap describes product direction; the
UI guidelines define the control-level rules and commit gate.

### HDS First

All new UI work must prefer Harmony Design System / `@kit.UIDesignKit` first.

Use HDS components and interaction patterns for:

- Navigation, title bars, tabs, tab bars, modal surfaces, menus, buttons, list
  rows, popups, dialogs, toast-like feedback, and material/blur/immersive
  effects.
- Secondary pages, including Search, Settings, Login, TopicEditor, ReplyEditor,
  UserProfile, account pages, notification pages, local lists, and future
  feature pages.
- Action menus. Prefer HDS popup menu / menu button patterns instead of
  hand-written temporary menus.
- Safe area, title blur, bottom floating tab blur, light-sense/immersive
  backgrounds, and page transitions.

Fallback rules:

- Use ArkUI native components only when HDS has no suitable component, the HDS
  API is unavailable, or device testing proves the HDS path is broken.
- If ArkUI fallback is required, wrap it in shared components so individual
  pages do not each invent spacing, buttons, menu, or scaffold behavior.
- Do not hand-tune one page in isolation. When a layout defect appears on one
  secondary page, compare it with Detail and Settings, then fix the shared
  scaffold or shared row/menu component when possible.
- Every UI change must be verified on the device with screenshots. Do not rely
  on static code review for spacing, safe area, or blur effects.

### Concise By Default

All pages should be concise. Do not add explanatory subtitles, helper text, or
secondary labels unless they materially help the user decide or prevent a
mistake.

Apply this especially to My, Settings, Search, Login, TopicEditor, ReplyEditor,
and local list pages:

- My page entries should usually be one-line commands or content entries. Remove
  subtitles like "from V2EX sync..." when the title already explains the row.
- Settings rows may use subtitles only for state, risk, or non-obvious behavior,
  such as current domain, write-action danger, cache size, or Wi-Fi-only image
  behavior.
- Avoid repeating the page or section context inside every row. For example, in
  an account section, "收藏主题" is enough; "从 V2EX 同步你的收藏主题" is usually
  redundant.
- Empty states should be short and actionable, not instructional paragraphs.
- Prefer compact controls, icon buttons with HDS tooltips/menus, and clear row
  titles over explanatory inline text.
- When a page feels rough, first remove unnecessary text and visual noise before
  adding decoration.

## Current Implementation State

V2Next is beyond a read-only prototype. It already supports public browsing,
login/session state, account metadata, local state, drafts, topic/reply reading,
and image-heavy content.

Implemented:

- Public browsing through parsed V2EX tabs and public/API endpoints.
- Home tabs with category-specific content and horizontal tab switching.
- Node discovery, node search, node topic pages, and locally saved nodes.
- User profile page with profile metadata and recent topics.
- Topic detail page with Markdown rendering, replies, pull refresh, cache,
  read/unread state, last read floor, jump to latest, jump to floor, OP-only
  filter, local save-later, recent-view recording, copy/share/browser actions,
  reply context, text selection, and code block controls.
- Cookie session storage, WebView login, native username/password login
  prototype, session validation, logout, balance parsing, daily mission status,
  and manual sign-in.
- Account block on My page with avatar, username, custom-drawn coin badges, and
  sign-in action.
- PAT storage, verification, token metadata, API rate-limit snapshot, and
  PAT-backed API v2 reads. PAT is an advanced mode, not the primary user flow.
- API v2 wrapper for member, token, notifications, notification deletion, node
  detail, node topics, topic detail, topic replies, generic GET/POST/DELETE, and
  rate-limit headers.
- Notification list pagination, cache, tap-to-topic, type/read labels where the
  source provides enough signal, and PAT deletion.
- Cookie-backed account content pages for collected topics, replies, and
  collected nodes, plus browser fallback links.
- Site-synced topic favorite/unfavorite and node follow/unfollow via
  Cookie-backed once-token actions.
- Guarded Cookie-backed topic and reply submission adapters behind a global
  write-action switch, with confirmation dialogs, form-token parsing, in-flight
  states, failure messages, and draft clearing only after success.
- Inline Markdown images, bare direct image links, common image host recognition,
  image loading states, retry, full-screen preview, pinch zoom, image save, and
  image loading preferences.
- Standalone non-image link cards for common hosts while direct image URLs stay
  on the controlled inline image path.
- Reply and topic draft editors with Markdown preview, autosave, node picker,
  image link insertion, and disabled submit controls behind the write-action
  switch.
- Local search across saved topics, viewed topics, cache, saved nodes, node
  index, history, and external web search fallback.
- Settings page with local data reset, cache management, media settings, reading
  settings, write-action switch, API domain switch, and HDS notes.

Key local files:

- `entry/src/main/ets/pages/Index.ets`: app shell plus too many My/Notify/account
  responsibilities. This must be split.
- `feature/detail/src/main/ets/pages/TopicDetailPage.ets`: topic detail,
  replies, reading controls, topic actions.
- `feature/detail/src/main/ets/pages/ReplyEditorPage.ets`: reply editor.
- `entry/src/main/ets/pages/TopicEditorPage.ets`: topic editor.
- `entry/src/main/ets/pages/SearchPage.ets`: current local/external search UI.
- `feature/user/src/main/ets/pages/UserProfilePage.ets`: user profile.
- `feature/settings/src/main/ets/pages/SettingsPage.ets`: settings.
- `shared/src/main/ets/components/SecondaryListScaffold.ets`: existing secondary
  scaffold; keep evolving this into the common HDS-first page layer.
- `shared/src/main/ets/network/ApiService.ets`: public API and Cookie-backed
  HTML adapters.
- `shared/src/main/ets/network/ApiV2Service.ets`: authenticated API v2 wrapper.
- `shared/src/main/ets/components/MarkdownContent.ets`: Markdown/image/link
  rendering.

## Product Gap Summary

Compared with V2Fun and VVEX, the largest gaps are now:

- In-app remote search with SOV2EX-style advanced filters.
- Discover surfaces: today hot, historical hot, rank/community pages, and richer
  node navigation.
- Account actions: thank topic/reply, ignore topic/reply, report, follow/unfollow
  user, block/unblock user, black list, edit topic, append topic, and image
  upload.
- Notification workflow: jump to exact floor/reply, richer type handling, local
  notification/polling, and better deletion/read-state handling.
- Login completeness: captcha, 2FA, session expiration recovery, and better
  native-login error handling.
- User customization: tab sorting/hiding, node sorting, reading defaults,
  open-in-app browser preference, quick actions, and deep links.
- UI consistency: several secondary pages still look like independently tuned
  pages instead of one HDS-based product.

Compared with the V2EX website, V2Next still lacks:

- Full website action parity for thank, ignore, report, block, edit, append,
  sticky, boost, invite-code purchase, and image hosting.
- Full account settings and balance detail.
- Block behavior that affects lists, replies, notifications, and local filters.
- Original-format expansion parity for every embedded content type.

API constraint:

- V2EX API 2.0 currently covers notifications, notification deletion, member,
  token, node, node topics, topic, topic replies, sticky, and boost.
- Normal topic creation, reply creation, thank, favorite/unfavorite, block, edit,
  append, image upload, and many account operations still need Cookie-backed HTML
  form/action adapters unless the official API changes.

## Product Principles

1. HDS-first UI is mandatory for new UI and refactors.
2. Concise UI is mandatory. Remove redundant subtitles and helper copy unless
   they communicate state, risk, or an otherwise hidden behavior.
3. Normal users should use username/password login or official WebView login.
   PAT remains an advanced/API mode.
4. Prefer official API v2 when it exposes the needed operation. Use
   Cookie-backed page parsing/form submission only for missing API capabilities.
5. Write operations must be explicit, visible, confirmed, and protected by the
   global write-action switch.
6. Never auto-submit posts, replies, thanks, favorites, blocks, sticky, boost,
   image uploads, or other account-changing actions during unattended validation.
7. Passwords, tokens, cookies, and screenshots containing credentials must never
   be committed, logged, or shown.
8. Every coherent feature must pass build, install, device interaction,
   screenshot review, `git diff --check`, diff review, and an accurate commit.

## Recommended Development Plan

### P0. HDS-First Architecture Baseline

Goal: stop accumulating one-off page UI and make future feature work predictable.

Tasks:

- Split `Index.ets`. Keep only app shell, bottom tabs, route registration, and
  global app state there.
- Move My page/account UI into an account feature area.
- Move notification UI and notification view model ownership into a notification
  feature area.
- Move local saved/viewed/node pages out of `Index.ets`.
- Promote `SecondaryListScaffold` into a common HDS-first secondary page layer:
  safe area, title offset, background, list padding, section header, empty state,
  error state, loading state, bottom padding, and optional appbar actions.
- Add shared HDS-style components: `SectionHeader`, `SettingsRow`, `AccountRow`,
  `ActionMenuButton`, `FilterChip`, `SearchPanel`, `EmptyState`, and
  `DestructiveConfirmDialog` as needed.
- Add concise-copy defaults to shared row components: subtitles are optional and
  should be absent by default.
- Convert Search, Settings, Login, TopicEditor, ReplyEditor, UserProfile, and
  local list pages to the shared scaffolds.
- Audit My and Settings first for redundant subtitles and repeated context.
- Capture baseline screenshots for all primary and secondary pages.

Validation:

- Home, Discover, Notifications, My, Settings, Detail, User, Node, Search,
  Login, TopicEditor, ReplyEditor, SavedTopics, ViewedTopics, and SavedNodes
  have consistent safe area, horizontal padding, title placement, and background.
- HDS menu/popup/action patterns are used where available.
- No content is hidden behind title bars, status bar, bottom floating tab, or
  gesture area.

### P0. In-App Remote Search

Goal: match V2Fun/VVEX search usefulness while keeping local search fast.

Reference:

- V2Fun uses SOV2EX and has a search options screen.
- VVEX uses SOV2EX with sort, order, and date filters.

Tasks:

- Add a SOV2EX service wrapper with typed request/response models.
- Support query, pagination, result count, node filter, author filter, date
  range, sort by relevance/created, and ascending/descending order.
- Keep local search available as an instant tab/source.
- Redesign Search as an HDS-first page:
  - Empty state: history + node quick search.
  - Query state: local results + remote SOV2EX results.
  - Appbar action: search filters.
  - Clear error isolation between local and remote sources.
- Record and manage search history.
- Preserve external browser fallback for Google/Bing search if SOV2EX fails.

Validation:

- Search "programmer", a Chinese keyword, a username, and a node name.
- Page through results.
- Open a result into TopicDetail.
- SOV2EX failure does not break local search.

### P0. Detail Actions and Notification Floor Jump

Goal: make the reading and notification loop feel complete.

Tasks:

- Add notification-to-floor navigation where notification parsing exposes a reply
  id or floor.
- Keep TopicDetail capable of loading pages until the target floor/reply is
  visible.
- Add thank topic and thank reply with coin-cost confirmation.
- Add ignore topic and ignore reply with explicit confirmation.
- Add report topic with explicit confirmation and no unattended execution.
- Move low-frequency actions into an HDS popup menu.
- Rework reply toolbar so OP filter, floor jump, sort/latest controls, and reply
  actions do not crowd each other.
- Add related replies / reply context entry from reply action menu.

Validation:

- Open notification and land near the correct floor.
- Open a long topic, jump to floor, filter OP, and return to all replies.
- Write-action disabled state prevents unsafe operations where applicable.
- No thank/ignore/report action runs during unattended tests.

### P0. Account and My Page Completion

Goal: make normal Cookie login useful as the main account mode.

Tasks:

- Keep My page as a product account dashboard: avatar, username, balance coins,
  daily mission/sign-in button, and concise account entries.
- Remove redundant subtitles from account content rows. Use subtitles only for
  counts, failure states, stale-cache markers, or other useful state.
- Move settings to the My appbar only; do not duplicate settings rows in My.
- Add account detail page with balance detail and browser fallback.
- Add my topics if parseable separately from collected topics.
- Add following users/topics page if stable parseable pages exist.
- Add black list page.
- Add follow/unfollow user and block/unblock user actions.
- Make session expiration recoverable everywhere: relogin entry, no stale
  logged-in UI, clear error path.
- Keep PAT metadata in an advanced/debug area only.

Validation:

- Cookie login persists across restart.
- My page shows `honjow` account data correctly when logged in.
- Balance parsing keeps `97` as silver and `0.72` as copper for compact website
  balance text.
- Expired/invalid Cookie leads to a recoverable login state.

### P1. Discover and Navigation Surfaces

Goal: bring the app closer to mature clients' browsing/discovery capability.

Tasks:

- Add Today Hot.
- Add Historical Hot, with date selection if a stable source is used.
- Add Rank/community pages where parseable.
- Improve Discover page with clear sections: node search, all nodes, hot,
  history hot, rank, and frequent nodes.
- Add homepage tab management: sort, hide/show, restore default.
- Add node sorting/favorites management.
- Keep all pages on shared HDS scaffolds.

Validation:

- Hot/history/rank pages open and navigate to TopicDetail.
- Tab sorting survives app restart.
- Discover does not become a card grid with oversized empty space.

### P1. Login Hardening

Goal: make username/password login robust, with WebView as fallback.

Tasks:

- Harden dynamic field parsing for `/signin`.
- Add captcha display/input flow if V2EX returns a captcha challenge.
- Add 2FA flow.
- Improve error messages for wrong password, captcha, 2FA, network, and blocked
  session cases.
- Validate saved Cookie by loading an authenticated page, not by checking that a
  Cookie string exists.
- Keep WebView login as a visible fallback from the native login page.

Validation:

- Normal login succeeds.
- Wrong password and invalid 2FA/captcha show precise error states.
- App restart keeps a valid session.

### P1. Writing and Editing

Goal: make write flows usable while remaining safe.

Tasks:

- Polish reply editor with HDS toolbar, preview, mention insertion, image link
  insertion, autosave, and submit confirmation.
- Polish topic editor with node picker, Markdown toolbar, preview, draft save,
  and submit confirmation.
- Add @ multiple users from reply context/search.
- Add edit topic flow: parse original form, edit, preview, confirm coin cost,
  submit only with write-action switch enabled.
- Add append topic flow if V2EX exposes stable form/actions.
- Keep drafts until confirmed success.

Validation:

- Drafts survive restart.
- Submit controls remain disabled while write-action switch is off.
- Manual real submission requires explicit user approval.

### P1. Media and Uploads

Goal: cover image-heavy topics and writing workflows.

Tasks:

- Keep direct image rendering and full-screen preview stable.
- Add image upload provider support. Start with Imgur or another user-configured
  provider; V2EX image host can be evaluated after account eligibility is clear.
- Add image picker, upload progress, uploaded-image history, copy URL, and insert
  Markdown.
- Add long-image preview polish.
- Add reply/topic "save as image" only after core upload/rendering is stable.
- Keep Wi-Fi-only and auto-load image preferences.

Validation:

- Pick image, upload, insert Markdown, preview.
- Save image still works.
- Large images do not break list/detail layout.

### P1. Settings and Personalization

Goal: make settings product-grade instead of engineering-grade.

Tasks:

- Reorganize Settings into HDS-style sections:
  - Account
  - Reading
  - Content parsing
  - Images and media
  - Notifications
  - Writing
  - Storage
  - Advanced
- Add reading defaults: reply order, OP highlight, font size, line height,
  density, code wrapping.
- Add open links in app/browser preference.
- Add notification preference.
- Add tab/node sorting entry.
- Keep dangerous actions behind confirmation.
- Remove redundant account controls from Settings when they belong in My or
  Account.
- Remove row subtitles that only restate the title or section context.

Validation:

- Settings page spacing matches other secondary pages.
- No row text overflows.
- Account settings are not duplicated between My and Settings.
- My and Settings remain scannable with minimal secondary text.

### P2. System Integration

Goal: make the app feel complete on HarmonyOS.

Tasks:

- Add deep links:
  - topic by id
  - member by username
  - node by name
  - search by query
- Add desktop/launcher quick actions if Harmony supports the required capability:
  search, sign in, today hot, topic draft.
- Add local notification/polling only after notification data and user preference
  are stable.
- Add notification click routing to topic/floor.
- Evaluate tablet/two-pane layout after phone UI is stable.

Validation:

- Deep links open correct pages from outside the app.
- Quick actions do not require login unless the action needs it.
- Notification tap lands on the expected topic/floor.

### P2. Advanced Account Actions

Goal: reach parity with website/client power features after core loops are
stable.

Tasks:

- Sticky and boost with clear permission and coin-cost explanation.
- Invite-code purchase only if user explicitly asks for it.
- Multi-account switching after single-account Cookie/PAT state is reliable.
- Account settings pages if parseable and worth supporting in app.
- Optional sync/export/import for local state.

Validation:

- Every paid/destructive action displays cost and impact before submission.
- No paid/destructive action is triggered during unattended testing.

## Reference Comparison Notes

V2Fun notable references:

- SOV2EX/Google search and search option page.
- History/recent topics, hot topics, rank/community pages.
- Black list, domain configuration, Imgur configuration, theme customization.
- Related replies, selectable text, search reply member, and topic editing.
- URL scheme for search, topic, member, and node.

VVEX notable references:

- Material-style adaptive UI, node sorting, hot/history pages, and recent
  browsing.
- Advanced SOV2EX search with date/sort/order controls.
- 2FA login, auto sign-in, local notifications, quick actions.
- Topic/reply thank, ignore, report, favorite, follow/block user.
- Image upload, reply save as image, markdown topic publishing.
- Read-state service and adaptive/two-pane layout experiments.

## Verification Protocol

For every coherent feature or UI pass:

1. `bash dev.sh --build-only`
2. Install to `192.168.50.237:12345`
3. Launch app
4. Device interaction tests
5. Screenshot/layout review
6. `git diff --check`
7. Review actual diff
8. Commit with a message describing the actual diff

UI verification must include screenshots for affected pages. For shared UI
changes, capture at least:

- Home
- Discover
- Notifications
- My
- Settings
- TopicDetail
- Search
- Login
- TopicEditor
- ReplyEditor
- UserProfile
- NodeTopic

Use the existing device tools:

- HDC path:
  `/home/gamer/devtool/ohos/command-line-tools/sdk/default/openharmony/toolchains/hdc`
- Device:
  `192.168.50.237:12345`

Do not commit `.env.local`, cookies, tokens, screenshots, device dumps, local
reference checkouts, or external tool folders such as `.claude/`,
`.cursor/skills/`, and `.opencode/`.

## Immediate Next Session Prompt

Use this prompt to start the next independent development session:

```text
Continue V2Next development from docs/roadmap-v2ex-client.md.

Priorities:
1. Follow the HDS-first rule strictly.
2. Keep UI concise. Remove redundant subtitles/helper text, especially in My and
   Settings, unless the text communicates state, risk, or hidden behavior.
3. Start with P0 HDS-first architecture baseline.
4. Split Index.ets so app shell, My/account, notifications, and local list pages
   are separated.
5. Promote shared HDS-first secondary page scaffolds and migrate Search,
   Settings, Login, TopicEditor, ReplyEditor, UserProfile, and local list pages
   where practical.
6. After each coherent step, build, install to 192.168.50.237:12345, interact
   with affected pages, capture screenshots, review diff, and commit with an
   accurate message.

Do not auto-submit account-changing actions. Do not commit credentials, cookies,
tokens, screenshots, or local reference checkouts.
```
