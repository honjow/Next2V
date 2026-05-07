# V2Next Roadmap and Handoff Guide

This document is the execution guide for continuing V2Next in independent
threads. It reflects the current codebase after the recent UI/link/profile
changes, plus a feature comparison against:

- V2Fun: `https://github.com/liaoliao666/v2ex`
- VVEX / flutter_v2ex: `https://github.com/guozhigq/flutter_v2ex`
- ClashBox HarmonyOS app, master branch:
  `https://github.com/xiaobaigroup/ClashBox/tree/master`
- HarmonyDO public HarmonyOS app:
  `https://github.com/Amaz1ny/HarmonyDO-public`
- V2EX web pages and API v2 behavior observed through the current app adapters.

The product goal is a complete daily-use HarmonyOS NEXT V2EX client. The
implementation direction is HDS-first, concise, and regression-aware.

## Hard Rules

1. Prefer Harmony Design System / `@kit.UIDesignKit` components and system
   interaction patterns before writing custom ArkUI UI.
2. If HDS is unavailable or unsuitable, create or reuse a shared wrapper in
   `shared/src/main/ets/components/`; do not add page-local one-off buttons,
   text fields, sheets, rows, or menus.
3. Keep UI concise. Remove helper subtitles and explanatory copy unless they
   communicate state, risk, count, cache freshness, or a hidden behavior.
4. Preserve explicit V2EX money units. If source text says `0.90 铜币`, display a
   fractional copper value. Do not convert it to `90 铜币`.
5. Do not auto-run paid/destructive/account-changing operations during
   unattended validation. This includes post, reply, thank, ignore, report,
   block, follow, favorite, sign-in, image upload, sticky, and boost.
6. Write operations must stay guarded by the global write-action switch plus an
   explicit confirmation.
7. Do not commit credentials, cookies, tokens, screenshots, device dumps, local
   reference checkouts, or temporary test artifacts.
8. Every coherent implementation step must pass:
   - `bash dev.sh --build-only`
   - install to `192.168.50.237:12345`
   - affected-page device interaction
   - screenshot/layout review for UI changes
   - `git diff --check`
   - actual diff review
   - accurate commit message

## Current Codebase Snapshot

Core app and routes:

- `entry/src/main/ets/pages/Index.ets`
  - App shell, bottom tabs, navigation route registration.
  - Still owns too much: My page, notification UI, account state, local lists.
  - This is the main architecture debt.
- `feature/feed/src/main/ets/pages/HomePage.ets`
  - Home tab strip, swiper sync, topic lists, pull refresh.
- `feature/node/src/main/ets/pages/DiscoverPage.ets`
  - Node search plus hot/rank/latest/recent topic surfaces.
  - UI still uses custom page layout and needs shared scaffold migration.
- `feature/detail/src/main/ets/pages/TopicDetailPage.ets`
  - Topic detail, replies, topic actions, read position, filters, images.
- `feature/detail/src/main/ets/pages/ReplyEditorPage.ets`
  - Existing reply draft/editor route.
  - Normal topic replies should move away from a standalone page and use a
    keyboard-attached floating composer opened from topic detail.
- `entry/src/main/ets/pages/TopicEditorPage.ets`
  - Topic draft/editor flow.
- `entry/src/main/ets/pages/SearchPage.ets`
  - Local/node/SOV2EX/web search sources and filter sheet.
- `feature/user/src/main/ets/pages/UserProfilePage.ets`
  - User profile, topics/replies tabs, follow/block controls, full-list entries.
- `feature/settings/src/main/ets/pages/SettingsPage.ets`
  - Settings and advanced controls.

Shared infrastructure:

- `shared/src/main/ets/components/SecondaryListScaffold.ets`
  - Current secondary list safe-area scaffold.
- `shared/src/main/ets/components/SecondaryFormScaffold.ets`
  - Form-page scaffold.
- `shared/src/main/ets/components/AppSearchField.ets`
- `shared/src/main/ets/components/AppTextField.ets`
- `shared/src/main/ets/components/AppModalScaffold.ets`
- `shared/src/main/ets/components/AppActionButton.ets`
- `shared/src/main/ets/components/FilterChip.ets`
- `shared/src/main/ets/components/ConciseListRow.ets`
- `shared/src/main/ets/components/GroupedListSection.ets`
- `shared/src/main/ets/components/MarkdownContent.ets`
  - Markdown rendering, selectable text, mentions, image rendering.
  - Standalone non-image links now render as normal inline links, not cards.
