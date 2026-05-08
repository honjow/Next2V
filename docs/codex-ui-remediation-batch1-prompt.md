# Codex Task: V2Next UI/Function Remediation Batch 1

Repo: `/home/gamer/git/V2Next`

You are fixing V2Next HarmonyOS app issues. Follow these documents first:

- `AGENTS.md`
- `docs/ui-guidelines.md`
- `docs/ui-remediation-standard.zh.md`
- `docs/device-lease.md` if you need the shared device

## Non-negotiable rules

1. Do not make speculative UI rewrites. Identify exact components/files before editing.
2. Do not add fake/static options, disabled placeholders, or explanatory subtitles to pretend a feature exists.
3. Prefer existing shared components/scaffolds; if you need a new pattern, create/extend a shared wrapper instead of page-local styling.
4. Commit message must be English and follow `AGENTS.md` with Why / What changed / Validation.
5. Run validation before committing:
   - `export DEVECO_SDK_HOME=/home/gamer/devtool/ohos/command-line-tools/sdk`
   - `bash dev.sh --build-only`
   - `git diff --check`
   - Device verification for any UI/interaction changes.

## Batch 1 scope: P0 functionality blockers

Fix only these functionality blockers in this run. Avoid broad settings/list restyling unless needed by the fix.

### 1. Local content counts all show 0

User-visible problem: local content project rows show numbers as 0 even when data exists.

Expected behavior:
- Counts must come from real local storage/statistics, not hardcoded defaults.
- Empty really means 0; non-empty shows actual count.
- Counts refresh when entering/re-entering the relevant page after local data changes.

Investigation hints:
- Search settings/local storage classes such as `LocalDataSettings`, `CollectionSettings`, `DraftSettings`, cache/session storage, and settings/account pages.
- Verify whether the UI reads async values too early or never updates state.

### 2. Node topic page always has 10 topics and cannot load more

User-visible problem: node page only shows 10 topics and cannot load more.

Expected behavior:
- First page loads correctly.
- Scrolling to bottom requests the next page when available.
- Loading footer/empty/end/error states are correct.
- The parser/network layer discovers or constructs the next page URL/parameter correctly.

Investigation hints:
- Search node pages/parsers/services: `V2exNodeParser`, `ApiService`, `NodeTopic`, `SavedNodesPage`, node navigation utils, loading footer/scaffold.
- Do not hardcode page counts. Use parsed next-page state or robust page increment if V2EX structure supports it.

### 3. Topic detail reply button does not open reply UI

User-visible problem: reply button in topic page does nothing / cannot open reply interface.

Expected behavior:
- Logged-in user tapping reply opens reply editor/sheet/page with correct topic id/title/context.
- Logged-out state is handled visibly and correctly.
- Back/dismiss behavior works.
- Submit flow is not required unless already implemented, but opening the UI must work.

Investigation hints:
- Search `TopicDetail`, `ReplyEditorPage`, `TopicEditorPage`, `WriteActionSettings`, router definitions and click handlers.
- Verify route name/parameter mismatch, login guard, disabled state, and build-time references.

## Required evidence in final report

Before committing, collect and include:

- Files changed.
- Root cause for each of the three issues.
- Exact validation commands and results.
- Device verification notes. Include screenshot/layout paths if captured.
- Commit hash.

## Commit

Commit the coherent Batch 1 fix only. Suggested subject examples:

```text
fix(core): restore local counts, node pagination, and reply entry
```

or split commits if changes are clearly independent. Each commit must follow `AGENTS.md`.
