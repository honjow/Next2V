# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Next2V (repo dir `V2Next`) is a native **HarmonyOS NEXT** third-party V2EX client written in **ArkTS/ArkUI**. It browses, reads, replies to, and manages a V2EX account, parsing V2EX's web pages and JSON APIs into native models.

- SDK: `26.0.0` (HarmonyOS 26.0.0 Beta1, API 26 Beta1). DevEco command-line tools 26.0.0.461 or compatible.
- Multi-module Hvigor workspace. Package manager: `ohpm`.
- This is a HarmonyOS project: **consult the `harmony-next` skill / references for any ArkTS/ArkUI/NDK API, DevEco, `hdc`/`uitest`/`hilog` task** rather than guessing API shapes.

## Build / Sign / Install

The one-stop script is `dev.sh` (Chinese help: `bash dev.sh --help`). It backs up & swaps `AppScope/app.json5` bundle name and debug branding around the build, then signs via `scripts/sign.py`.

```bash
bash dev.sh                       # debug: build + sign + install to cached/selected device
bash dev.sh --build-only          # debug: build + sign only (no install)
bash dev.sh --release-build-only  # release: build + sign only
bash dev.sh --no-build            # re-sign + install last artifact
bash dev.sh --launch              # aa start the app
bash dev.sh --log                 # hilog | grep next2v
```

Raw HAP build (what CI runs, no signing):

```bash
hvigorw assembleHap --mode module -p product=default -p buildMode=debug --no-daemon
```

- **Single bundle ID `com.honjow.next2v` for both debug and release** (unified 2026-06-05; the old debug split `com.next2v.app` is retired). The debug build wears a distinct **slate icon** (`dev.sh` applies/restores the debug branding) but shares the release bundle name and is signed with the **same account-level debug key** (same private key/CSR as the release cert), so a debug build **installs over (overwrites) the installed release in place — no uninstall, no data loss**. `dev.sh` still swaps/restores the debug branding resources per build. QA installs/launches/queries `com.honjow.next2v`.
- Signing material lives at `/home/gamer/.config/harmony/debug-signing` (`debug.p12`, debug cert, `profiles/com.honjow.next2v.p7b`). Never generate a Profile, open a browser, or call Huawei/AGC login to find it; set `NEXT2V_SIGN_NONINTERACTIVE=1` for non-interactive signing. Signing files are never committed.
- `oh-package-lock.json5` and `build-profile.json5` signing config are not committed unless the change is intentional.

## Tests / Gates

There is **no single test runner**. Contract tests are standalone Node scripts under `scripts/` (~100 `*.mjs` files) run individually; most are static/source-contract checks, some run logic. Python checks (`check_i18n_duplicates.py`, `static_*_contracts.py`) cover i18n and network proxy.

```bash
node scripts/test_<name>_contract.mjs        # run one contract
python3 scripts/check_i18n_duplicates.py     # i18n duplicate check
```

**Mandatory gate for any ArkTS/UI/state change** — must report `0 file(s)` with live V1 decorators before merge/push:

```bash
node scripts/test_v1_decorator_inventory_contract.mjs
```

When you change a subsystem, find and run the matching `scripts/test_*_contract.mjs` (e.g. topic detail → `test_topicdetail_v2_contract.mjs`, feed tabs → `test_feed_tab_bridge_v2_contract.mjs`, accounts → `test_account_v2_contract.mjs`).

## Format & Commits

```bash
npx @ohos-rs/oxk format --quote-style single --semicolons as-needed <file.ets>
```

- Commit messages: **English only**, Conventional Commits `type(scope): description` (`feat`/`fix`/`refactor`/`style`/`docs`/`chore`/`perf`). Add a body with Why/What/Validation for bug fixes, parser/network changes, and write actions. Never include cookies, tokens, `once` values, passwords, or 2FA codes.
- Don't commit unless explicitly asked.
- Code comments: English, explain *why* (product constraints, platform quirks, state invariants), not *what*. User-facing strings are Chinese and must be i18n resources.

## Architecture

Dependency graph (all feature modules depend only on `shared`; `entry` orchestrates everything):

```
entry  ──> shared, feed, detail, node, user, settings   (nav shell + tabs + routing)
feed   ──> shared    HomePage (tab 0), FeedViewModel
detail ──> shared    TopicDetailPage, ReplyEditorPage, DetailViewModel
node   ──> shared    DiscoverPage, NodeTopicPage, NodePickerPage
user   ──> shared    UserProfilePage, UserTopicsPage, UserRepliesPage
settings ─> shared   SettingsPage + reading/storage/network/domain/diagnostics pages
shared ──> (none)    network · parser · state · settings · components · theme · services · utils
```

Feature modules never import each other; cross-feature interaction goes through `shared/` state holders and `entry`'s navigation.

### Data flow

`HttpClient` → `ApiService`/`ApiV2Service` → HTML/JSON **parsers** → `NetworkTypes` models → feature **ViewModels** → **AppStorageV2 state holders** → `@ComponentV2` pages.