- `shared/src/main/ets/utils/MediaUrlUtils.ets`
  - Image URL detection and media URL helpers.
- `shared/src/main/ets/network/ApiService.ets`
  - V1/public APIs, HTML parsing, Cookie-backed account/write adapters.
- `shared/src/main/ets/network/ApiV2Service.ets`
  - PAT/API v2 wrapper for member/token/notifications/node/topic/replies.
- `shared/src/main/ets/network/Sov2exService.ets`
  - SOV2EX remote search.

Implemented and must not regress:

- Public tabs and category-specific home content.
- Horizontal home tab switching with animated indicator.
- Pull refresh and list scroll behavior.
- Detail page read position, last-read floor, latest jump, floor jump,
  OP-only filter, sort/latest controls, reply context, selectable text,
  copy/share/browser actions, save-later, recent-view tracking.
- Reply filter row is acceptable in current compact form. Do not enlarge
  `楼层 / 只看楼主 / 最新` into heavy buttons.
- Topic/reply Markdown images, direct image URLs, retry/loading, full-screen
  preview, pinch zoom, save image through appbar menu.
- Non-image links display as direct clickable text.
- Web login and native login prototype.
- Cookie session validation and logout.
- My account card with avatar, username, coin icons, and sign-in button.
- Daily mission display and manual sign-in.
- Balance parsing with explicit-unit preservation.
- PAT storage and API v2 read flows as advanced/debug capability.
- Notification list pagination/cache/deletion where supported.
- Collected topics, member replies, and collected nodes pages.
- Cookie-backed topic favorite and node follow actions.
- Guarded topic/reply submission adapters and drafts.
- User profile topics/replies tabs, full topics/replies pages, follow/block
  controls with immediate UI update.
- Search across local saved/viewed/cache/nodes plus SOV2EX and web fallback.

## Reference Projects

Reference checkouts should stay outside this repo, for example:

- `/tmp/v2next-reference/v2fun`
- `/tmp/v2next-reference/flutter_v2ex`

Useful V2Fun paths:

- `screens/HomeScreen.tsx`: dynamic home tabs, recent tab, node tabs.
- `screens/SortTabsScreen.tsx`: tab sorting/customization.
- `screens/SearchScreen.tsx`, `screens/SearchOptionsScreen.tsx`:
  SOV2EX search and options.
- `screens/HotestTopicsScreen.tsx`, `screens/RankScreen.tsx`,
  `screens/RecentTopicScreen.tsx`: discovery surfaces.
- `screens/MemberDetailScreen.tsx`: user profile topics/replies tabs,
  follow/block actions.
- `screens/BlackListScreen.tsx`: blocked users and ignored topics.
- `components/topic/TopicInfo.tsx`: favorite, thank, ignore, report, edit,
  append action model.
- `components/topic/ReplyItem.tsx`: thank reply, ignore reply, related replies,
  reply menu.
- `screens/RelatedRepliesScreen.tsx`: related reply/thread context.
- `components/UploadImageButton.tsx`, `screens/ImgurConfigScreen.tsx`,
  `servicies/other.ts`: Imgur upload configuration and upload flow.
- `servicies/helper.ts`: HTML parsing, image URL conversion, member/profile
  parsing, money/profile parsing.
- `navigation/LinkingConfiguration.ts`, `app.json`: app scheme/deep links.

Useful VVEX paths:

- `lib/http/soV2ex.dart`: SOV2EX request parameters and response models.
- `lib/http/dio_web.dart`: login dynamic fields, captcha, 2FA, thank,
  ignore, mission, write/edit/append parsing.
- `lib/http/user.dart`: user profile, topics/replies, block, notifications.
- `lib/pages/t/topic_id.dart`: topic detail, notification-floor routing,
  reply list behavior.
- `lib/components/message/notice_item.dart`, `lib/pages/page_message.dart`,
  `lib/service/local_notice.dart`: notification parsing/deletion/local
  notifications and topic jump payload.
- `lib/utils/upload.dart`: Imgur upload.
- `lib/utils/app_scheme.dart`, Android `AndroidManifest.xml`: deep link setup.
- `lib/utils/storage.dart`: settings for link opening, auto sign-in, notice,
  font sizes, tabs, OP highlight, side swipe.

