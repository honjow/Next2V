# Rendering contract active task

Workspace: `/home/gamer/v2next-worktrees/rendering-image-flow`
Branch: `lane/rendering-image-flow`

## Scope

Only detail-page body content rendering is in scope:

- `shared/src/main/ets/components/MarkdownContent.ets`
- `scripts/test_v2ex_rendered_html_tokens.mjs`
- `shared/src/main/ets/settings/ReadingSettings.ets` (reading text scale compatibility model)
- `feature/settings/src/main/ets/pages/ReadingSettingsPage.ets` (font-size control copy/value mapping)
- `scripts/test_render_ast_contract.mjs`
- this document

Out of scope: titlebar/appbar, navigation, home feed, bottom tabs, unrelated UI, build/install/device validation.

## Product boundary

V2Next topic/reply body rendering must expose one semantic contract for both source paths:

1. Markdown fallback is parsed by the Markdown adapter only.
2. V2EX `content_rendered` HTML is parsed by the rendered-HTML adapter directly.
3. Both adapters normalize to the same V2Next Render AST/token compatibility shape before rendering.
4. Rendered HTML main path must not use a generic HTML -> Markdown -> lexer pipeline.
5. Image inline/block role is decided by source structure / Markdown semantics, not intrinsic big/small image classification.
6. Member links remain semantic links and only the redundant preceding literal `@` is removed.
7. Adjacent duplicate linked images are preserved in source order; no dedupe or concatenation.

## Adapter contract

Transitional implementation remains compatible with `@lidary/markdown` token objects for the renderer, but the adapter boundary is explicit:

- `parseMarkdownToRenderAst(source, sizeRecords)`:
  - only Markdown fallback enters `lexer(...)`;
  - output is tagged `rawSourceKind: "markdown"`;
  - later normalization passes retype legacy block tokens to V2Next-owned custom render blocks.
- `parseRenderedHtmlToRenderAst(contentRendered, sizeRecords)`:
  - direct HTML block/inline tokenization via `renderedHtmlToTokens(...)`;
  - output is tagged `rawSourceKind: "renderedHtml"`;
  - ordinary HTML tables are parsed directly into V2Next-owned `table` render tokens; only image tables keep the `imageTable` special case.

Canonical block kinds:

- `paragraph`
- `heading`
- `list`
- `blockquote`
- `code`
- `imageBlock`
- `imageTable`
- `table`

Canonical inline kinds:

- `text`
- `link`
- `strong`
- `em`
- `codespan`
- `image`
- `break`

## Explicit style contract

The source now carries `RENDER_STYLE_CONTRACT_TABLE` as a testable contract. Current rows:

| Semantic | Contract |
| --- | --- |
| paragraph | fixed base `14/20` × `readingTextScale`, `color=TEXT_PRIMARY` |
| h1 | fixed base `22/28` × `readingTextScale`, `weight=Bold`, `color=TEXT_PRIMARY` |
| h2 | fixed base `20/26` × `readingTextScale`, `weight=Bold`, `color=TEXT_PRIMARY` |
| h3 | fixed base `18/24` × `readingTextScale`, `weight=Medium`, `color=TEXT_PRIMARY` |
| h4 | fixed base `16/22` × `readingTextScale`, `weight=Medium`, `color=TEXT_PRIMARY` |
| h5 | fixed base `15/21` × `readingTextScale`, `weight=Medium`, `color=TEXT_PRIMARY` |
| h6 | fixed base `14/20` × `readingTextScale`, `weight=Medium`, `color=TEXT_PRIMARY` |
| list | marker/content use fixed body `14/20` × `readingTextScale`; unordered marker bold secondary; ordered marker primary |
| blockquote | rail height is scaled body line height (not `100%`), background `_quoteBackground`, child rendering shared |
| code/pre | fixed code base `12/18` × `readingTextScale`, mono font, `_codeBackground` |
| link | `TEXT_LINK`; non-member underline; member link callback/no forced plain text |
| strong | inherited/body size, bold, primary |
| em | inherited/body size, italic, primary |
| codespan | inherited/body size, mono, primary, `BG_SUB` background |
| imageBlock | role from source structure/Markdown block semantics; dimensions only size rendering |
| inlineImage | role from source structure/Markdown inline semantics; display dimensions come from actual image dimensions and the measured paragraph/content available width; missing size records use a neutral pending load sentinel until `ImageSpan.onComplete` reports intrinsic dimensions |
| imageTable | preserve all image URLs in source order with optional caption labels |
| table | ordinary data tables use fixed body `14/20` × `readingTextScale`; header Medium/Bold, body Regular; horizontal scroll with content-estimated/clamped per-column widths, min/max cell width, row/header separation, and visible vertical column dividers |

## Image sizing contract

Image inline/block role is a source-structure decision only:

- Rendered HTML `<p><img ...>text</p>` and Markdown same-line image+text remain inline in token order.
- Standalone image lines/blocks remain block images through existing source-line checks.
- The renderer must not introduce an intrinsic big/small/icon classifier to choose inline vs block.

Display size is a separate rendering concern:

