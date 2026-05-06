# V2Next V2EX Client Roadmap

This document is the handoff guide for continuing V2Next development in a new
session. It records the current implementation state, the gap versus mature V2EX
clients and the V2EX website, and a feature-first development plan.

## Current Implementation State

V2Next is already past the read-only prototype stage. The app can browse public
content, keep useful local state, sign in, show account metadata, and render
image-heavy topics.

Implemented:

- Public browsing through parsed V2EX tabs and public API endpoints.
- Home tabs with category-specific content and horizontal tab switching.
- Node discovery, node search, node topic pages, and locally saved nodes.
- User profile page with profile metadata and recent topics.
- Topic detail page with Markdown rendering, replies, pull refresh, cache,
  read/unread state, last read floor, jump to latest, jump to floor,
  original-poster filter, local save-later, recent-view recording, copy, share,
  and browser open actions.
- Personal Access Token storage, verification, token metadata, API rate-limit
  snapshot, and PAT-backed API v2 reads.
- Cookie session storage, WebView login flow, native username/password login
  prototype, session validation, and logout.
- Account block on My page with avatar, username, V2EX balance, custom-drawn
  coin badges, daily mission status, and manual sign-in action.
- API v2 wrapper for member, token, notifications, notification deletion, node
  detail, node topics, topic detail, topic replies, generic GET/POST/DELETE, and
  rate-limit headers.
- Cookie-backed balance, daily mission, and notification parsing paths.
- Notification list pagination, cache, tap-to-topic, and single notification
  deletion when PAT is configured; notification rows also expose read/unread and
  type labels when the backing source provides enough signal.
- Cookie-backed account content pages for collected topics, replies, and
  collected nodes, plus browser fallback links for deeper account pages.
- Site-synced topic favorite/unfavorite and node follow/unfollow flows using
  Cookie-backed once-token actions with post-action state refresh.
- Guarded Cookie-backed topic and reply submission adapters behind the
  write-action switch, with form-token parsing, confirmation dialogs, in-flight
  states, and draft clearing only after success.
- Inline Markdown images, bare direct image links, common image host recognition,
  image loading states, retry, full-screen preview, pinch zoom, and image loading
  preferences. GIF, static WebP, and animated WebP rendering have been verified
  on the target device through ArkUI `Image`.
- Standalone non-image links render as preview cards for common hosts
  (YouTube/Vimeo/Gist/Imgur/V2EX/default URL) while direct image URLs stay on
  the controlled inline image path.
- Reply and topic draft editors with Markdown preview, autosave, node picker,
  image link insertion, and disabled submit controls behind the write-action
  switch.
- Reading upgrades include reply conversation context, compact reply action
  menus, mention/copy-user actions, raw text selection panels, code block
  language/wrap/copy controls, and font size/line height/density preferences.
- Local search across saved topics, viewed topics, cache, saved nodes, node index,
  history, and external web search fallback.
- Settings page, local data reset, cache management, media settings,
  write-action switch, API domain switch, and HDS usage notes.

Key files:

- `entry/src/main/ets/pages/Index.ets`: app shell, tabs, My page, notifications,
  local saved/viewed/node pages, account metadata.
- `feature/detail/src/main/ets/pages/TopicDetailPage.ets`: topic detail,
  reply controls, topic actions.
- `feature/detail/src/main/ets/pages/ReplyEditorPage.ets`: reply draft editor.
- `entry/src/main/ets/pages/TopicEditorPage.ets`: topic draft editor.
- `entry/src/main/ets/pages/SearchPage.ets`: local and external search UI.
- `feature/user/src/main/ets/pages/UserProfilePage.ets`: user profile.
- `shared/src/main/ets/network/ApiService.ets`: public API and Cookie-backed
  parsers.
- `shared/src/main/ets/network/ApiV2Service.ets`: authenticated API v2 wrapper.
- `shared/src/main/ets/components/MarkdownContent.ets`: Markdown and image
  rendering.

## Product Gap Summary

The biggest gap is not the main reading path. The biggest gap is the logged-in
daily-use loop: account content, notification handling, real write operations,
and site-synced actions.

