#!/usr/bin/env node
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

const read = (path) => readFileSync(path, 'utf8')
const mustContain = (source, needle, label) => {
  assert.notEqual(source.indexOf(needle), -1, `${label} not found`)
}

const settings = read('shared/src/main/ets/settings/ReadingSettings.ets')
mustContain(settings, 'TEXT_SCALE_SMALL: number = 12 / ThemeConstants.FONT_SIZE_BODY', 'small preset')
mustContain(settings, 'TEXT_SCALE_STANDARD: number = 1.0', 'standard preset')
mustContain(settings, 'TEXT_SCALE_LARGE: number = 16 / ThemeConstants.FONT_SIZE_BODY', 'large preset')
mustContain(settings, 'TEXT_SCALE_EXTRA_LARGE: number = 17 / ThemeConstants.FONT_SIZE_BODY', 'extra-large preset')
mustContain(settings, 'TEXT_SCALE_LARGEST: number = 18 / ThemeConstants.FONT_SIZE_BODY', 'largest preset')
mustContain(settings, 'presetIndexForTextScale(numeric)', 'continuous-value nearest-preset migration')
mustContain(settings, 'textScaleForPresetIndex(value: number)', 'preset-index to scale mapping')

const control = read('feature/settings/src/main/ets/components/SettingsPageComponents.ets')
mustContain(control, 'value: ReadingSettings.presetIndexForTextScale(this.textScale)', 'slider uses preset index')
mustContain(control, 'max: ReadingSettings.TEXT_SCALE_PRESET_COUNT - 1', 'slider has five positions')
mustContain(control, 'step: 1', 'slider snaps by one preset')
mustContain(control, '.showSteps(true)', 'slider shows tick marks')
mustContain(control, '.showTips(true, this.presetLabel())', 'slider tip names the current preset')
mustContain(control, '.enableHapticFeedback(true)', 'slider enables native haptics')

const scopedSurfaces = [
  'shared/src/main/ets/components/TopicCard.ets',
  'feature/detail/src/main/ets/components/TopicDetailComponents.ets',
  'feature/detail/src/main/ets/components/ReplyComposerBar.ets',
  'entry/src/main/ets/pages/TopicEditorPage.ets',
  'entry/src/main/ets/components/NotificationPageComponents.ets',
  'entry/src/main/ets/components/SearchPageComponents.ets',
  'feature/node/src/main/ets/components/DiscoverPageComponents.ets',
  'feature/user/src/main/ets/components/UserRepliesComponents.ets',
  'feature/user/src/main/ets/components/UserProfileComponents.ets',
]
for (const path of scopedSurfaces) {
  const source = read(path)
  mustContain(source, 'connectReadingSettings', `${path} observes the global setting`)
  mustContain(source, 'ReadingSettings.scaleTypographyToken', `${path} scales content typography`)
}

const resourceNames = [
  'reading_text_size_small',
  'reading_text_size_standard',
  'reading_text_size_large',
  'reading_text_size_extra_large',
  'reading_text_size_largest',
]
const localeFiles = [
  'base',
  'en_US',
  'zh_CN',
  'zh_HK',
  'zh_TW',
  'ja_JP',
  'ko_KR',
].map((locale) => `entry/src/main/resources/${locale}/element/string.json`)
for (const path of localeFiles) {
  const parsed = JSON.parse(read(path))
  const names = new Set(parsed.string.map((item) => item.name))
  for (const name of resourceNames) {
    assert.equal(names.has(name), true, `${path} is missing ${name}`)
  }
}

const zh = JSON.parse(read('entry/src/main/resources/zh_CN/element/string.json'))
const zhValues = new Map(zh.string.map((item) => [item.name, item.value]))
assert.deepEqual(
  resourceNames.map((name) => zhValues.get(name)),
  ['小', '标准', '大', '超大', '特大'],
  'Chinese preset labels must match the agreed order',
)
assert.equal(zhValues.get('nav_reading'), '字体设置', 'Chinese page title must describe font settings')

const moduleProfile = read('entry/src/main/module.json5')
mustContain(moduleProfile, 'ohos.permission.VIBRATE', 'native Slider haptics permission')

console.log('test_global_content_font_scale_contract: PASS')
