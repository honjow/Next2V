# Codex Task: V2Next UI/Function Remediation Batch 2

Repo: `/home/gamer/git/V2Next`

Follow these documents first:

- `AGENTS.md`
- `docs/ui-guidelines.md`
- `docs/ui-remediation-standard.zh.md`
- `docs/device-lease.md` if using the shared device

## Non-negotiable rules

1. Identify exact files/components before editing. Do not touch unrelated settings IA in this batch.
2. Prefer existing shared components/scaffolds: `SecondaryListScaffold`, `PullRefreshListScaffold`, `ConciseListRow`, `GroupedListSection`, `ListDivider`, `EmptyState`, etc.
3. Do not add fake subtitles, fake routes, or static explanatory options.
4. Preserve native/HDS patterns. Page-level secondary actions belong in appbar menu, not large body buttons.
5. Validate on device for all changed screens and commit in English following `AGENTS.md`.

## Batch 2 scope: list-page style and appbar structure

Fix only these P1 structural issues in this run.

### 1. Local list pages use independent styling instead of existing list-page style

User-visible problem:
- 最近浏览、稍后读、本地内容 related list pages look independent and inconsistent with existing secondary list pages.

Expected behavior:
- Recently viewed / saved topics / saved nodes / my local content pages use the app's existing list scaffolds and row patterns.
- Empty, loading, divider, padding, safe-area bottom, title/appbar behavior are consistent.
- Do not hand-style new one-off rows unless no shared row can represent the content.

Likely files to inspect:
- `entry/src/main/ets/pages/ViewedTopicsPage.ets`
- `entry/src/main/ets/pages/SavedTopicsPage.ets`
- `entry/src/main/ets/pages/SavedNodesPage.ets`
- `entry/src/main/ets/pages/MyTopicsPage.ets`
- `entry/src/main/ets/pages/MyNodesPage.ets`
- shared list components under `shared/src/main/ets/components/`

### 2. Node topic page should put node name/subtitle in appbar

User-visible problem:
- Node page currently shows node name and subtitle information in the page body; this should be appbar-level identity.

Expected behavior:
- NodeTopic page appbar shows the node name and meaningful subtitle/header/metadata when available.
- The topic list body starts with topic content, not a repeated big title block.
- Scrolling/loading/footer behavior from Batch 1 must remain intact.

Likely files to inspect:
- `feature/node/src/main/ets/pages/NodeTopicPage.ets`
- `feature/node/src/main/ets/viewmodel/NodeViewModel.ets`
- shared appbar/scaffold components if any.

### 3. User page follow/block actions should move to appbar menu

User-visible problem:
- 用户页的关注、屏蔽按钮 are currently prominent body controls; they should be page-level secondary actions in appbar menu.

Expected behavior:
- Follow/block actions appear in an appbar menu or equivalent native/HDS overflow action.
- Page body no longer has visually loud follow/block buttons.
- Logged-in/permission/loading states are handled clearly.
- Existing follow/block behavior must still work; if not implemented, do not fake it—make the menu item reflect only real available actions.

Likely files to inspect:
- `feature/user/src/main/ets/pages/UserProfilePage.ets` or matching user page files.
- related services/settings for follow/block actions.

## Required validation

Run:

```bash
export DEVECO_SDK_HOME=/home/gamer/devtool/ohos/command-line-tools/sdk
bash dev.sh --build-only
git diff --check
```

Device verification on `192.168.50.237:12345` with device lease:

- Recently viewed list page: empty or populated state.
- Saved/read-later list page: empty or populated state.
- NodeTopic page: appbar contains node identity; list body no longer repeats the old header block; load-more still works if practical to verify.
- UserProfile page: menu opened showing follow/block actions or correctly omitting unavailable fake actions.

Capture screenshot or layout dump paths and include them in the final report/commit validation.

## Required final report

Before finishing, report:

- Files changed.
- Which shared components/scaffolds each affected page now uses.
- Root cause of each inconsistency.
- Exact validation commands/results.
- Device verification notes and screenshot/layout paths.
- Commit hash.

## Commit

Commit Batch 2 only. Suggested subject:

```text
fix(ui): align list pages and page actions with shared structure
```

Use the full `AGENTS.md` body with Why / What changed / Validation.
