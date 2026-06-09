#!/usr/bin/env node
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

const coordinator = readFileSync('feature/settings/src/main/ets/model/SettingsPageCoordinator.ets', 'utf8')

// Each specific language must be shown in its OWN script (native self-language label),
// not a string that re-translates with the current UI locale. Post i18n-migration the
// labels are routed through $r('app.string.language_*') resources whose values are
// locale-INVARIANT (verified below against every locale json). The intent is unchanged:
// "简体中文" always reads "简体中文", "日本語" always reads "日本語", etc.
const localeFiles = ['base', 'en_US', 'zh_CN', 'zh_HK', 'zh_TW']

function loadLocaleStrings(loc) {
  const json = JSON.parse(readFileSync(`entry/src/main/resources/${loc}/element/string.json`, 'utf8'))
  const map = new Map()
  for (const entry of json.string) {
    map.set(entry.name, entry.value)
  }
  return map
}

const locales = new Map(localeFiles.map((loc) => [loc, loadLocaleStrings(loc)]))

// resource key -> expected native self-language label (must be identical across all locales)
const expectedLabels = new Map([
  ['MODE_ZH_CN', { key: 'language_simplified_chinese', native: '简体中文' }],
  ['MODE_ZH_HK', { key: 'language_traditional_chinese_hk', native: '繁體中文（香港）' }],
  ['MODE_ZH_TW', { key: 'language_traditional_chinese_tw', native: '繁體中文（台灣）' }],
  ['MODE_EN', { key: 'language_english', native: 'English' }],
  ['MODE_JA', { key: 'language_japanese', native: '日本語' }],
  ['MODE_KO', { key: 'language_korean', native: '한국어' }],
])

// Follow-system stays a localized resource (it SHOULD translate with the UI locale).
assert.match(
  coordinator,
  /\$r\('app\.string\.language_follow_system'\)/,
  'Follow system must remain a localized resource label',
)

function escapeRegExp(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
}

function sliceBetween(startToken, endToken) {
  const start = coordinator.indexOf(startToken)
  const end = coordinator.indexOf(endToken)
  assert.ok(start >= 0, `missing block start: ${startToken}`)
  assert.ok(end > start, `missing block end after ${startToken}: ${endToken}`)
  return coordinator.slice(start, end)
}

const targetLanguageBlock = sliceBetween('static languageModeOptions()', 'static themeModeOptions()')
const selectedLanguageBlock = sliceBetween('static languageModeLabel', 'static themeModeLabel')

for (const [modeName, info] of expectedLabels) {
  const keyRe = escapeRegExp(info.key)

  const optionPattern = new RegExp(
    String.raw`\{\s*label:\s*\$r\('app\.string\.${keyRe}'\),\s*value:\s*LanguageSettings\.${modeName}\s*\}`,
  )
  assert.match(
    targetLanguageBlock,
    optionPattern,
    `${modeName} picker option must use native self-language resource ${info.key} (${info.native})`,
  )

  const labelBranchPattern = new RegExp(
    String.raw`if\s*\(\s*normalizedMode\s*===\s*LanguageSettings\.${modeName}\s*\)\s*\{\s*return\s+\$r\('app\.string\.${keyRe}'\)\s*\}`,
  )
  assert.match(
    selectedLanguageBlock,
    labelBranchPattern,
    `${modeName} selected language label must use native self-language resource ${info.key} (${info.native})`,
  )

  // The native-label intent only holds if the resource is locale-INVARIANT: the same
  // self-language string in every locale. A per-locale translation here would silently
  // re-translate the picker label and break the contract's purpose.
  for (const [loc, map] of locales) {
    assert.equal(
      map.get(info.key),
      info.native,
      `${loc} ${info.key} must stay the native self-language label ${info.native}, found ${JSON.stringify(map.get(info.key))}`,
    )
  }
}

console.log('PASS language picker native label contract')