Compared with mature V2EX clients, V2Next still lacks:

- Deeper account management surfaces, multi-account switching, and optional
  account data sync.
- Thank topic/reply, block user, edit topic, append topic, image upload, and
  other authenticated actions beyond favorite/follow/reply/topic creation.
- Mature notification workflow: grouping, batch handling, richer navigation
  context, and site-synced state changes where V2EX exposes stable paths.
- Long-image polish and remaining edge cases in image-heavy topics.
- In-app remote topic search.
- Consistent first-party-feeling Harmony UI across all secondary pages.

Compared with the V2EX website, V2Next still lacks:

- Full site-native V2EX original-format parity for every supported expansion
  form; common standalone image/link cases are covered, but embedded website
  behavior may still differ.
- Full virtual-currency-related workflows: edit, thank, sticky, boost,
  invite-code purchase, and deeper cost/permission explanations.
- Block behavior that affects lists, replies, and notifications.
- V2EX image-host upload flow.
- Account settings, balance detail, and browser-level account pages.

Important API constraint:

- V2EX API 2.0 currently covers notifications, notification deletion, member,
  token, node, node topics, topic, topic replies, sticky, and boost.
- Common actions such as normal topic creation, reply creation, thank,
  favorite/unfavorite, block, edit, append, and image upload likely need
  Cookie-backed HTML form adapters unless the official API changes.

## Product Principles

1. Normal users should be able to use username/password login or official WebView
   login. PAT remains an advanced/API mode, not the primary UX.
2. Prefer official API v2 when it exposes the needed operation. Use Cookie-backed
   page parsing/form submission only for features API v2 does not expose.
3. Write operations must be explicit, visible, confirmed, and protected by the
   global write-action switch.
4. Never auto-submit posts, replies, thanks, favorites, blocks, sticky, boost, or
   other account-changing actions during unattended validation.
5. Passwords, tokens, cookies, and screenshots containing credentials must never
   be committed, logged, or shown.
6. Keep UI work aligned with Harmony Design System and local HDS notes. Prefer
   shared scaffolds over per-page padding fixes.
7. Every shipped feature must pass build, install, device interaction, screenshot
   review, `git diff --check`, diff review, and an accurate commit.

## Recommended Development Order

### P0. Account Read Loop

Goal: make normal Cookie login useful beyond showing "logged in".

Status: collected topics, replies, collected nodes, account metadata, browser
fallback links, session invalidation paths, and advanced-only PAT diagnostics are
implemented. Remaining work is mostly deeper account management and multi-account
polish.

Tasks:

- [x] Add Cookie-backed "my topics" and "my replies".
- [x] Add "my favorites" or equivalent site-favorite surface if the website
  exposes a stable parseable page.
- [x] Add account-detail navigation from My page, with balance detail and browser
  fallback links.
- [x] Make session expiration recoverable everywhere: clear error, relogin
  action, and no stale "logged in" UI.
- [x] Tighten WebView cookie save validation so a random non-empty cookie is not
  treated as a valid login.
- [x] Keep PAT metadata visible only as advanced/debug account info.

Validation:

- Cookie login persists across app restart.
- My topics and my replies load with the real Cookie session.
- Expired/invalid Cookie leads to a recoverable login state.
- My page shows only useful account entry, balance, and sign-in status.

### P0. Notification Center Completion

Goal: notifications work for both normal login and PAT mode.

Status: PAT and Cookie notification paths are unified behind a page view model
with pagination/cache, source labels, grouped kind summaries, type/read labels,
tap-to-topic, PAT-only deletion, and stale-cache labeling. Remaining work is any
safe site-synced state changes that V2EX exposes.

Tasks:

- [x] Unify PAT-backed and Cookie-backed notification loading behind one view
  model.
- [x] Preserve PAT as the structured preferred path when available.
- [x] Add clear state labels for unread/read/deleted where the source supports
  it.
- [x] Add better grouping or metadata for mention, reply, thank, and system
  events.
- [x] Add safe deletion behavior for PAT path; keep batch delete disabled until
  confirmed and carefully tested.
- [x] Cache notifications without showing stale data as current.

Validation:

