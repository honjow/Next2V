# Codex Task: V2Next Remediation Correction After Independent Review

Repo: `/home/gamer/git/V2Next`

This is a correction task. The previous Batch 2 commit is not fully correct. Do not continue Batch 3. Fix only the issues below, then validate and commit.

Follow:
- `AGENTS.md`
- `docs/ui-guidelines.md`
- `docs/ui-remediation-standard.zh.md`

## User corrections to treat as authoritative

1. 最近浏览 should use the same style as the normal topic list, not the newly simplified row/card style.
2. 最近浏览 currently still cannot jump/open topic from the list.
3. The Account/My page entry number for 最近浏览 still shows 0 when data exists.
4. Node page main title/subtitle are duplicated.
5. The node page suffix topic count currently reflects the current loaded array length; that count is meaningless and should not be shown as a live topic-count badge/title value.

## Scope

Fix only:
- 最近浏览 entry count refresh/source.
- 最近浏览 list row style and click/navigation behavior.
- NodeTopic appbar title/subtitle duplication and meaningless loaded-list count.
- Clean up untracked verification artifacts if they are just temporary output, or move them outside the repo. Do not commit `artifacts/`.

Do not change settings IA in this task. Do not restyle unrelated saved/read-later pages unless a tiny shared helper change is necessary.

## Expected behavior

### Recently viewed entry count

- In `AccountPage` / My local section, 最近浏览 count must reflect `CollectionSettings.loadViewedTopics()` result.
- The count must update after a topic is viewed and after returning/re-entering Account/My.
- If `LOCAL_DATA_UPDATED_AT` or another refresh key is intended to drive this, ensure viewed-topic writes publish it. Do not only update saved topics/drafts.

### Recently viewed list

- Use the same visual row style as normal topic lists where practical, e.g. `TopicCard` or the shared topic-list component pattern used by feed/node/user topic lists.
- Do not wrap each item in its own `GroupedListSection` card.
- Preserve useful metadata, especially viewed time if it was previously shown.
- Tapping a recently viewed item must navigate to `TopicDetail` with the correct topic id. Verify the click target actually works on device/layout; do not assume because `.onClick` exists.

### NodeTopic appbar

- Main title should be the node display title only, e.g. `Android`.
- Subtitle may be node name/header/description if available, e.g. `android` or a meaningful header.
- Do not duplicate `Android · android` in both main title and subtitle.
- Do not show `20 主题` or any count derived from the currently loaded list array length. It is not the total node topic count and is misleading.
- Preserve Batch 1 pagination/load-more behavior.

## Independent review findings to address

- `entry/src/main/ets/pages/Index.ets` currently builds `visibleTitle = `${title} · ${subTitle}`` and also passes `subTitle`, causing duplication.
- `NodeTopicPage` / `NodeViewModel` publishes topic counts derived from loaded arrays; do not use that as node identity count.
- `ViewedTopicsPage` currently uses `GroupedListSection` per row and `ConciseListRow`, which is not the normal topic list style.
- `CollectionSettings.writeViewedTopics()` may not publish `LOCAL_DATA_UPDATED_AT`; check and fix so AccountPage count refreshes.
- `artifacts/` is untracked in repo and should not remain in the worktree after this correction.

## Required validation

Run:

```bash
export DEVECO_SDK_HOME=/home/gamer/devtool/ohos/command-line-tools/sdk
export PATH=/home/gamer/devtool/ohos/command-line-tools/bin:$PATH
bash dev.sh --build-only
git diff --check
```

Device validation on `192.168.50.237:12345` using device lease if available:

- Create/ensure at least one recently viewed topic by opening a topic.
- Go to My/Account page: 最近浏览 count must be non-zero and match the local list count.
- Open 最近浏览 from the entry: list should use normal topic-list style.
- Tap a 最近浏览 row: TopicDetail opens for that topic.
- Open NodeTopic page: appbar main/subtitle must not duplicate and must not show loaded-list count as “N 主题”.

Capture screenshot/layout paths, preferably outside the repo under `/tmp/v2next-correction-verify-*`.

## Required final report

Include:
- Files changed.
- Root cause of each fixed issue.
- Validation commands/results.
- Device verification notes and artifact paths.
- Commit hash.

## Commit

Commit this correction only. Suggested subject:

```text
fix(ui): correct recently viewed list and node title state
```

Use `AGENTS.md` format with Why / What changed / Validation.