Useful ClashBox master paths:

- `entry/src/main/ets/pages/ConfigurationPage.ets`: floating add button,
  `bindSheet` lifecycle, sheet dismiss control, and internal sheet routing.
- `entry/src/main/ets/common/entity/Constants.ets`: centralized sheet/list
  sizing constants instead of page-local magic numbers.
- `entry/src/main/ets/components/Common/*`: reusable title/sheet/button
  primitives and round button patterns.
- `entry/src/main/ets/common/breakpoint/BreakPoint.ets`: breakpoint-driven
  navigation/list padding and responsive constants.

Useful HarmonyDO public paths:

- `entry/src/main/ets/pages/Index.ets`: `HdsNavigation`, `HdsTabs`, floating tab
  sizing, and HDS animation mode coordination.
- `entry/src/main/ets/views/components/ImmersiveHdsTitleBarHelper.ets`:
  immersive HDS title bar, gradient blur, status bar content color, and top
  spacer convention.
- `entry/src/main/ets/views/pages/TopicDetailPage.ets`: bottom HDS action bar,
  floating reply button, multiple sheet hosts, reply sheet open/dismiss flow,
  and reply/post menu organization.
- `entry/src/main/ets/views/components/ReplyComposerSheet.ets`: sheet-based
  reply composer with draft save, preview, toolbar, image upload hooks, and
  text selection.
- `entry/src/main/ets/views/pages/CategoryTopicPage.ets`,
  `BookmarksPage.ets`, `BrowsingHistoryPage.ets`: HDS secondary pages, appbar
  menus, sheet-host placement, list top spacer and bottom floating-tab avoid.
- `entry/src/main/ets/common/constants/LayoutConstants.ets`: shared floating
  tab/action-bar dimensions and content padding constants.

Reference code is for behavior and architecture comparison only. Do not copy
large blocks or foreign UI style into this Harmony app.

## P0. Architecture and UI Baseline

Goal: stop page-by-page patching and make future work predictable.

Tasks:

- Split `entry/src/main/ets/pages/Index.ets`.
  - Keep route registration, bottom tabs, global app state, and top-level HDS
    title bar helpers in `Index.ets`.
  - Move My/account page into a new account feature area, for example
    `feature/account/src/main/ets/...` or an equivalent local convention.
  - Move notification page and view model ownership into a notification feature
    area.
  - Move local pages for saved topics, viewed topics, and saved nodes out of
    `Index.ets`.
- Promote shared scaffolds.
  - Extend `SecondaryListScaffold` or add a compatible HDS-first page scaffold
    for safe area, title offset, list padding, bottom avoid, loading, error,
    empty state, optional appbar actions, pull refresh, and reach-end.
  - Keep immersive/light-sense behavior correct: content may scroll under the
    title blur, but first content must not start hidden behind it.
  - Avoid blank spacer hacks outside the scaffold.
- Consolidate shared UI primitives.
  - List rows: use `ConciseListRow`, `GroupedListSection`, or an HDS list-item
    wrapper. Subtitles are optional and absent by default.
  - Inputs: use `AppSearchField` or `AppTextField`, never raw page-local
    `TextInput` styling.
  - Buttons/chips: keep same-role controls same size and same component.
  - Sheets: use `bindSheet` plus `AppModalScaffold` or HDS/system sheet
    patterns. Back must close the sheet before leaving the page.
  - Menus: page actions and low-frequency operations belong in HDS appbar menus
    or `ContextMenu`.
  - Floating primary actions: when the action is the page's primary repeated
    action, use a bottom floating button/action bar that respects keyboard,
    bottom tab, and gesture safe areas. Do not hide high-frequency actions in
    appbar menus.
- Migrate or review these pages against the shared layer:
  - Search
  - Settings
  - Login
  - Web login
  - Topic editor
  - Reply composer sheet
  - User profile
  - Node topic
  - Discover
  - Saved topics / recent views / saved nodes
  - Notifications
  - Any page still drawing a page-local back button.