- Cookie login loads notification pages or gives a precise unsupported/expired
  state.
- PAT notifications still page and delete correctly.
- Tap-to-topic works from each notification type.

### P0. Site-Synced Collections

Goal: separate local convenience from real V2EX account state.

Status: topic favorite/unfavorite and node follow/unfollow are implemented with
Cookie-backed once-token actions and post-action refresh. Local save-later remains
separate from site state.

Tasks:

- [x] Implement site favorite/unfavorite topic using Cookie-backed form adapters.
- [x] Implement site follow/unfollow node if V2EX exposes stable actions.
- [x] Keep local save-later as a separate feature, named clearly.
- [x] Sync local state after successful site action.
- [x] Add failure recovery and avoid optimistic state that cannot be reconciled.

Validation:

- Favorite/follow state survives restart and matches the website.
- Local save-later remains independent.
- Disabled write-action switch prevents site-changing operations.

### P0. Guarded Writing Flow

Goal: move from drafts to manual, confirmed submission.

Status: Cookie-backed reply and topic submission adapters are implemented behind
the write-action switch with confirmation dialogs, in-flight state, failure
messages, and draft clearing only after success. Further work should focus on
manual production validation and later edit or append flows. Submit confirmations
show the target topic/node and likely V2EX coin cost before sending.

Tasks:

- [x] Design Cookie-backed reply submit adapter.
- [x] Design Cookie-backed topic submit adapter.
- [x] Parse and send required form tokens (`once`, hidden fields, syntax mode,
  node, title, content) from live pages.
- [x] Keep submit disabled unless the global write-action switch is enabled.
- [x] Add confirmation dialogs showing target topic/node and possible coin cost.
- [x] Add in-flight state, retry guidance, and failure messages from V2EX.
- [x] Clear draft only after confirmed success.
- [x] Never submit during unattended tests.

Validation:

- Drafts survive restart.
- Submit UI cannot be triggered when write actions are disabled.
- Manual test uses a safe private/low-risk flow and requires explicit user
  approval before real submission.

### P1. Reading Experience Upgrade

Goal: match mature V2EX clients on discussion reading.

Status: the listed reading upgrades are implemented in the current app: reply
context, compact reply actions, text selection/copy, code block controls, reply
user actions, and reading display preferences. Future work here should focus on
performance, visual consistency, and edge-case polish.

Tasks:

- [x] Add reply conversation/context view: for a selected reply, show related
  mentions/replies and useful surrounding context.
- [x] Improve reply toolbar layout. Avoid crowded chips; move rarely used actions
  into appbar menu or a compact toolbar.
- [x] Add robust text selection/copy for topic body, replies, and code blocks.
- [x] Improve code block rendering, wrapping, and copy actions.
- [x] Add user actions from reply/user rows: open profile, copy username, mention
  in reply draft.
- [x] Add reading settings: font size, line height, maybe compact/comfortable
  density.

Validation:

- Long topics and long reply threads remain smooth.
- Reply context is understandable and easy to dismiss.
- Text selection/copy works for normal text and code.

### P1. Media and Link Polish

Goal: make image-heavy and link-heavy topics comfortable.

Status: image URL classification, save-image flow, GIF/WebP verification,
standalone link cards, common host labels, direct image rendering, and non-image
link click handling are implemented. Remaining work is long-image polish and
deeper website-format parity where feasible.

Tasks:

- [x] Move image URL classification into a shared utility if any logic is still
  duplicated.
- [x] Add save-image flow with the correct Harmony picker/permission model.
- [x] Verify GIF/WebP behavior on target devices. Verified on
  `192.168.50.237:12345`: static WebP renders, animated GIF advances frames,
  and animated WebP advances frames through ArkUI `Image`. Platform note:
  ImageKit lists `gif` and `webp` as supported image-source formats but recommends
  querying the device's supported formats before custom decoding because some
  decode capabilities depend on device hardware.
- [x] Add non-direct image/link preview cards for common hosts.
- [x] Add V2EX original-format expansions where feasible: imgur/i.v2ex.co
  images, Gist cards, YouTube/Vimeo link cards, and normal URL cards.
