# i18n ResourceManager Migration Execution Plan

This lane migrates AppStrings from the generated `StringMap` source of truth to
HarmonyOS `ResourceManager.getOverrideResourceManager`, while keeping each step
small enough to build and device-test.

## Phase 1: ResourceManager Baseline

- Add an override `ResourceManager` holder inside `AppStrings`.
- Let `LanguageSettings.apply()` hand the normalized app language mode to
  `AppStrings`.
- Make `AppStrings.text()` prefer the override manager, then fall back to the
  existing `StringMap` and default resource manager.
- Convert one representative direct `$r()` UI string, About tagline, to
  `AppStrings.text()` so the path is exercised without temporary probe UI.
- Keep `StringMap.ets`, `AppStrings.R_*`, and existing call sites intact.

Validation:

- `python3 scripts/static_i18n_contracts.py`
- `node scripts/test_v1_decorator_inventory_contract.mjs`
- `git diff --check`
- Build/install/device QA after static gates pass.

## Phase 2: Mechanical Constant Replacement

- Generate a mapping from `AppStrings.R_FOO` declarations to
  `$r('app.string.foo')`.
- Replace `AppStrings.R_*` call sites in small module batches.
- Prefer preserving `ResourceStr` return types where existing components expect
  resources.
- Keep `AppStrings.text()` and `format()` behavior unchanged.

Current batch:

- Migrated the Settings page language row, visible settings row titles,
  settings dropdown labels, and reading preview controls to direct `$r(...)`
  resources.
- Locked language target names to fixed autonyms across all locales:
  `简体中文`, `繁體中文（香港）`, `繁體中文（台灣）`, `English`, `日本語`, and
  `한국어`. `Follow system` remains localized because it is an action option.
- Migrated the Image Upload settings subpage's visible `ResourceStr` labels,
  hints, placeholders, provider rows, and save/link controls to direct `$r(...)`
  resources.
- Migrated the visible direct `ResourceStr` labels in the Cloud Sync, Home
  Nodes, API Domain, and Diagnostics Log settings subpages to direct `$r(...)`
  resources. Runtime status, validation, toast, and error strings remain on
  `AppStrings.text()` for the runtime-string batch.
- Migrated the visible direct `ResourceStr` labels, profile editor field
  labels, protocol rows, and action buttons in the Network Proxy settings
  subpage to direct `$r(...)` resources.
- Migrated the visible direct `ResourceStr` labels in the Storage settings
  subpage, including offline-cache rows, backup sheet titles/fields/buttons,
  and debug QA seed row titles, to direct `$r(...)` resources.
- Migrated the `ThemeColorSettings` option/label holder to direct `$r(...)`
  resources so theme color menu labels no longer depend on `AppStrings.R_*`.
- Migrated settings option/label holders for theme, avatar appearance, reply
  display, reply card style, and reply action alignment to direct `$r(...)`
  resources so those menu summaries no longer depend on `AppStrings.R_*`.
- Migrated Network Proxy runtime test status, profile validation, toasts,
  confirmation dialog strings, formatted summaries, mode labels, and default
  profile naming to direct `$r(...)` resources while preserving
  `AppStrings.text()` override resolution.
- Migrated API domain runtime validation/toast strings in
  `DomainSettingsPage` and `DomainSettingsCoordinator` to direct `$r(...)`
  resources while preserving `AppStrings.text()` override resolution.
- Migrated Home Node settings validation toasts to direct `$r(...)` resources,
  removing the page's remaining `AppStrings.R_*` dependency.
- Migrated Settings and Image Upload common saved/save-failed toasts to direct
  `$r(...)` resources while preserving `AppStrings.text()` override resolution.
- Migrated Cloud Sync status and last-sync formatted strings to direct `$r(...)`
  resources while preserving `AppStrings.text()` override resolution.