- Bring notifications and node-related pages into the same architecture before
  adding more features:
  - Notifications must be owned by a notification feature module/view model,
    not embedded in `Index.ets`.
  - Notification list rows, empty/loading/error states, pagination, deletion,
    and tap-to-floor navigation must use the shared list scaffold.
  - Node search, node topic lists, all-node navigation, favorite-node state,
    and recent/frequent nodes should share one node feature architecture.
  - Node and notification pages should use appbar menus for secondary actions,
    pull refresh for reload, and shared list/content spacing.

Acceptance:

- Screenshot review covers Home, Discover, Notifications, My, Settings, Search,
  Login, WebLogin, TopicDetail, TopicEditor, ReplyEditor, UserProfile,
  NodeTopic, saved topics, recent views, saved nodes.
- No affected page has hidden content behind title bar, status bar, floating
  bottom tab, keyboard, or gesture area.
- Same-row controls have consistent height, font, shape, and alignment.
- No feature page adds raw `TextInput`, pseudo-buttons, custom sheets, or new
  page-local row styles when a shared wrapper exists.
- Replying from topic detail does not route to a standalone reply page in the
  normal flow.

Regression guards:

- Do not change compact reply filter row shape.
- Do not reintroduce standalone non-image link cards.
- Do not change money parsing unless tests prove the source format.

## P0. Media and Image Host Handling

Goal: make image-heavy V2EX topics readable without turning normal links into
heavy cards.

Current state:

- Direct image suffix URLs are shown as images.
- Known direct image CDN prefixes are shown as images.
- Non-image links are shown as inline clickable text.
- Image preview/save/retry/loading preferences exist.

Gaps:

- Image-host page URLs are not reliably converted to direct image URLs.
- No content-type probing for ambiguous links.
- No provider rules table, tests, or settings for image-host behavior.
- Image upload is not implemented.

Tasks:

- Refactor `MediaUrlUtils.ets` around a typed result, for example:
  - `directImage`
  - `knownImageHostDirect`
  - `imageHostPageResolved`
  - `probeRequired`
  - `nonImageLink`
  - `unsupported`
- Keep direct-image rules first:
  - suffix: `.jpg`, `.jpeg`, `.png`, `.gif`, `.webp`, `.bmp`, `.svg`,
    `.avif`, `.heic`, `.heif`
  - query extension: `format`, `fm`, `ext`, `type`, `output`
  - known direct hosts already in `IMAGE_HOST_PREFIXES`
- Add conservative image-host page rules:
  - `https://imgur.com/<id>` -> `https://i.imgur.com/<id>.png`
    only for single-image IDs, not `/a/` or `/gallery/` albums.
  - `https://sm.ms/image/<id>`: only resolve if a stable direct URL can be
    derived or fetched; otherwise keep normal link.
  - `postimg.cc`, `ibb.co`, `imgbox.com`, `postimages.org`: add only when a
    deterministic direct URL pattern or safe parser is implemented.
- Add optional HEAD/content-type probing.
  - Probe only http/https links that are standalone, not known non-image links.
  - Respect media preferences where possible.
  - Use timeout and cache probe results locally by normalized URL.
  - If `Content-Type` starts with `image/`, render image.
  - On 403/404/timeout/non-image, keep inline link. Do not show an error block.
- Add tests or a small deterministic test harness for `MediaUrlUtils` rules.
  Include at least:
  - direct suffix URL
  - suffix with query string
  - `i.imgur.com/...jpg`
  - `imgur.com/<id>` single image page
  - `imgur.com/a/<id>` album stays link
  - `github.com/...` normal link stays link
  - `raw.githubusercontent.com/...` direct image stays image
  - unknown URL stays link unless HEAD proves image
- Update `MarkdownContent.ets`.
  - Image candidates render through current `MarkdownAutoImage`.
  - Non-image links remain selectable/clickable text.
  - Do not create a large link preview card.
- Add settings only if needed:
  - auto-load images
  - Wi-Fi-only image loading
  - content-type probing on/off if probe behavior affects performance.

Acceptance:

- Build/install/device verify on a topic containing:
  - direct image link
  - Imgur single-image page link
  - GitHub normal link
  - at least one unsupported image-host page link
- Direct images show image blocks.
- Imgur single-image page shows image only if transformed correctly.
- Album/unsupported links remain normal text links.
- No grey standalone link cards return.
- Image loading indicator remains centered.
- Full-screen preview and save image still work.

Follow-up P1 for upload:

- Add user-configured image upload provider, starting with Imgur-style
  Client-ID flow.
- Use a Harmony picker/media API, upload progress, error state, uploaded image
  history, copy URL, insert Markdown into reply/topic editors.
- Do not ship hard-coded public client IDs.
- Do not auto-upload in unattended tests.

## P0. Search Completion

Goal: match mature clients' search utility while keeping the page simple.

Current state:

- Local search across saved/viewed/cache/nodes.
- SOV2EX service and filters exist.
- Web fallback exists.

Tasks:

- Verify SOV2EX trigger behavior. The search page must have an obvious HDS
  action or keyboard action that runs remote search.
- Confirm remote parameters:
  - query
  - pagination
  - sort: relevance/sumup and created
  - order: desc/asc
  - date range
  - node filter
  - author/member filter
- Keep local results instant and separate from remote failures.
- Search history:
  - record successful queries
  - clear history
  - tap history to search
- Filter sheet:
  - use appbar-style modal scaffold with close button
  - Back closes sheet
  - no mixed-size buttons
- Opening results:
  - topic result opens `TopicDetail`
  - node result opens `NodeTopicList`
  - user/author result opens `UserProfile` where applicable.

Reference:

- V2Fun: `screens/SearchScreen.tsx`, `screens/SearchOptionsScreen.tsx`,
  `jotai/sov2exArgsAtom.ts`
- VVEX: `lib/http/soV2ex.dart`

Acceptance:

- Device tests: search `github`, a Chinese keyword, a node name, and a username.
- Remote search can load and page results.
- Remote failure does not break local search.
- Search UI remains visibly HDS-like and concise.

## P0. Detail, Reply, and Notification Loop

Goal: complete the read -> notification -> exact reply -> respond loop.

Tasks:

- Notification floor jump:
  - Parse topic id, reply id, and floor from both API v2 and web notification
    sources.
  - Pass target floor/reply into `TopicDetailParams`.
  - Topic detail loads pages until target floor/reply is visible or no more
    pages remain.
  - Use an animated scroll to target, not an abrupt jump.
- Reply controls:
  - Keep compact `楼层 / 只看楼主 / 最新` row.
  - Expose high-frequency per-floor actions directly in the floor row:
    - thank reply
    - reply to this floor
  - Keep low-frequency reply actions in `ContextMenu`:
    - copy
    - share
    - view context / related replies
    - ignore reply
    - report
    - edit where available
  - Update reply action icons to appropriate system/HDS symbols and keep the
    touch targets consistent with the current compact row.
  - Do not add large visible buttons for rare actions.
- Reply entry and composer:
  - Do not put the primary reply entry in the appbar menu.
  - Add a bottom floating reply button on topic detail, visible for logged-in
    users and disabled/recoverable for expired sessions.
  - Opening reply uses a keyboard-attached floating composer/sheet component,
    not a standalone route/page.
  - The composer should stay above the keyboard, resize with the available
    area, keep its submit/close controls visible, and preserve draft content
    when dismissed.
  - Reuse or replace `ReplyEditorPage.ets` only as a backing component/draft
    host. The normal user flow is detail page -> floating reply button ->
    composer sheet.
  - The composer sheet may use an internal appbar/title row with close,
    preview, draft, and submit actions, but it must feel like a modal attached
    to the current topic instead of a full secondary page.
- Related replies:
  - Implement related/context view through the existing modal scaffold.
  - Reference V2Fun `screens/RelatedRepliesScreen.tsx` and
    `components/topic/ReplyItem.tsx`.
- Account actions in detail:
  - thank topic
  - thank reply
  - ignore topic
  - ignore reply
  - report topic
  - favorite/unfavorite topic, preserving current behavior
  - edit topic and append topic as P1 if not safe to complete in P0.
- All paid/destructive actions require confirmation and write-action switch.

Reference:

- V2Fun: `components/topic/TopicInfo.tsx`,
  `components/topic/ReplyItem.tsx`
- VVEX: `lib/http/dio_web.dart`, `lib/pages/t/topic_id.dart`,
  `lib/components/message/notice_item.dart`
- HarmonyDO: `entry/src/main/ets/views/pages/TopicDetailPage.ets`,
  `entry/src/main/ets/views/components/ReplyComposerSheet.ets`
