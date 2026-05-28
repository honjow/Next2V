#!/usr/bin/env node
/**
 * Locale matrix i18n contract.
 *
 * Covers app-owned resource values and runtime call sites that can bypass
 * ArkUI ResourceStr locale resolution when composing dynamic status text.
 */

import fs from 'node:fs'
import path from 'node:path'

const repo = process.cwd()
const CJK_RE = /[\u3400-\u9FFF\u3040-\u30FF\uAC00-\uD7AF]/
const locales = ['base', 'en_US', 'zh_CN', 'zh_HK', 'zh_TW', 'ja_JP', 'ko_KR']
const englishLocales = ['base', 'en_US']
const resourceRoot = path.join(repo, 'entry/src/main/resources')
const failures = []

function read(rel) {
  return fs.readFileSync(path.join(repo, rel), 'utf8')
}

function loadStrings(locale) {
  const rel = `entry/src/main/resources/${locale}/element/string.json`
  const full = path.join(repo, rel)
  if (!fs.existsSync(full)) {
    failures.push(`${rel}: missing locale resource file`)
    return new Map()
  }
  const data = JSON.parse(fs.readFileSync(full, 'utf8'))
  const map = new Map()
  for (const item of data.string || []) {
    map.set(String(item.name), String(item.value))
  }
  return map
}

const stringsByLocale = new Map(locales.map(locale => [locale, loadStrings(locale)]))

function fail(pathKey, message, value = undefined) {
  failures.push(value === undefined ? `${pathKey}: ${message}` : `${pathKey}: ${message} (${JSON.stringify(value)})`)
}

function valueOf(locale, key) {
  const map = stringsByLocale.get(locale)
  if (!map?.has(key)) {
    fail(`entry/src/main/resources/${locale}/element/string.json:${key}`, 'missing resource key')
    return ''
  }
  return map.get(key)
}

function assertEquals(locale, key, expected) {
  const value = valueOf(locale, key)
  if (value !== expected) {
    fail(`entry/src/main/resources/${locale}/element/string.json:${key}`, `expected ${JSON.stringify(expected)}`, value)
  }
}

function assertNoCjk(locale, key) {
  const value = valueOf(locale, key)
  if (CJK_RE.test(value)) {
    fail(`entry/src/main/resources/${locale}/element/string.json:${key}`, 'English/base app-owned resource contains CJK', value)
  }
}

function assertHasCjk(locale, key) {
  const value = valueOf(locale, key)
  if (!CJK_RE.test(value)) {
    fail(`entry/src/main/resources/${locale}/element/string.json:${key}`, 'Chinese locale resource should remain localized', value)
  }
}

for (const locale of englishLocales) {
  const rel = `entry/src/main/resources/${locale}/element/string.json`
  for (const [key, value] of stringsByLocale.get(locale)) {
    if (CJK_RE.test(value)) {
      fail(`${rel}:${key}`, 'base/en_US app-owned resource contains CJK', value)
    }
  }
}

const screenshotRegressionEnglish = {
  account_active_label: 'Current',
  account_switch_label: 'Switch',
  account_remove_label: 'Remove',
  account_add_another: 'Add another account',
  account_list_header: 'Accounts',
  account_management: 'Account management',
  cache_subtitle_updated: 'Lists {0} · Details {1} · Updated {2}',
  cache_subtitle: 'Lists {0} · Details {1}',
  common_closed: 'Off',
  proxy_not_configured: 'Not configured',
  proxy_summary_http_not_configured: 'HTTP proxy · Not configured',
  proxy_summary_socks5_not_configured: 'SOCKS5 proxy · Not configured',
}

for (const locale of englishLocales) {
  for (const [key, expected] of Object.entries(screenshotRegressionEnglish)) {
    assertEquals(locale, key, expected)
    assertNoCjk(locale, key)
  }
}

for (const locale of ['zh_CN', 'zh_HK', 'zh_TW']) {
  for (const key of [
    'account_active_label',
    'account_switch_label',
    'account_remove_label',
    'cache_subtitle_updated',
    'cache_subtitle',
    'common_closed',
    'proxy_summary_http_not_configured',
  ]) {
    assertHasCjk(locale, key)
  }
}

const baseKeys = new Set(stringsByLocale.get('base').keys())
for (const locale of locales) {
  const keys = new Set(stringsByLocale.get(locale).keys())
  for (const key of baseKeys) {
    if (!keys.has(key)) {
      fail(`entry/src/main/resources/${locale}/element/string.json:${key}`, 'missing key from base locale matrix')
    }
  }
}

const sourceChecks = [
  {
    rel: 'entry/src/main/ets/pages/AccountManagementPage.ets',
    forbidden: ['当前', '切换', '移除'],
    required: [
      'AccountPageCoordinator.ACCOUNT_ACTIVE_LABEL',
      'AccountPageCoordinator.SWITCH_LABEL',
      'AccountPageCoordinator.REMOVE_LABEL',
    ],
  },
  {
    rel: 'entry/src/main/ets/model/AccountPageCoordinator.ets',
    forbidden: ['当前', '切换', '移除'],
    required: [
      'static get ACCOUNT_ACTIVE_LABEL(): ResourceStr { return AppStrings.R_ACCOUNT_ACTIVE_LABEL }',
      'static get SWITCH_LABEL(): ResourceStr { return AppStrings.R_ACCOUNT_SWITCH_LABEL }',
      'static get REMOVE_LABEL(): ResourceStr { return AppStrings.R_ACCOUNT_REMOVE_LABEL }',
    ],
  },
  {
    rel: 'feature/settings/src/main/ets/model/StorageSettingsCoordinator.ets',
    forbidden: ['列表', '详情', '更新于'],
    required: [
      "AppStrings.R_CACHE_SUBTITLE_UPDATED",
      "AppStrings.R_CACHE_SUBTITLE",
      "AppStrings.format",
    ],
    forbiddenPatterns: [
      /\$r\('app\.string\.cache_subtitle/,
    ],
  },
  {
    rel: 'shared/src/main/ets/settings/NetworkProxySettings.ets',
    forbidden: ['关闭'],
    required: [
      'static summary(snapshot: NetworkProxySettingsSnapshot): ResourceStr',
      'return AppStrings.R_COMMON_CLOSED',
      'return AppStrings.R_PROXY_SUMMARY_HTTP_NOT_CONFIGURED',
    ],
  },
]

for (const check of sourceChecks) {
  const text = read(check.rel)
  for (const token of check.forbidden) {
    if (text.includes(token)) {
      fail(check.rel, `must not inline app-owned CJK token ${JSON.stringify(token)}`)
    }
  }
  for (const token of check.required) {
    if (!text.includes(token)) {
      fail(check.rel, `missing locale-safe call-site token ${JSON.stringify(token)}`)
    }
  }
  for (const pattern of check.forbiddenPatterns || []) {
    if (pattern.test(text)) {
      fail(check.rel, `forbidden locale-bypassing pattern ${pattern}`)
    }
  }
}

if (failures.length > 0) {
  console.log('=== Locale Matrix i18n Contract: FAIL ===')
  for (const item of failures) {
    console.log(`  ${item}`)
  }
  process.exit(1)
}

console.log(`Locale Matrix i18n Contract: PASS (${resourceRoot})`)
