# V2Next UI Guidelines

Date: 2026-05-07

This document is a working contract for UI implementation in V2Next. It exists
to stop page-by-page visual patching. When this document conflicts with a local
one-off style, this document wins.

## Core Rules

1. HDS first. Check Harmony Design System / `@kit.UIDesignKit` before writing a
   custom ArkUI surface.
2. If HDS cannot be used, create a shared local wrapper. Do not scatter raw
   `TextInput`, `Button`, `Text` pseudo-buttons, ad hoc borders, or ad hoc
   shadows across pages.
3. Same role, same component. Controls in the same row and role must use the
   same builder/component, height, font size, enabled state, and vertical
   alignment.
4. Do not make UI changes by only satisfying the latest complaint. First classify
   the control role, then apply the role's rule.
5. Screenshots are required for affected pages before committing UI changes.

## Forbidden Patterns

- Do not mix `Text` pseudo-buttons and `Button` components in the same action
  row.
- Do not hand-style `TextInput` directly in feature pages. Use an HDS input
  component or a shared app input wrapper.
- Do not use generic rounded rectangles for selectable filters, segmented
  options, or compact mode switches.
- Do not confuse chip and button roles. Harmony/HDS action buttons may be
  capsule-shaped by default; the problem to avoid is mixing action-button size,
  chip size, and pseudo-button implementation in the same surface.
- Do not fix a single page by copying numbers into that page. Add or use a
  shared wrapper when the pattern can appear elsewhere.
- Do not use custom overlays for modal/sheet behavior when a system/HDS sheet,
  dialog, popup, or menu can provide animation, focus, dismissal, and Back
  handling.
- Do not commit UI work after build-only validation. Visual review must use
  device screenshots.

## Control Roles

### Search And Text Inputs

Preferred implementation:

- HDS search/input component when available.
- Otherwise a shared app wrapper such as `AppSearchField` or `AppTextField`.

Rules:

- Feature pages must not inline `TextInput` styling.
- Input fields must be visually distinct from the page background.
- Search input and form input are different roles. Do not make a search field
  look like a mode chip or command button.
- Text input height, content padding, placeholder color, focus treatment, and
  disabled state must come from the shared wrapper.

### Selection Chips

Use for:

- Search source choices such as local/node/remote/web.
- Sort choices.
- Time range choices.
- Result type filters.

Rules:

- Use compact capsule chips.
- All chips in the same group must have the same height and typography.
- Selected and unselected states must be clear without changing layout size.
- Chips are not primary action buttons.

### Action Buttons

Use for:

- Apply, submit, retry, save, clear, open, login, and other commands.

Rules:

- Same action row, same component. For example, `Clear` and `Apply` in a sheet
  must both use the same action-button wrapper, not `Text` plus `Button`.
- Primary and secondary actions may differ by color/weight, not by accidental
  height, baseline, or component internals.
- Do not decide shape locally. Use HDS button defaults when available. If the
  default is capsule, keep it; enforce consistent height, typography, width, and
  state instead of fighting the system shape.
- Disabled primary actions must not dominate the page. If there is no valid
  action, consider hiding the action, using a less prominent disabled state, or
  moving the validation feedback closer to the input.

### Menus

Use for:

- Page actions in app bars.
- Detail-page operations.
- Secondary commands that do not deserve visible buttons.

Rules:

- Prefer HDS popup/menu button patterns.
- Use system symbol icons that match the action. Do not use a document icon for
  filtering, or a generic icon when a clear action icon exists.
- Avoid visible text buttons in app bars when an icon/menu pattern is available.

### Sheets And Modals

Use for:

- Filters, action pickers, short forms, confirmation flows, and transient
  secondary surfaces.

Rules:

- Prefer system/HDS sheet/dialog APIs such as `bindSheet` over custom overlay
  stacks.
- Back must dismiss the top sheet/modal before leaving the page.
- The sheet content builder must not use percentage height with
  `SheetSize.FIT_CONTENT`.
- Do not set large fixed heights unless the design requires a scrollable,
  multi-section sheet. A fixed height must be justified and screenshot-verified.
- Capture screenshots after the opening animation settles. Do not judge layout
  from a transition frame.

### Lists And Rows

Use for:

- Settings, account entries, local collections, notifications, search results,
  and topic/reply lists.

Rules:

- Prefer shared list rows/scaffolds for secondary pages.
- Repeated rows should have consistent horizontal padding, title size, metadata
  size, divider behavior, and safe-area bottom spacing.
- Avoid redundant subtitles. Keep secondary text only for state, risk, or hidden
  behavior.

## Page-Level Rules

### Search

Search must use shared/HDS-style primitives for:

- Search field.
- Source selection chips.
- Filter sheet scaffold.
- Filter chips.
- Sheet action row.

The search page must not directly style raw `TextInput` or create one-off action
rows. Before modifying Search UI, inspect the whole page in these states:

- Initial/history state.
- Result list state.
- Filter sheet open.
- Back after filter sheet open.

### Secondary Pages

Settings, Login, TopicEditor, ReplyEditor, UserProfile, NodeTopic, local
collection pages, and Search should feel like the same product family. Compare
new secondary-page work against TopicDetail and Settings before committing.

### My

My page should be concise. Use account/profile entry blocks and app-bar menus
instead of duplicate settings entries or explanatory rows.

## Required Implementation Flow

Before editing UI:

1. Identify the control roles being changed.
2. Check HDS usage and existing shared wrappers.
3. If no wrapper exists, create or extend a shared wrapper first.
4. Replace page-local styling with the wrapper.

Before committing UI:

1. Build with `bash dev.sh --build-only`.
2. Install to `192.168.50.237:12345` when behavior or visual layout changed.
3. Capture stable screenshots for all affected states.
4. Check that same-row controls have the same height and alignment.
5. Check Back behavior for sheets, dialogs, and menus.
6. Run `git diff --check`.
7. Review the actual diff and commit only the coherent change.

## Review Questions

Every UI diff should be able to answer:

- Which HDS component or shared wrapper is used?
- If raw ArkUI is used, why is it not wrapped?
- Are same-role controls implemented by the same component?
- Does the screenshot show consistent size, spacing, and state?
- Did this change remove page-local styling instead of adding more?
