#!/usr/bin/env node
// Static contract for the immersive material setting.
//
// The UI offers auto/exquisite/gentle/smooth only. "Off"/NONE is deliberately
// not a user option, and HDS material call sites must read the shared setting.
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

function read(path) {
  return readFileSync(new URL(`../${path}`, import.meta.url), 'utf8')
}

const settingsPath = 'shared/src/main/ets/settings/ImmersiveMaterialSettings.ets'
const settings = read(settingsPath)
const index = read('entry/src/main/ets/pages/Index.ets')
const miniButton = read('feature/detail/src/main/ets/components/HdsMiniBarButton.ets')
const settingsPage = read('feature/settings/src/main/ets/pages/SettingsPage.ets')
const coordinator = read('feature/settings/src/main/ets/model/SettingsPageCoordinator.ets')

assert.match(settings, /DEFAULT_LEVEL:\s*string\s*=\s*LEVEL_ADAPTIVE/, `${settingsPath}: default is adaptive`)
assert.match(settings, /LEVEL_EXQUISITE/, `${settingsPath}: exposes exquisite level`)
assert.match(settings, /LEVEL_GENTLE/, `${settingsPath}: exposes gentle level`)
assert.match(settings, /LEVEL_SMOOTH/, `${settingsPath}: exposes smooth level`)
assert.doesNotMatch(settings, /MaterialType\.NONE|LEVEL_NONE|common_closed|关闭|Off/, `${settingsPath}: no user-facing off material option`)
assert.match(settings, /getSystemMaterialTypes\(\)/, `${settingsPath}: checks device material type support`)
assert.match(settings, /MaterialType\.IMMERSIVE[\s\S]*MaterialLevel\.EXQUISITE/, `${settingsPath}: maps exquisite to immersive material`)
assert.match(settings, /MaterialType\.IMMERSIVE[\s\S]*MaterialLevel\.GENTLE/, `${settingsPath}: maps gentle to immersive material`)
assert.match(settings, /MaterialType\.IMMERSIVE[\s\S]*MaterialLevel\.SMOOTH/, `${settingsPath}: maps smooth to immersive material`)
assert.match(settings, /MaterialType\.ADAPTIVE[\s\S]*MaterialLevel\.ADAPTIVE/, `${settingsPath}: maps adaptive fallback`)

assert.match(settingsPage, /app\.string\.immersive_material/, 'SettingsPage renders immersive material row')
assert.match(settingsPage, /ImmersiveMaterialMenu/, 'SettingsPage renders immersive material menu')
assert.match(coordinator, /immersiveMaterialOptions\(\)/, 'SettingsPageCoordinator exposes immersive material options')
assert.match(coordinator, /immersiveMaterialLabel\(level:\s*string\)/, 'SettingsPageCoordinator exposes immersive material label')

assert.match(index, /connectImmersiveMaterialSettings\(\)/, 'Index reads immersive material state')
assert.match(index, /ImmersiveMaterialSettings\.effect\(this\.immersiveMaterial\.level\)/, 'Index material effect comes from setting')
assert.doesNotMatch(index, /MaterialLevel\.ADAPTIVE/, 'Index must not hard-code adaptive material level')
assert.match(miniButton, /connectImmersiveMaterialSettings\(\)/, 'HdsMiniBarButton reads immersive material state')
assert.match(miniButton, /ImmersiveMaterialSettings\.effect\(this\.immersiveMaterial\.level\)/, 'HdsMiniBarButton material effect comes from setting')
assert.doesNotMatch(miniButton, /MaterialLevel\.ADAPTIVE/, 'HdsMiniBarButton must not hard-code adaptive material level')

// Per-surface immersive-material tiers follow the HarmonyOS guidance: top-floating search → ULTRA_THIN,
// arbitrary-position menus/popups → THICK, dialog boxes + semi-modal sheets → ULTRA_THICK. (Dialogs/sheets
// were REGULAR and read as "too transparent" once API 26 began rendering the material.)
const appPrompt = read('shared/src/main/ets/utils/AppPrompt.ets')
const bindSheetHelper = read('shared/src/main/ets/utils/BindSheetHelper.ets')
const searchField = read('shared/src/main/ets/components/AppSearchField.ets')
assert.match(appPrompt, /static surfaceSystemMaterial\(\)[\s\S]*?ImmersiveStyle\.THICK/, 'AppPrompt: menu/popup material uses THICK')
assert.match(appPrompt, /static modalSystemMaterial\(\)[\s\S]*?ImmersiveStyle\.ULTRA_THICK/, 'AppPrompt: dialog/sheet material uses ULTRA_THICK')
assert.match(appPrompt, /showAlertDialog[\s\S]*?AppPrompt\.modalSystemMaterial\(\)/, 'AppPrompt: alert dialog reads the ULTRA_THICK modal material')
assert.match(appPrompt, /toastMaterial\(\)[\s\S]*?ImmersiveStyle\.REGULAR/, 'AppPrompt: toast keeps REGULAR')
assert.match(bindSheetHelper, /AppPrompt\.modalSystemMaterial\(\)/, 'BindSheetHelper: semi-modal sheets read the ULTRA_THICK modal material')
assert.doesNotMatch(bindSheetHelper, /AppPrompt\.surfaceSystemMaterial\(\)/, 'BindSheetHelper: sheets no longer use the thinner menu material')
assert.match(searchField, /ImmersiveStyle\.ULTRA_THIN/, 'AppSearchField: top-floating search keeps ULTRA_THIN')

for (const locale of ['base', 'en_US', 'zh_CN', 'zh_HK', 'zh_TW', 'ja_JP', 'ko_KR']) {
  const strings = read(`entry/src/main/resources/${locale}/element/string.json`)
  assert.match(strings, /"name":\s*"immersive_material"/, `${locale}: has immersive material title`)
  assert.match(strings, /"name":\s*"immersive_material_exquisite"/, `${locale}: has exquisite label`)
  assert.match(strings, /"name":\s*"immersive_material_gentle"/, `${locale}: has gentle label`)
  assert.match(strings, /"name":\s*"immersive_material_smooth"/, `${locale}: has smooth label`)
}

console.log('immersive material settings contract OK')
