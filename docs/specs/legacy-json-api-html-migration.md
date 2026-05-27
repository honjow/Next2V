# Legacy JSON API to HTML-Only Migration Plan

> **For Hermes:** Use `subagent-driven-development` if this plan is implemented later. Do not revive chat-summary assumptions; read this file and the current code first.

**Goal:** Make topic detail capable of running without V2EX legacy JSON API while preserving current rendering semantics.

**Current state:**
- List-style feeds (`hot`, `recent`, node topic lists) parse V2EX HTML topic cards and no longer fan out to `/api/topics/show.json`.
- Topic detail currently keeps `/api/topics/show.json?id={id}` as primary because its `content/content_rendered` is the stable input for V2Next's rendered-content parser.
- Topic detail HTML (`/t/{id}`) exists as fallback only.
- Replies already prefer topic-page HTML in the detail view and use legacy replies API only when HTML replies are empty.

**Architecture:** Build a dedicated topic-page parser that extracts a clean rendered-content fragment from `/t/{id}` HTML. The parser must feed the existing `MarkdownContent` rendered-HTML path; it must not convert rendered HTML back to Markdown and must not use one-shot regex that can return wrapper divs or truncated nested markup.

**Tech stack:** ArkTS parser code under `shared/src/main/ets/parser/`, existing `MarkdownContent` rendered-HTML renderer, Node `.mjs` contract tests, real V2EX HTML fixtures under `scripts/fixtures/`.

---

## Invariants

- Preserve user-visible topic detail formatting: paragraph order, links, mentions, image order, code blocks, tables, blockquotes, and line breaks.
- Preserve `MarkdownContent` boundary: rendered V2EX HTML goes to `parseRenderedHtmlToRenderAst()`; do not convert `content_rendered` back to Markdown.
- HTML-only migration must not reintroduce `/api/topics/show.json` batch fan-out for list screens.
- Legacy JSON rate-limit failures must be treated as source unavailability, not account invalidation.
- No UI redesign, spacing change, component replacement, lifecycle workaround, cache wipe, or account-session reset belongs to this migration.

## Non-goals

- Do not remove all legacy API constants in the first implementation.
- Do not rewrite `MarkdownContent` wholesale.
- Do not change reply rendering style.
- Do not change topic-card list UI.
- Do not add a user-visible setting for this migration unless a later product task explicitly asks for one.

---

## Required parser behavior

Create `shared/src/main/ets/parser/V2exTopicPageParser.ets`.

Input:

```text
full HTML from /t/{id}
```

Output:

```text
V2exTopic-like metadata:
- id
- title
- member username / id / avatar
- node name / title
- created timestamp when available
- replies count when available
- content
- content_rendered
- optional topicSupplementMarkdown if the page exposes append/supplement blocks
```

Critical `content_rendered` rule:

```text
Find .topic_content.
Find the nested .markdown_body when present.
Return markdown_body innerHTML only.
Do not return the .topic_content wrapper.
Do not return the .markdown_body wrapper.
Do not strip supported inner HTML tags.
Do not return half-closed HTML.
```

Target fragment shape:

```html
<p>body...</p>
<table>...</table>
<pre><code>...</code></pre>
```

Forbidden fragment shapes:

```html
<div class="topic_content">...</div>
<div class="markdown_body">...</div>
<div class="markdown_body"><p>half closed...
```

---

## Execution queue

### P0: Keep current production behavior

**Objective:** Preserve the current safe state until the HTML parser is proven.

**Files:**
- Keep: `shared/src/main/ets/network/ApiService.ets`
- Keep: `scripts/test_legacy_json_api_rate_limit_contract.mjs`

**Gate:**
- `getTopicById()` remains legacy JSON primary, HTML fallback.
- Lists remain HTML primary and do not call `getBatchTopics(ids)`.

**Validation:**

```bash
node scripts/test_legacy_json_api_rate_limit_contract.mjs
node scripts/test_hot_tab_web_source.mjs
PATH=/home/gamer/devtool/ohos/command-line-tools/bin:/home/gamer/devtool/ohos/command-line-tools/ohpm/bin:$PATH bash dev.sh --no-install
```

### P1: Add topic-page parser behind tests only

**Objective:** Parse `/t/{id}` topic metadata and clean rendered body without changing runtime source selection.

**Files:**
- Create: `shared/src/main/ets/parser/V2exTopicPageParser.ets`
- Create: `scripts/test_v2ex_topic_page_parser.mjs`
- Add fixtures under: `scripts/fixtures/topic_page_*.html`

**Parser requirements:**
- Use structural scanning for matching start/end tags or a small local fragment extractor.
- Regex may be used to find anchor points and attributes, but not to consume arbitrary nested body HTML.
- Extract the inner HTML of `.markdown_body` inside `.topic_content`.
- Fall back to `.topic_content` inner HTML only when `.markdown_body` is absent.
- Normalize protocol-relative URLs with existing `V2exUrlRouter` conventions.
- Decode text metadata with `HtmlEntityUtils`, but do not entity-decode the full rendered HTML fragment before handing it to `MarkdownContent` unless existing renderer contracts require it.

**Fixture classes:**
- Plain paragraph.
- Multiple paragraphs.
- Link and `@member` link.
- Embedded images.
- `pre/code` block.
- Table.
- Blockquote.
- Nested `div` inside body.
- Empty/deleted/no-permission body.