- ClashBox master: `entry/src/main/ets/pages/ConfigurationPage.ets`
  for floating button plus `bindSheet` lifecycle and dismiss handling.

Acceptance:

- Notification tap lands near the exact reply/floor when data exists.
- Long topic target floor loading works across pages.
- Reply filter row remains visually compact.
- Topic detail has a bottom floating reply button; the appbar menu is not the
  primary reply entry.
- Reply composer opens as a sheet/floating component, follows keyboard resize,
  keeps close/submit reachable, and does not navigate to a separate reply page.
- Each reply exposes thank and reply actions directly; lower-frequency actions
  remain in a context menu with correct icons.
- Context menu appears repeatedly without failing after multiple opens.
- Paid/destructive actions are not run by unattended tests.

## P0. Account, My Page, and User Profiles

Goal: make Cookie login the normal account mode and keep PAT advanced.

Tasks:

- Keep My page as account dashboard:
  - avatar
  - username
  - coin badges
  - daily mission/sign-in state
  - concise account entries
  - settings only in appbar menu
- Remove redundant subtitles and repeated context.
- Add account detail page:
  - balance detail
  - browser fallback
  - session state
  - logout in the detail/settings flow, not as a primary My-page row.
- Add black list page:
  - blocked users
  - ignored topics
  - reset/clear with confirmation
  - local state should affect lists where feasible.
- Add following pages:
  - following users if parseable
  - following/collected nodes
  - collected topics
- Improve user profile:
  - topics/replies tab remains.
  - hidden topics must respect website hidden state.
  - full topics/replies entries live at list tail, not as top-heavy buttons.
  - follow/block actions belong in the top-right appbar/menu area or a stable
    reserved header action slot, not below the profile content.
  - reserve default space for follow/block state so loading does not change the
    header height or push the topics/replies tab down.
  - follow/block actions update immediately and refresh from server.
  - re-entering the page must preserve correct server state.
- Session expiration:
  - every authenticated page should show a recoverable login entry.
  - stale logged-in UI must be cleared or marked stale after validation fails.

Reference:

- V2Fun: `screens/MemberDetailScreen.tsx`, `screens/BlackListScreen.tsx`,
  `screens/MyTopicsScreen.tsx`, `screens/MyNodesScreen.tsx`
- VVEX: `lib/http/user.dart`, `lib/components/adaptive/slide.dart`

Acceptance:

- Logged-in My page shows `honjow` and correct coin units.
- `0.90 铜币` stays fractional copper if source says that.
- Follow/unfollow and block/unblock state refreshes without app restart.
- User profile header height does not jump when follow/block state loads.
- Follow/block entry is available from the top-right action area, with loading
  and logged-out states represented in the same reserved slot.
- Blacklist/ignored topics page does not require PAT.
- Expired Cookie path is recoverable.

## P1. Login Hardening

Goal: make username/password login reliable, with WebView fallback.

Tasks:

- Harden `/signin` dynamic field parsing.
- Display captcha image and input when required.
- Add 2FA flow.
- Distinguish errors:
  - wrong password
  - captcha required/invalid
  - 2FA required/invalid
  - login attempts blocked by V2EX
  - network failure
  - session expired
- Validate saved Cookie by loading an authenticated page, not just by checking
  a Cookie string.
- Web login:
  - use shared scaffold correctly
  - avoid blank spacer hacks
  - save and return automatically when a valid session is detected
  - keep manual save/reload appbar actions as fallback.

Reference:

- VVEX: `lib/http/dio_web.dart`, `lib/utils/login.dart`
- V2Fun: `screens/LoginScreen.tsx`, `screens/WebSigninScreen.tsx`

Acceptance:

- Normal login succeeds.
- Wrong password shows precise error.
- Captcha challenge displays and can retry.
- 2FA challenge can complete.
- Restart preserves valid session.

## P1. Discover and Navigation

Goal: make browsing surfaces competitive with V2Fun/VVEX.

Current state:

- Discover has node search and hot/rank/latest/recent topic surfaces.

Tasks:

- Verify and polish current Discover:
  - HDS/shared scaffold
  - pull refresh
  - concise sections
  - no oversized grid/card whitespace
  - appbar menu for secondary actions
- Rework node pages to match the project architecture:
  - `DiscoverPage`
  - node search results
  - node topic list
  - collected/favorite nodes
  - all-node category navigation
  - recent/frequent nodes