- **Network** (`shared/src/main/ets/network/`): `HttpClient` (singleton, retry/backoff, GET cache, configurable base URL), `ApiService` (web-parsed public/auth pages), `ApiV2Service` (`/api/v2` token JSON), `V2exTopicWebRepliesClient` (web fallback for replies), native login/2FA, SOCKS5 proxy. Models and `translateApiError()` live here.
- **Parsing** (`shared/src/main/ets/parser/`): V2EX HTML → models via in-house regex/DOM traversal (**no external HTML library**). One parser per page type (tab feed, topic replies, account dashboard, member page, notifications, nodes, signin/session, write forms, collection-toggle actions). V2EX page-structure changes break these — they are the most fragile layer.
- **Theme** (`shared/src/main/ets/theme/ThemeConstants.ets`): all design tokens. **Never hardcode** pixel sizes, colors, or font sizes in components — use `ThemeConstants` (spacing `SPACE_*`, `FONT_SIZE_*`, radii, system-color aliases like `TEXT_PRIMARY`/`TEXT_LINK`). New colors need dark + light theme coverage.
- **Components** (`shared/src/main/ets/components/`): reusable `@ComponentV2` UI (`TopicCard`, `ReplyCard`, `MarkdownContent`/`HtmlContent`, `Avatar`, list scaffolds with pull-refresh & pagination, form controls, `V2exWebView`). Reuse these before building new UI. Markdown uses `@lidary/markdown`; custom rendering re-types tokens (e.g. `code` → `customCode`) and handles them in `customBlockBuilder`.
- **Settings** (`shared/src/main/ets/settings/`): preference snapshots/bridges over the `preferences` Kit — `SettingsBootstrap` restores config at startup; `CookieJarSettings`, `AuthSettings`, `AccountStore` (multi-account), feed/theme/language/cache/collection/blocked-list settings.

### Navigation

`entry/src/main/ets/pages/Index.ets` is the nav shell: `HdsNavigation` over a `NavPathStack` plus 4 `HdsTabs` (Home / Discover / Notifications / Me). Routed pages are pushed by name — `connectNavStack().stack.pushPathByName('TopicDetail', params)`. `EntryAbility` parses deep links via `V2exUrlRouter` into `PendingV2exUrlState`, which `Index` consumes. Title-bar action buttons (favorite/save/thank) use one-writer command-bus state holders read back by the page.

## State Management V2 — hard constraint

**State Management V1 is retired. Never introduce or restore V1 decorators** in `entry/`, `feature/`, or `shared/`: `@Component`, `@State`, `@Prop`, `@Link`, `@Watch`, `@StorageLink`, `@StorageProp`, `@Provide`, `@Consume`, `@ObjectLink`, `@Observed` (bare), `@Track`, `@LocalStorageLink`, `@LocalStorageProp`. Do **not** add a V1 adapter, allowlist entry, temporary bridge, or key-churn refresh hack (`Date.now`/random/version bumps to force re-render). If a change appears to require V1, stop and report `BLOCKED` with source/build evidence and a V2-only alternative.

Use V2 only: `@ComponentV2`, `@ObservedV2`, `@Trace`, `@Local`, `@Param`, `@Monitor`, and the project's state holders.

The project's canonical holder pattern (see `shared/src/main/ets/state/`, e.g. `NavStackHolder.ets`, `TopicDetailAppbarState.ets`, `FeedTabState.ets`):

```ets
@ObservedV2
export class TopicDetailAppbarState {
  @Trace savedLater: boolean = false   // @Trace fields are the subscription points
  @Trace title: string = '';
}
const KEY: string = 'v2:topicDetailAppbar';
export function connectTopicDetailAppbar(): TopicDetailAppbarState {
  return AppStorageV2.connect(TopicDetailAppbarState, KEY, () => new TopicDetailAppbarState())!;
}
// single-writer publish helpers mutate the holder; readers use @Monitor('appbar.savedLater')
```

Cross-component signals are **single-writer command buses**: a `connectXxxAction()` holder whose field carries a unique (often timestamped) payload; consumers react via `@Monitor`. High-frequency state (e.g. swiper visual index) is isolated into its own holder to avoid observer churn. For the row-staleness fix in `ForEach`/`LazyForEach`, follow the established `@ObservedV2`/`@Trace` row pattern (surgical per-row, not a big-bang rewrite).

## ArkTS gotchas

ArkTS is a restricted TypeScript dialect; many TS constructs **fail to compile**. Before writing `.ets`, recall: no `any`/`unknown`, no index/conditional/mapped types, no `as const`, no destructuring (params/assignment/declaration), no spread except array→rest/array-literal, no `for..in`, no `Function.bind/call/apply`, no function expressions (use arrow functions), no nested functions (use lambdas), no `this` in standalone/static functions, no dynamic/indexed field access (`obj['x']`), no `globalThis`, omit type annotations on `catch` clauses. Object literals need an inferable class/interface target. Full list: `docs/agent-guides/harmonyos-default.md`. For animations, drive via state changes, set `renderGroup(true)` on complex subtrees, and avoid animating layout props (`width`/`height`/`padding`/`margin`).

## Operating boundaries

- **Destructive writes** (thank, favorite, ignore, report, reply/topic submit) are non-idempotent. Default validation is non-destructive: open dialog → capture evidence → cancel. Real submits, when authorized, must target the V2EX sandbox node `/go/sandbox` only.
- **UI/product preservation**: don't change colors, typography, spacing, layout, wording, navigation, or interaction model while fixing a bug unless the change was explicitly requested. Remove any temporary test scaffolding (fake requests, mocks, diagnostic UI) before finalizing.
- **Login/2FA**: credentials come from local `.env.local` only — never print, commit, or paste them into prompts/chat. Don't ask the user for passwords/cookies/2FA codes.
- Shared QA device: `192.168.50.237:12345`. Bottom `HdsTabs` ignore synthetic `uitest` clicks and the soft IME won't engage there — navigate by tapping topic cards. Verify `hdc` with a real `shell echo ok` probe before trusting the connection.

## More detail

`AGENTS.md` indexes deeper agent guides under `docs/agent-guides/` (controller workflow, review/QA/integrate gates, device QA login/2FA, multi-account contract, commit messages). Other design/roadmap notes are in `docs/`. The `.cursor/rules/` files mirror the style/git/overview conventions captured above.