**Validation:**

```bash
node scripts/test_v2ex_topic_page_parser.mjs
```

Expected assertions:
- `content_rendered` does not contain `topic_content`.
- `content_rendered` does not contain `markdown_body` wrapper.
- `content_rendered` has balanced supported block tags.
- Text, links, image srcs, code text, table row/column counts, and block order match fixture expectations.

### P2: Add JSON-vs-HTML semantic comparison script

**Objective:** Prove HTML parser output is semantically equivalent to legacy JSON for real topics while JSON still drives UI.

**Files:**
- Create: `scripts/probe_topic_html_vs_legacy_json.mjs`
- Optionally add sanitized saved samples under `scripts/fixtures/` after redaction.

**Comparison dimensions:**
- Plain text equal after whitespace normalization.
- Link href set equal.
- Image src set equal.
- Code block text equal.
- Table row/column count equal.
- Block sequence compatible: paragraph/image/table/code/blockquote order preserved.

**Validation:**

```bash
node scripts/probe_topic_html_vs_legacy_json.mjs 1215988
node scripts/probe_topic_html_vs_legacy_json.mjs <image-topic-id>
node scripts/probe_topic_html_vs_legacy_json.mjs <table-topic-id>
node scripts/probe_topic_html_vs_legacy_json.mjs <code-topic-id>
```

**Gate:** No runtime behavior changes in this phase.

### P3: Shadow-read HTML in detail path

**Objective:** Run the parser in production diagnostics without changing displayed content.

**Files:**
- Modify: `shared/src/main/ets/network/ApiService.ets`
- Modify/add diagnostics under existing diagnostic abstractions only.

**Behavior:**
- `getTopicById()` still returns legacy JSON topic when JSON succeeds.
- When debug diagnostics are enabled, optionally parse HTML and log only non-sensitive mismatch counters.
- Do not log full HTML, rendered content, cookies, `once`, or reply body.

**Gate:**
- No user-visible output changes.
- Diagnostics redaction tests pass.

**Validation:**

```bash
node scripts/test_diagnostics_logger_contract.mjs
node scripts/test_legacy_json_api_rate_limit_contract.mjs
PATH=/home/gamer/devtool/ohos/command-line-tools/bin:/home/gamer/devtool/ohos/command-line-tools/ohpm/bin:$PATH bash dev.sh --no-install
```

### P4: Switch detail to HTML primary with JSON fallback

**Objective:** Use `/t/{id}` HTML as primary after parser contract is proven.

**Files:**
- Modify: `shared/src/main/ets/network/ApiService.ets`
- Modify: `scripts/test_legacy_json_api_rate_limit_contract.mjs`
- Add/update parser tests from P1/P2.

**Behavior:**

```text
getTopicById(topicId):
1. Fetch /t/{id} HTML.
2. Parse with V2exTopicPageParser.
3. If parser returns valid title + clean content_rendered/content + member/node metadata, return HTML topic.
4. If HTML fetch or parser contract fails, fall back to /api/topics/show.json?id={id}.
```

**Gate:**
- Existing topic detail rendering screenshots must match baseline for representative topics.
- Parser tests and build pass.
- Legacy JSON remains fallback only.

**Validation:**

```bash
node scripts/test_v2ex_topic_page_parser.mjs
node scripts/probe_topic_html_vs_legacy_json.mjs <sample-topic-ids>
node scripts/test_legacy_json_api_rate_limit_contract.mjs
PATH=/home/gamer/devtool/ohos/command-line-tools/bin:/home/gamer/devtool/ohos/command-line-tools/ohpm/bin:$PATH bash dev.sh --no-install
```

If device QA is part of that implementation lane, capture screenshots for:
- ordinary text topic;
- image topic;
- code/table topic;
- long topic with replies.

### P5: Remove topic-detail legacy JSON fallback

**Objective:** Delete `/api/topics/show.json` dependency only after HTML primary has been stable.

**Precondition:** P4 has run in real use without parser/rendering regressions.

**Files:**
- Modify: `shared/src/main/ets/network/ApiService.ets`
- Modify: `shared/src/main/ets/network/ApiConstants.ets` only if no other caller needs the endpoint.
- Update tests to assert no detail dependency remains.

**Gate:**
- No remaining production caller requires `/api/topics/show.json` for detail or list screens.
- Any remaining explicit batch-by-id feature is either removed, replaced with HTML, or documented as still legacy-dependent.

---

## Stop conditions

Stop and do not integrate if any of these occurs:

- HTML parser returns wrapper divs or unbalanced body fragments.
- Rendered body changes image/link/code/table ordering relative to legacy JSON.
- Device screenshot shows visible formatting regression.
- Parser requires clearing cookies, resetting account state, changing lifecycle, or altering UI layout.
- Implementation tries to replace `MarkdownContent` instead of feeding its rendered-HTML path.

## Current integration note

As of 2026-05-27, the safe production posture is:

```text
List pages: HTML primary.
Topic detail: legacy JSON primary, HTML fallback.
Replies: topic-page HTML primary in detail view, legacy replies fallback only when needed.
Member profile: HTML primary, legacy JSON fallback.
```
