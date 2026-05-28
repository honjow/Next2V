#!/usr/bin/env node
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

const coordinator = readFileSync('feature/settings/src/main/ets/model/SettingsPageCoordinator.ets', 'utf8')

const expectedLabels = new Map([
  ['MODE_ZH_CN', '简体中文'],
  ['MODE_ZH_HK', '繁體中文（香港）'],
  ['MODE_ZH_TW', '繁體中文（台灣）'],
  ['MODE_EN', 'English'],
  ['MODE_JA', '日本語'],
  ['MODE_KO', '한국어'],
])

assert.match(
  coordinator,
  /AppStrings\.R_LANGUAGE_FOLLOW_SYSTEM/,
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

for (const [modeName, nativeLabel] of expectedLabels) {
  const nativeLabelRe = escapeRegExp(nativeLabel)
  const optionPattern = new RegExp(
    String.raw`\{\s*label:\s*'${nativeLabelRe}',\s*value:\s*LanguageSettings\.${modeName}\s*\}`,
  )
  assert.match(
    targetLanguageBlock,
    optionPattern,
    `${modeName} picker option must use native self-language label ${nativeLabel}`,
  )

  const labelBranchPattern = new RegExp(
    String.raw`if\s*\(\s*normalizedMode\s*===\s*LanguageSettings\.${modeName}\s*\)\s*\{\s*return\s+'${nativeLabelRe}'\s*\}`,
  )
  assert.match(
    selectedLanguageBlock,
    labelBranchPattern,
    `${modeName} selected language label must use native self-language label ${nativeLabel}`,
  )
}

for (const block of [targetLanguageBlock, selectedLanguageBlock]) {
  assert.doesNotMatch(
    block,
    /AppStrings\.R_LANGUAGE_(SIMPLIFIED_CHINESE|TRADITIONAL_CHINESE_HK|TRADITIONAL_CHINESE_TW|ENGLISH|JAPANESE|KOREAN)/,
    'Target language labels must not use current-locale-translated resource keys',
  )
}

console.log('PASS language picker native label contract')
