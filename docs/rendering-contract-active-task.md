# Rendering contract active task

Workspace: `/home/gamer/v2next-worktrees/rendering-contract`
Branch: `lane/rendering-contract`

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
  - non-image HTML tables remain the narrow legacy exception because the existing renderer consumes Markdown table tokens.

Canonical block kinds:

- `paragraph`
- `heading`
- `list`
- `blockquote`
- `code`
- `imageBlock`
- `imageTable`

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
| inlineImage | role from source structure/Markdown inline semantics; measured size only affects rendered dimensions |
| imageTable | preserve all image URLs in source order with optional caption labels |

## Reading text scale

The existing persisted/AppStorage key remains `readingFontSize` for compatibility, but it is now a scale source rather than the semantic body token. `ReadingSettings.normalizeTextScale(...)` accepts both new scale values and legacy 12..18 font-size values; legacy values are mapped as `oldFontSize / 14` and clamped to the same range.

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

It also asserts static source boundaries:

- explicit Render block/inline kinds and style contract table exist;
- both adapter functions exist;
- rendered HTML process path does not call `renderedHtmlToMarkdown`;
- no intrinsic big/small image role classifier is introduced;
- `isImageTokenAloneOnInlineLine(...)` only demotes an image to standalone/block when both `before.trim().length === 0` and `after.trim().length === 0` on the same source line;
- h1-h6 have independent fixed base typography tokens; no heading contract uses `bodyFontSize() + N` or `min(bodyFontSize()+N, ...)`, and h2-h6 are not collapsed into the body token.

## Validation status

Required static/script validation for this implementation is recorded under:

`.hermes-artifacts/rendering-contract-impl/test-logs/`

Typography/scale fix validation is recorded under:

`.hermes-artifacts/rendering-contract-typography-fix/test-logs/`

Implementation evidence paths expected by reviewer exist:

- `.hermes-artifacts/rendering-contract-impl/summary.md`
- `.hermes-artifacts/rendering-contract-impl/diff-summary.md`
- `.hermes-artifacts/rendering-contract-impl/test-logs/`

No Harmony build, install, device control, screenshots, or layout dumps are claimed because this task explicitly forbids those actions.