- [x] Keep direct image URLs rendered inline and non-image links clickable.

Validation:

- Direct images render inline.
- Image save works without broad storage permission if possible.
- Long image preview and zoom do not break layout.
- Non-direct links never block Markdown rendering.

### P1. Search Upgrade

Goal: improve discovery without brittle scraping.

Status: instant local search, source-specific labels/error isolation,
topic/node/user filters, external web fallback, and recent query history are
implemented. In-app remote topic search remains a future task until a stable
official source is selected.

Tasks:

- [x] Keep local search as instant default.
- [ ] Evaluate in-app remote source options. If there is no stable official topic
  search API, keep external web fallback and make the UX clearer.
- [x] Add source-specific result labels and error isolation.
- [x] Add topic/node/user filters.
- [x] Add better recent query management.

Validation:

- Local search remains fast with cache and node index.
- Remote failures never break local results.

### P2. Advanced Account Actions

Goal: cover more website capabilities after core reading/writing is stable.

Tasks:

- Thank topic and thank reply with coin-cost confirmation.
- Block/unblock user and hide blocked users locally after confirmed site action.
- Edit topic within V2EX rules and coin-cost constraints.
- Append topic after V2EX allows it.
- Sticky and boost only with explicit confirmation, clear cost, and permission
  explanation.
- Invite-code purchase only if user explicitly asks for it.
- V2EX image-host upload, if account and permissions allow it.
- Multi-account switching after single-account Cookie/PAT state is reliable.

Validation:

- Every action displays cost/impact before submission.
- No destructive or paid action runs during unattended validation.

### P2. UI System Stabilization

Goal: make the app feel like a coherent first-party Harmony app.

Tasks:

- Standardize all secondary pages on a shared scaffold for safe area, title bar,
  background, padding, and bottom actions.
- Use Detail and Settings as the visual reference for secondary pages.
- Rework Search, Login, TopicEditor, ReplyEditor, UserProfile, Node pages, and
  local-list pages to the same spacing model.
- Keep settings centralized in Settings and avoid duplicate preferences in My.
- Convert settings-like surfaces to dense list rows; reserve cards for real
  content items.
- Audit page horizontal padding, section spacing, empty states, button heights,
  and text overflow.
- Verify light/dark mode, top title blur, bottom floating tab blur, and no
  content hidden behind system areas.

Validation:

- Build and install on `192.168.50.237:12345`.
- Capture screenshots/layout dumps for Home, Discover, Notifications, My,
  Settings, Detail, Node, User, Search, Login, TopicEditor, and ReplyEditor.
- Compare secondary pages side by side for consistent safe area and padding.

## Reference Comparison Notes

Mature V2EX clients commonly provide:

- Full browsing for topics, comments, nodes, user pages, collections, search, and
  notifications.
- Account features: login, automatic or manual daily mission, personal content,
  favorites, notification state, balance, and account switching.
- Interactive actions: reply, topic creation, thank, favorite, block, and basic
  account operations.
- Reading features: image rendering, image saving, link parsing, code blocks,
  reply context, dark mode, font size, line-height settings, and smooth large-list
  navigation.
- Local reliability: cache, browsing history, drafts, multi-account state, and
  optional sync.

V2EX website capabilities to keep in mind:

- Creating a topic costs at least 20 copper.
- Editing a topic within the allowed window costs 5 copper.
- Replying costs at least 5 copper.
- Thanking a topic costs 15 copper; thanking a reply costs 10 copper.
- Sticky and boost consume coins and have eligibility constraints.
- V2EX supports Markdown and original formatting. Original formatting auto
  expands some image, video, Gist, and URL links.
- Block affects lists, replies, and reminders.
- V2EX image hosting supports JPEG, PNG, and GIF up to 6 MB for eligible paid
  users.

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

Use the existing device tools:

- HDC path:
  `/home/gamer/devtool/ohos/command-line-tools/sdk/default/openharmony/toolchains/hdc`
- Device:
  `192.168.50.237:12345`

Do not commit `.env.local`, cookies, tokens, screenshots, device dumps, or
external tool folders such as `.claude/`, `.cursor/skills/`, and `.opencode/`.