- Inline image size uses the recorded actual `widthPx`/`heightPx` and preserves aspect ratio.
- `MarkdownParagraph` records the paragraph/Text available width with `onAreaChange` and passes that measured width into `_inlineImageRenderSize(...)`; table cells use their cell width and top-level heading fallback paths use the component width state. This avoids a global fixed "content width" assumption.
- A viewport safety max height (`INLINE_IMAGE_VIEWPORT_SAFE_MAX_HEIGHT`, currently `1200`) prevents pathological tall draw regions while avoiding the old fixed `320x240` inline cap.
- Missing size records must not fall back to font-size icons, `24..40`, or a content-width `16:9` placeholder. They use `INLINE_IMAGE_PENDING_SIZE = 1` as a pending load sentinel whose only purpose is to trigger `ImageSpan` loading and `onComplete` intrinsic size reporting. Existing `reportInlineImageComplete` / size-record refresh can replace it with actual aspect-ratio sizing on later render.
- If no content width has been measured yet, inline images (even with a size record) stay at the same pending sentinel rather than drawing a huge region; once width is measured, recorded dimensions are clamped to that real available width.
- Emojis/icons can still stay inline; if their actual dimensions are naturally small, they render small because of actual size, not because of a separate inline-small path.

Forbidden strategies: `INLINE_IMAGE_FALLBACK_MIN_SIZE/MAX_SIZE`, `_inlineImageSize(fontSize)`, fixed `INLINE_IMAGE_SPAN_MAX_WIDTH=320` / `MAX_HEIGHT=240`, or any `inlineSmall` / `blockLarge` role classifier.

## Reading text scale

The persisted/AppStorage key is `readingTextScale`. `ReadingSettings.normalizeTextScale(...)` treats stored values as scale values only; legacy font-size values are intentionally not migrated in this schema cleanup.

Rendering components must apply this single scale to fixed semantic tokens. Headings must not be defined as `bodyFontSize() + N`, `min(bodyFontSize()+N, ...)`, or by collapsing h2-h6 to body configuration. Line heights are fixed token line heights multiplied by the same scale.

## Regression coverage

`scripts/test_render_ast_contract.mjs` is a deterministic JS mirror plus static/source-boundary validation. It does not import or execute the ArkTS production adapter at runtime, so it must not be described as production adapter runtime equivalence. Its production binding is limited to source assertions for the adapter boundary and image-role condition.

It covers semantic mirror equivalence for:

- h1-h6
- paragraph
- unordered and ordered lists
- blockquote
- code/pre
- link
- strong/em/codespan
- mixed text + image source order
- image-first mixed text, e.g. `<p><img src="..."> after</p>`, which must remain inline because same-line text exists after the image
- adjacent duplicate linked images
- member link without literal preceding `@`
- ordinary HTML and Markdown GFM tables normalize into the same `table` render-token shape, preserving inline strong/link/codespan semantics and avoiding Markdown pipe/separator fallback

It also asserts static source boundaries:

- explicit Render block/inline kinds and style contract table exist;
- both adapter functions exist;
- rendered HTML process path does not call `renderedHtmlToMarkdown`;
- ordinary HTML table handling does not call `lexer(convertHtmlTable(raw))`, and `RenderProcessedToken` has a `token.type === "table"` renderer branch;
- ordinary table layout does not use the old fixed `116vp` per-cell strategy or runtime natural `onSizeChange` column measurement; each column is deterministically estimated from header/body text display units with min/max clamps and horizontal padding, table width is the sum of estimated columns, ragged rows pad to `columnCount()`, cells draw explicit right borders for vertical separators, and parsed left/center/right alignment uses Start fallback;
- no intrinsic big/small image role classifier is introduced;
- inline image display size uses actual recorded width/height + aspect ratio under measured paragraph/content available width, uses a `1x1` pending load sentinel before intrinsic dimensions/width are available, does not use the old `24..40` font-size fallback, fixed `320x240` inline span cap, or a fixed `360` content-width placeholder, and preserves `<p><img ...>效果已经不是当下 Agent 的主要矛盾</p>` token order;
- `isImageTokenAloneOnInlineLine(...)` only demotes an image to standalone/block when both `before.trim().length === 0` and `after.trim().length === 0` on the same source line;
- h1-h6 have independent fixed base typography tokens; no heading contract uses `bodyFontSize() + N` or `min(bodyFontSize()+N, ...)`, and h2-h6 are not collapsed into the body token.

## Validation status

Required static/script validation for this implementation is recorded under:

`.hermes-artifacts/rendering-contract-impl/test-logs/`

Typography/scale fix validation is recorded under:

`.hermes-artifacts/rendering-contract-typography-fix/test-logs/`

Table layout fix validation is recorded under:

`.hermes-artifacts/rendering-table-layout-fix2/test-logs/`

Image-flow sizing fix1 validation is recorded under:

`.hermes-artifacts/rendering-image-flow-fix1/test-logs/`

Earlier image-flow sizing implementation validation was recorded under:

`.hermes-artifacts/rendering-image-flow-impl/test-logs/`

Implementation evidence paths expected by reviewer exist:

- `.hermes-artifacts/rendering-image-flow-impl/summary.md`
- `.hermes-artifacts/rendering-image-flow-impl/test-logs/`

Prior implementation evidence paths:

- `.hermes-artifacts/rendering-contract-impl/summary.md`
- `.hermes-artifacts/rendering-contract-impl/diff-summary.md`
- `.hermes-artifacts/rendering-contract-impl/test-logs/`

No Harmony build, install, device control, screenshots, or layout dumps are claimed because this task explicitly forbids those actions.
