# V2Next V2EX Client Roadmap

This document tracks the current product state and the next development plan for
V2Next. It replaces the older phase-only checklist because several foundational
features have already landed.

## Current State

Implemented baseline:

- Public browsing through parsed V2EX tabs and public API endpoints.
- Home tabs with category-specific content and horizontal tab switching.
- Topic detail page with Markdown rendering, reply list, pull refresh, cache,
  read/unread state, last read floor, jump to latest, jump to floor, and
  original-poster filter.
- User profile page, node discovery, node topic page, saved nodes, saved topics,
  and recently viewed topics.
- Personal Access Token storage, verification, token metadata, and API rate-limit
  snapshot.
- Cookie session storage, WebView login flow, native username/password login
  prototype, session validation, and logout.
- API v2 wrapper for node detail, node topics, topic detail, topic replies,
  notification deletion, generic GET/POST/DELETE, and rate-limit headers.
- Notification list pagination, cache, tap-to-topic, and single notification
  deletion with confirmation when PAT is configured.
- Inline Markdown images, bare direct image links, common image host recognition,
  image loading states, retry, full-screen preview, pinch zoom, and image loading
  preferences.
- Reply and topic draft editors with Markdown preview, autosave, node picker,
  image link insertion, and disabled submit controls behind the write-action
  switch.
- Local search across saved topics, viewed topics, cache, saved nodes, node index,
  history, and external web search fallback.
- Settings page, local data reset, cache management, media settings, write-action
  switch, API domain switch, and HDS usage notes.

Known product gaps:

- Cookie login is not yet used for full account features such as my topics, my
  replies, favorite/unfavorite, thank, ignore, daily sign-in reward, balance, or
  account navigation.
- Notification reading is still PAT-first. Cookie login alone does not unlock the
  notification center.
- WebView login can save any non-empty cookie before strong validation; the app
  validates afterwards, but the save step should be stricter.
- Native username/password login is fragile because it parses V2EX HTML with
  regular expressions.
- In-app remote topic search is not implemented. External search opens a browser.
- Reply/topic submission is intentionally disabled. Submit adapters still need to
  be designed, gated, confirmed, and tested.
- Image saving and non-direct image link preview cards are not implemented.
- UI is functional but not yet system-grade. Current issues include duplicated
  settings surfaces, inconsistent page padding, imperfect immersive safe-area
  handling, and some card-heavy layouts.

## Product Principles

1. Normal users should be able to use username/password or official WebView
   login. PAT remains an advanced/API mode.
2. Prefer official API v2 when available. Use Cookie-backed page parsing only for
   client features that API v2 does not expose.
3. Write operations must be explicit, visible, confirmed, and protected by the
   global write-action switch.
4. Passwords, tokens, and cookies must never be committed, logged, or shown in
   screenshots.
5. Every shipped feature must pass build, install, device interaction, screenshot
   review, `git diff --check`, and diff review before commit.

## Next Roadmap

### 1. UI System Stabilization

Goal: make the app shell feel closer to a first-party Harmony app before adding
more account surfaces.

Tasks:

- Fix immersive safe-area handling for navigation title bars, tab bar blur, and
  page content in Home, Discover, Notifications, My, Detail, Node, User, Search,
  Login, and Settings.
- Remove redundant settings controls from My or Settings so each preference has a
  single primary home.
- Convert settings-like surfaces to dense list rows and reserve cards for real
  content items.
- Audit page horizontal padding, section spacing, empty states, button heights,
  and text overflow.
- Recheck user profile spacing and metadata rows.
- Verify light/dark mode, top title blur, bottom floating tab blur, and no content
  hidden behind system areas.

Validation:

- Build and install on `192.168.50.237:12345`.
- Capture layout dumps/screenshots for Home, Discover, Notifications, My,
  Settings, Detail, Node, User, Search, and Login.
- Confirm title bar and floating tab material effects are visible and not covered
  by manual blank padding.

### 2. Cookie Account Read Features

Goal: make Cookie login useful beyond "logged in" status.

Tasks:

- Add a Cookie-backed account page parser/repository.
- Add my topics and my replies.
- Add account links for balance, settings, and browser fallback.
- Add daily sign-in reward detection and a guarded manual action.
- Add clear error states for captcha/session expiration.

Validation:

- Cookie login persists across restart.
- My topics and my replies load with a real Cookie session.
- Session expiration leads to a recoverable login state.

### 3. Notification Center Upgrade

Goal: notification center works for normal login and PAT mode.

Tasks:

- Decide whether Cookie notification parsing is reliable enough.
- If yes, add Cookie-backed notification loading.
- Keep PAT API v2 path as the preferred structured path when PAT exists.
- Add better notification grouping and read/delete state.
- Keep batch clear disabled until confirmed by the user.

Validation:

- PAT notifications still page and delete correctly.
- Cookie login either loads notifications or clearly explains why PAT is needed.

### 4. Search Upgrade

Goal: improve discovery without brittle scraping.

Tasks:

- Keep local search as instant default.
- Evaluate in-app remote source options.
- Add source-specific error isolation and result labels.
- Add node/topic filters and recent query management.

Validation:

- Local search remains fast with cache and node index.
- Remote failures never break local results.

### 5. Writing Flow

Goal: move from drafts to manual, guarded submission.

Tasks:

- Design reply submit adapter using Cookie session.
- Design topic submit adapter using Cookie session.
- Keep submit disabled unless the global write-action switch is enabled.
- Add confirmation dialogs, in-flight state, retry, and failure recovery.
- Never auto-submit during unattended validation.

Validation:

- Drafts survive restart.
- Preview remains accurate for common Markdown.
- Submit UI cannot be triggered when write actions are disabled.

### 6. Media Polish

Goal: make image-heavy topics comfortable to read.

Tasks:

- Move image URL classification into a shared utility.
- Add non-direct image link preview cards for common page links.
- Research and implement save-image flow with the correct system picker or
  permission model.
- Verify GIF/WebP behavior on target devices.

Validation:

- Direct image URLs render inline.
- Non-image links remain normal links.
- Preview handles long images and zoom without layout breakage.

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

Do not commit `.env.local`, cookies, tokens, screenshots, device dumps, or
external tool folders such as `.claude/`, `.cursor/skills/`, and `.opencode/`.