- Node pages must not use ad hoc back buttons, one-off cards, or local input
  styling. Use shared scaffolds, `AppSearchField`, appbar actions, and list
  pull refresh.
- Add historical hot if stable source is available.
- Add rank/community pages beyond the small embedded list if parseable.
- Add all-nodes navigation with categories.
- Add frequent/recent nodes.
- Add home tab management:
  - sort tabs
  - hide/show tabs
  - add node tab
  - restore defaults
  - persist across restart.
- Add node sorting/favorites management.

Reference:

- V2Fun: `screens/HomeScreen.tsx`, `screens/SortTabsScreen.tsx`,
  `screens/HotestTopicsScreen.tsx`, `screens/RankScreen.tsx`,
  `screens/NavNodesScreen.tsx`
- VVEX: `lib/components/adaptive/main.dart`,
  `lib/components/home/tab_bar_list.dart`

Acceptance:

- Hot/rank/latest/recent open topic detail.
- Tab management survives restart.
- Discover remains compact and HDS-like.
- Node pages and notification pages visually match secondary pages such as
  detail/settings: safe area, appbar, list spacing, pull refresh, and menu
  behavior are consistent.

## P1. Writing and Editing

Goal: make writing usable while keeping account-changing operations protected.

Tasks:

- Reply composer:
  - keyboard-attached floating sheet, not a normal route
  - bottom floating reply button as the primary entry on topic detail
  - shared HDS/modal scaffold with internal close/preview/submit actions
  - Markdown toolbar
  - preview
  - mention insertion
  - image link insertion
  - upload insertion after media upload exists
  - autosave and restore
  - draft restore when reopening from the same topic/floor
- Topic editor:
  - node picker
  - Markdown toolbar
  - preview
  - draft save
  - submit confirmation
- Add edit topic:
  - parse original form
  - preview
  - confirm
  - submit only with write-action switch enabled.
- Add append topic:
  - parse form/status
  - preview
  - confirm
  - guarded submit.
- Keep drafts until confirmed success.

Reference:

- V2Fun: `screens/WriteTopicScreen.tsx`, `components/topic/ReplyBox.tsx`,
  `components/UploadImageButton.tsx`
- VVEX: `lib/http/dio_web.dart`, `lib/pages/page_write.dart` if present,
  `lib/components/topic/reply_new.dart`

Acceptance:

- Drafts survive restart.
- Submit controls disabled when write-action switch is off.
- Manual real submission requires explicit user approval.

## P1. Settings and Personalization

Goal: turn settings from engineering controls into product controls.

Tasks:

- Reorganize Settings:
  - Account
  - Reading
  - Content and media
  - Notifications
  - Writing
  - Storage
  - Advanced
- Reading:
  - reply order default
  - OP-only/highlight default
  - font size
  - line height
  - density
  - code wrapping
- Content/media:
  - auto-load images
  - Wi-Fi-only images
  - image-host probing if implemented
  - link open preference
- Notifications:
  - polling/local notification preference
  - quiet behavior
- Writing:
  - global write-action switch
  - image upload provider settings
- Advanced:
  - PAT metadata
  - API domain
  - cache/debug controls.

Reference:

- V2Fun: `screens/SettingScreen.tsx`, `screens/ConfigureDomainScreen.tsx`,
  `screens/CustomizeThemeScreen.tsx`, `jotai/*Atom.ts`
- VVEX: `lib/utils/storage.dart`

Acceptance:

- Settings and My do not duplicate account controls.
- No row subtitle restates the row title.
- Settings page spacing matches other secondary pages.

## P2. System Integration

Goal: make V2Next feel native on HarmonyOS.

Tasks:

- Deep links:
  - topic by id
  - member by username
  - node by name
  - search by query
- Open external V2EX URLs in app where possible.
- Launcher quick actions if Harmony supports them:
  - search
  - today hot
  - draft
  - notifications
- Local notification polling after notification data is stable.
- Notification tap routes to exact topic/floor.
- Tablet/two-pane layout after phone layout stabilizes.

Reference:

- V2Fun: `navigation/LinkingConfiguration.ts`, `app.json`
- VVEX: Android `AndroidManifest.xml`, `lib/utils/app_scheme.dart`,
  `lib/service/local_notice.dart`

