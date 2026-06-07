#!/usr/bin/env node
// Static contract for the runtime/settings AppStorage -> V2 holder batch.
//
// Pins the durable V2 wiring that retired the direct AppStorage.get reads (and MotionHandStateService's
// direct AppStorage.setOrCreate writes) for:
//   - reading restore-position           -> ReadingSettingsState.restorePosition
//   - reply-display mode                  -> ReplyDisplayState.mode
//   - theme mode + cached system color    -> ThemeDisplayState.mode / systemColorMode
//   - theme color                         -> ThemeColorState.color
//   - app language mode                   -> LanguageState.mode
//   - reply-action alignment + holding    -> MotionReplyAlignmentState.alignmentMode / holdingHandSupported
//
// Each holder is seeded at its settings apply()/save() chokepoint (which still projects the legacy
// AppStorage key via setAppStorageValue / applyDescriptorValue and keeps preferences persistence), and
// every migrated reader now reads the holder instead of AppStorage. No restart/reload/manual-refresh lane.
//
// Run: node scripts/test_appstorage_runtime_holders_contract.mjs
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
const repo = join(here, '..');
const read = (rel) => readFileSync(join(repo, rel), 'utf8');
const strip = (s) => s.replace(/\/\*[\s\S]*?\*\//g, '').replace(/\/\/.*$/gm, '');

let failures = 0;
const ok = (m) => console.log(`ok   ${m}`);
const fail = (m) => { console.error(`FAIL ${m}`); failures++; };
const must = (cond, m) => (cond ? ok(m) : fail(m));
const hasNoAppStorage = (rel) => must(!/AppStorage\s*\./.test(strip(read(rel))), `${rel}: no direct AppStorage access`);

// 1) Holder shapes + connect exports -----------------------------------------------------------
{
  const reply = strip(read('shared/src/main/ets/state/ReplyDisplayState.ets'));
  must(/@ObservedV2\b/.test(reply) && /@Trace\s+mode\b/.test(reply) && /export function connectReplyDisplay\(/.test(reply),
    'ReplyDisplayState: @ObservedV2 @Trace mode + connectReplyDisplay()');

  const lang = strip(read('shared/src/main/ets/state/LanguageState.ets'));
  must(/@ObservedV2\b/.test(lang) && /@Trace\s+mode\b/.test(lang) && /export function connectLanguageState\(/.test(lang),
    'LanguageState: @ObservedV2 @Trace mode + connectLanguageState()');

  const motion = strip(read('shared/src/main/ets/state/MotionReplyAlignmentState.ets'));
  must(/@ObservedV2\b/.test(motion) && /@Trace\s+alignmentMode\b/.test(motion) && /@Trace\s+holdingHandSupported\b/.test(motion)
    && /export function connectMotionReplyAlignment\(/.test(motion),
    'MotionReplyAlignmentState: @ObservedV2 @Trace alignmentMode/holdingHandSupported + connectMotionReplyAlignment()');

  const reading = strip(read('shared/src/main/ets/state/ReadingSettingsState.ets'));
  must(/@Trace\s+restorePosition\b/.test(reading), 'ReadingSettingsState: @Trace restorePosition added');
  must(/@Trace\s+restorePosition:\s*boolean\s*=\s*true/.test(reading), 'ReadingSettingsState: restorePosition defaults on');

  const theme = strip(read('shared/src/main/ets/state/ThemeDisplayState.ets'));
  must(/@Trace\s+mode\b/.test(theme) && /@Trace\s+systemColorMode\b/.test(theme),
    'ThemeDisplayState: @Trace mode + systemColorMode added');

  const themeColor = strip(read('shared/src/main/ets/state/ThemeColorState.ets'));
  must(/@ObservedV2\b/.test(themeColor) && /@Trace\s+color\b/.test(themeColor) && /export function connectThemeColor\(/.test(themeColor),
    'ThemeColorState: @ObservedV2 @Trace color + connectThemeColor()');
}

// 2) settings apply()/save() chokepoints seed the holder (and keep AppStorage projection) -------
{
  const reply = read('shared/src/main/ets/settings/ReplyDisplaySettings.ets');
  must(/applyDescriptorValue<string>\(REPLY_DISPLAY_MODE_DESCRIPTOR/.test(reply), 'ReplyDisplaySettings.apply keeps descriptor AppStorage projection');
  must(/connectReplyDisplay\(\)\.mode\s*=/.test(reply), 'ReplyDisplaySettings.apply seeds ReplyDisplayState.mode');

  const lang = read('shared/src/main/ets/settings/LanguageSettings.ets');
  must(/setAppStorageValue<AppLanguageMode>\(StorageKeys\.LANGUAGE_MODE/.test(lang), 'LanguageSettings.apply keeps LANGUAGE_MODE AppStorage projection');
  must(/connectLanguageState\(\)\.mode\s*=/.test(lang), 'LanguageSettings.apply seeds LanguageState.mode');
  must(/\(connectLanguageState\(\)\.mode \|\| LanguageSettings\.MODE_SYSTEM\)/.test(lang), 'LanguageSettings.reapplyForFollowSystem reads LanguageState.mode');

  const align = read('shared/src/main/ets/settings/ReplyActionAlignmentSettings.ets');
  must(/applyDescriptorValue<string>\(REPLY_ACTION_ALIGNMENT_MODE_DESCRIPTOR/.test(align), 'ReplyActionAlignmentSettings.apply keeps descriptor AppStorage projection');
  must(/connectMotionReplyAlignment\(\)\.alignmentMode\s*=/.test(align), 'ReplyActionAlignmentSettings.apply seeds MotionReplyAlignmentState.alignmentMode');

  const reading = read('shared/src/main/ets/settings/ReadingSettings.ets');
  must(/RESTORE_POSITION_DEFAULT:\s*boolean\s*=\s*RESTORE_POSITION_DEFAULT/.test(reading), 'ReadingSettings exposes restore-position default');
  must(/store\.getSync\(KEY_RESTORE_POSITION,\s*RESTORE_POSITION_DEFAULT\)/.test(reading), 'ReadingSettings.loadFromStore defaults missing restore-position to on');
  must(/setAppStorageValue<boolean>\(StorageKeys\.READING_RESTORE_POSITION/.test(reading), 'ReadingSettings keeps READING_RESTORE_POSITION AppStorage projection');
  must(/readingState\.restorePosition\s*=\s*restorePosition/.test(reading), 'ReadingSettings.apply seeds ReadingSettingsState.restorePosition');
  must(/connectReadingSettings\(\)\.restorePosition\s*=\s*restorePosition/.test(reading), 'ReadingSettings.saveRestorePosition seeds the mirror');
  must(/const currentRestorePosition = connectReadingSettings\(\)\.restorePosition/.test(reading), 'ReadingSettings.save/saveTypography read the mirror (not AppStorage.get)');

  const theme = read('shared/src/main/ets/settings/ThemeSettings.ets');
  must(/setAppStorageValue<string>\(StorageKeys\.THEME_MODE/.test(theme), 'ThemeSettings.apply keeps THEME_MODE AppStorage projection');
  must(/connectThemeDisplay\(\)\.mode\s*=\s*normalizedMode/.test(theme), 'ThemeSettings.apply seeds ThemeDisplayState.mode');
  must(/connectThemeDisplay\(\)\.systemColorMode\s*=/.test(theme), 'ThemeSettings seeds ThemeDisplayState.systemColorMode (seed + reapply paths)');
  must(/const stored = connectThemeDisplay\(\)\.systemColorMode/.test(theme), 'ThemeSettings.getSystemColorMode reads the mirror (not AppStorage.get)');
  must(/const mode = ThemeSettings\.normalizeMode\(connectThemeDisplay\(\)\.mode/.test(theme), 'ThemeSettings.refreshEffectiveDark/reapply read ThemeDisplayState.mode');

  const themeColor = read('shared/src/main/ets/settings/ThemeColorSettings.ets');
  must(/setAppStorageValue<string>\(StorageKeys\.THEME_COLOR/.test(themeColor), 'ThemeColorSettings.apply keeps THEME_COLOR AppStorage projection');
  must(/connectThemeColor\(\)\.color\s*=\s*normalized/.test(themeColor), 'ThemeColorSettings.apply seeds ThemeColorState.color');
  must(/static readonly DEFAULT_COLOR:\s*string\s*=\s*THEME_COLOR_GALAXY_BLUE/.test(themeColor), 'ThemeColorSettings defaults to galaxy blue');
}

// 3) migrated readers no longer touch AppStorage ------------------------------------------------
hasNoAppStorage('shared/src/main/ets/settings/ReadingSettings.ets');
hasNoAppStorage('shared/src/main/ets/settings/ThemeSettings.ets');
hasNoAppStorage('shared/src/main/ets/settings/ThemeColorSettings.ets');
hasNoAppStorage('shared/src/main/ets/settings/LanguageSettings.ets');
hasNoAppStorage('shared/src/main/ets/i18n/AppStrings.ets');
hasNoAppStorage('shared/src/main/ets/services/MotionHandStateService.ets');
hasNoAppStorage('feature/settings/src/main/ets/pages/SettingsPage.ets');
hasNoAppStorage('feature/detail/src/main/ets/viewmodel/DetailViewModel.ets');
hasNoAppStorage('feature/detail/src/main/ets/pages/TopicDetailPage.ets');

{
  const motion = read('shared/src/main/ets/services/MotionHandStateService.ets');
  must(/connectMotionReplyAlignment\(\)\.alignmentMode/.test(motion), 'MotionHandStateService reads/writes alignmentMode mirror');
  must(/connectMotionReplyAlignment\(\)\.holdingHandSupported/.test(motion), 'MotionHandStateService reads/writes holdingHandSupported mirror');
  // Preserve the device behavior the existing alignment contract pins.
  must(motion.includes("MotionHandStateService.setEdge('right')"), 'MotionHandStateService default edge still right');
  must(motion.includes('setHoldingHandSupported(true)') && motion.includes('setHoldingHandSupported(false)'), 'holding-hand support success/failure states preserved');

  const detailVm = read('feature/detail/src/main/ets/viewmodel/DetailViewModel.ets');
  must(/connectReplyDisplay\(\)\.mode/.test(detailVm), 'DetailViewModel reads ReplyDisplayState.mode');
  const topic = read('feature/detail/src/main/ets/pages/TopicDetailPage.ets');
  must(/connectReplyDisplay\(\)\.mode/.test(topic), 'TopicDetailPage reads ReplyDisplayState.mode');
  must(/this\.reading\.restorePosition/.test(topic), 'TopicDetailPage reads ReadingSettingsState.restorePosition');
  const appStrings = read('shared/src/main/ets/i18n/AppStrings.ets');
  must(/connectLanguageState\(\)\.mode/.test(appStrings), 'AppStrings.currentLanguageMode reads LanguageState.mode');
}

// 4) no soft restart / reload / manual-refresh lane in any touched runtime file -----------------
for (const rel of [
  'shared/src/main/ets/settings/ThemeSettings.ets',
  'shared/src/main/ets/settings/LanguageSettings.ets',
  'shared/src/main/ets/i18n/AppStrings.ets',
  'feature/settings/src/main/ets/pages/SettingsPage.ets',
]) {
  must(!/restartApp|terminateSelf|loadContent|LOCALE_REVISION|languageRefreshKey/.test(read(rel)), `${rel}: no soft restart/reload/manual-refresh lane`);
}

// 5) barrel exports the new holders for cross-module (feature) consumers -------------------------
{
  const barrel = read('shared/src/main/ets/Index.ets');
  for (const c of ['connectReplyDisplay', 'connectLanguageState', 'connectMotionReplyAlignment', 'connectThemeDisplay', 'connectThemeColor', 'connectAutoDailyCheckin', 'connectMediaSettings']) {
    must(barrel.includes(c), `shared barrel exports ${c}`);
  }
}

console.log(`\nappstorage runtime holders contract: ${failures} failure(s)`);
if (failures > 0) process.exit(1);