- Migrated Diagnostics log runtime fallbacks, share failure messages, launch
  record toast, unknown-time fallback, and export no-log fallback to direct
  `$r(...)` resources while preserving `AppStrings.text()` override resolution.
- Migrated Storage settings runtime dialog copy, cache subtitles, backup
  success/error/preview messages, and backup password validation in
  `StorageSettingsPage` and `StorageSettingsCoordinator` to direct `$r(...)`
  resources while preserving `AppStrings.text()` override resolution.
- Migrated `ReadingSettingsPage` reset dialog copy and all remaining
  `shared/src/main/ets/settings` runtime error strings to direct `$r(...)`
  resources. The i18n contract now asserts `feature/settings/src/main/ets` and
  `shared/src/main/ets/settings` contain no `AppStrings.R_*` references.
- Migrated centralized network `ApiError` message resources to direct `$r(...)`
  resources while preserving stable error codes, English fallbacks, and
  formatted context handling.
- Migrated Account dashboard coordinator/page labels, dialog buttons, 2FA
  messages, token info fallback, and daily check-in toasts to direct `$r(...)`
  resources while preserving account/session state behavior.
- Migrated the `feature/user` profile pages, profile components, tab label
  coordinator, user-mark sheet, and all-topics/all-replies empty/error states
  to direct `$r(...)` resources; the contract now asserts
  `feature/user/src/main/ets` contains no `AppStrings.R_*` references.
- Migrated the main index route/title-bar batch, including destination titles,
  tab labels, title-bar menu labels, search title-bar copy, topic action labels,
  and account web-view titles, to direct `$r(...)` resources.
- Migrated `feature/detail` topic detail, reply composer, reply context,
  markdown placeholder, preload/loading, and topic/reply action resources to
  direct `$r(...)` resources; the contract now asserts
  `feature/detail/src/main/ets` contains no `AppStrings.R_*` references.
- Completed the remaining business call-site sweep across entry
  pages/components/models, `feature/node`, and shared components/parsers,
  services, and utils. `entry/src/main/ets`, `feature/`, and
  `shared/src/main/ets` excluding i18n definitions now contain no
  `AppStrings.R_*` call sites. Business code uses direct `$r(...)` resources.

Validation:

- Existing i18n source-of-truth and locale matrix contracts.
- Business ETS no-`AppStrings.R_*` contract, excluding i18n definitions.
- Batch-level ArkTS build after each broad replacement.

## Phase 3: Remove Generated StringMap

- Removed the `StringMap.ets` import and deleted the `idToName`, `mapReady`,
  `buildIdToNameMap()`, and `currentLanguageMode()` fallback path from
  `AppStrings`.
- Deleted the generated `shared/src/main/ets/i18n/StringMap.ets` table and
  `scripts/generate_string_map.py`.
- Updated i18n contracts so resource JSON files are the source of truth and
  `AppStrings.text()` is required to resolve through override/default
  `ResourceManager`.
- Ensured production code has no `StringMap` import.

Validation:

- Full static i18n suite.
- V1 decorator inventory.
- Build.
- Device QA: explicit `zh-Hans`, `en-US`, and follow-system smoke paths.

## Phase 4: Cleanup

- Re-checked production `entry/feature/shared` ETS call sites and confirmed no
  business code depends on `AppStrings.R_*`.
- Removed the 661 transitional `AppStrings.R_*` resource aliases from
  `AppStrings.ets`; the class now only owns init, override/default
  ResourceManager resolution, `format()`, and language mode mapping.
- Locked focused i18n contracts so `StringMap`, the generator script, and
  `AppStrings.R_*` aliases cannot be reintroduced.
- Keep `AppStrings.format()` and `{0}` templates unless a separate migration is
  explicitly approved.

Remaining cleanup outside this lane:

- Broad CJK gates now distinguish ordinary UI copy from comments, V2EX
  server/parser grammar, and sticker `[name]` content tokens. Sticker token
  values intentionally remain stable because they are inserted into drafts and
  expanded back to URLs at submit time.