Acceptance:

- Opening a V2EX topic/member/node URL lands on the correct page.
- Notification tap opens expected topic/floor.
- System integration does not require login unless action needs account data.

## Work Breakdown for Child Threads

Recommended order:

1. P0 Media and Image Host Handling.
2. P0 Architecture and UI Baseline.
3. P0 Search Completion.
4. P0 Detail/Notification Loop.
5. P0 Node/Notification architecture cleanup.
6. P0 Account/My/User.
7. P1 Login Hardening.
8. P1 Discover/Navigation.
9. P1 Writing/Editing.
10. P1 Settings/Personalization.
11. P2 System Integration.

Each child thread should:

- Start by reading this document plus `docs/ui-guidelines.md`.
- Inspect relevant current files before editing.
- Inspect only the listed reference paths needed for the task.
- Keep write scope narrow and state it in the final message.
- Avoid touching unrelated UI.
- Avoid running real paid/destructive actions.
- Build/install/device-verify before commit.
- Commit each coherent feature separately.

Suggested child-thread prompts:

### Media Child Thread

```text
Implement P0 Media and Image Host Handling from docs/roadmap-v2ex-client.md.
Focus on MediaUrlUtils and MarkdownContent only unless settings are strictly
needed. Preserve direct links as inline text, preserve direct image rendering,
do not reintroduce link cards, and do not implement upload in this step.
Build, install to 192.168.50.237:12345, verify with screenshots on a topic that
contains direct image, Imgur page link, and normal GitHub link, then commit.
```

### Architecture Child Thread

```text
Implement the first safe slice of P0 Architecture and UI Baseline from
docs/roadmap-v2ex-client.md. Split one ownership area out of Index.ets, prefer
HDS/shared components, and do not change visual behavior outside that area.
Build, install, screenshot affected pages, and commit.
```

### Search Child Thread

```text
Complete P0 Search from docs/roadmap-v2ex-client.md. Verify SOV2EX execution,
pagination, filter sheet Back dismissal, result navigation, and local-search
fallback. Preserve HDS/shared controls and concise UI. Build, install, screenshot
Search states, and commit.
```

### Detail/Notification Child Thread

```text
Complete the P0 Detail/Reply/Notification slice from
docs/roadmap-v2ex-client.md. Implement notification floor jump, expose per-reply
thank/reply actions, keep rare actions in ContextMenu with correct icons, and
replace standalone reply-page navigation with a bottom floating reply button
plus keyboard-attached composer sheet. Keep the current compact
`楼层 / 只看楼主 / 最新` filter row. Do not run paid/destructive actions
unattended. Build, install, verify notification-to-floor when data exists,
verify composer keyboard behavior, screenshot TopicDetail and composer, then
commit.
```

### Node/Notification Architecture Child Thread

```text
Bring node and notification pages into the shared HDS-first architecture from
docs/roadmap-v2ex-client.md. Move notification ownership out of Index.ets where
safe, migrate node/discover/notification pages to shared scaffolds, remove
page-local back buttons and one-off inputs/cards, add pull refresh where
appropriate, and keep existing data behavior unchanged. Build, install,
screenshot Discover, NodeTopic, Notifications, and one notification/detail jump
when data exists, then commit.
```

## Verification Checklist

Use this for every commit:

- `git status --short`
- `bash dev.sh --build-only`
- `bash dev.sh --no-build -d 192.168.50.237:12345`
- Launch app:
  `/home/gamer/devtool/ohos/command-line-tools/sdk/default/openharmony/toolchains/hdc -t 192.168.50.237:12345 shell "aa start -a EntryAbility -b com.next2v.app"`
- Interact with affected flows.
- Capture screenshot:
  `/home/gamer/devtool/ohos/command-line-tools/sdk/default/openharmony/toolchains/hdc -t 192.168.50.237:12345 shell "snapshot_display -f /data/local/tmp/<name>.jpeg"`
- Pull screenshot to `/tmp`, inspect it.
- Optional layout dump for text/state proof:
  `/home/gamer/devtool/ohos/command-line-tools/sdk/default/openharmony/toolchains/hdc -t 192.168.50.237:12345 shell "uitest dumpLayout"`
- `git diff --check`
- Review `git diff`
- Commit with accurate message.
