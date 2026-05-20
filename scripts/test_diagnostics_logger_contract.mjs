#!/usr/bin/env node
import fs from 'node:fs'
import path from 'node:path'

const repo = process.cwd()
const read = (rel) => fs.readFileSync(path.join(repo, rel), 'utf8')
const assert = (condition, message) => {
  if (!condition) throw new Error(message)
}

const files = {
  redactor: 'shared/src/main/ets/diagnostics/DiagnosticsRedactor.ets',
  logger: 'shared/src/main/ets/diagnostics/DiagnosticLogger.ets',
  store: 'shared/src/main/ets/diagnostics/DiagnosticsStore.ets',
  settings: 'shared/src/main/ets/settings/DiagnosticsSettings.ets',
  index: 'shared/src/main/ets/Index.ets',
  storageKeys: 'shared/src/main/ets/constants/StorageKeys.ets',
  settingsPage: 'feature/settings/src/main/ets/pages/SettingsPage.ets',
  autoDaily: 'shared/src/main/ets/services/AutoDailyCheckinService.ets',
  notificationPage: 'entry/src/main/ets/pages/NotificationPage.ets',
  notificationVm: 'entry/src/main/ets/viewmodel/NotificationCenterViewModel.ets',
  notificationCache: 'entry/src/main/ets/model/NotificationCacheCoordinator.ets',
  accountPage: 'entry/src/main/ets/pages/AccountPage.ets',
}
for (const [name, rel] of Object.entries(files)) {
  assert(fs.existsSync(path.join(repo, rel)), `${name} file missing: ${rel}`)
}

const redactor = read(files.redactor)
for (const token of [
  'sanitizeEvent(entry: DiagnosticLogEntry)',
  'sanitizeContext(context: DiagnosticContextObject)',
  'sanitizeUrl(value: string)',
  "cookie') >= 0",
  "token') >= 0",
  "authorization') >= 0",
  "password') >= 0",
  "two_factor') >= 0",
  "lower === 'code'",
  "once') >= 0",
  "redeemPath".toLowerCase(),
  "rawhtml') >= 0",
  "content_rendered') >= 0",
  "reply_content_rendered') >= 0",
  "payload_rendered') >= 0",
  "lower === 'body'",
  'once=<redacted>',
  '/delete/notification/<id>?once=<redacted>',
]) {
  assert(redactor.toLowerCase().includes(token.toLowerCase()), `redactor contract missing ${token}`)
}

const logger = read(files.logger)
for (const token of [
  'static configure(enabled: boolean',
  'static debug(',
  'static info(',
  'static warn(',
  'static error(',
  'DiagnosticsRedactor.sanitizeEvent(entry)',
  'DiagnosticsStore.append(safeEntry)',
  'catch (_error)',
  'Never throw to callers',
  'exportText()',
  'clear()',
]) {
  assert(logger.includes(token), `logger contract missing ${token}`)
}
const store = read(files.store)
assert(store.includes('DEFAULT_MAX_ENTRIES: number = 400'), 'ring buffer default must be bounded')
assert(store.includes('slice(DiagnosticsStore.entries.length - DiagnosticsStore.maxEntries)'), 'ring buffer must keep newest entries')
assert(store.includes('exportText()'), 'store must export redacted text')

const settings = read(files.settings)
assert(settings.includes('DEFAULT_ENABLED: boolean = true'), 'diagnostics should default enabled')
assert(settings.includes("DEFAULT_MIN_LEVEL: string = DiagnosticsSettings.LEVEL_INFO"), 'diagnostics default level must be info')
assert(settings.includes('DiagnosticLogger.configure(enabled, safeLevel)'), 'settings must configure logger')

const index = read(files.index)
for (const token of ['DiagnosticLogger', 'DiagnosticsRedactor', 'DiagnosticsStore', 'DiagnosticsSettings']) {
  assert(index.includes(token), `shared Index missing ${token}`)
}
const storageKeys = read(files.storageKeys)
assert(storageKeys.includes('DIAGNOSTICS_ENABLED') && storageKeys.includes('DIAGNOSTICS_MIN_LEVEL'), 'diagnostics storage keys missing')

const settingsPage = read(files.settingsPage)
for (const token of ['诊断日志', '复制诊断日志', '清空诊断日志', 'pasteboard.createData', 'DiagnosticsSettings.exportText()', 'DiagnosticsSettings.clearLogs()', 'saveDiagnostics']) {
  assert(settingsPage.includes(token), `SettingsPage diagnostics UI missing ${token}`)
}
const advancedHeaderIndex = settingsPage.indexOf("this.SectionHeader('高级')")
const diagnosticsCallIndex = settingsPage.indexOf('this.DiagnosticsSection()', advancedHeaderIndex)
const apiDomainCallIndex = settingsPage.indexOf('this.ApiDomainAdvancedSection()', diagnosticsCallIndex)
assert(
  advancedHeaderIndex >= 0 && diagnosticsCallIndex > advancedHeaderIndex && apiDomainCallIndex > diagnosticsCallIndex,
  'SettingsPage must place diagnostics ListItem under 高级 before the API domain ListItem',
)
const diagnosticsStart = settingsPage.indexOf('  DiagnosticsSection() {')
const diagnosticsEnd = settingsPage.indexOf('\n  @Builder', diagnosticsStart + 1)
assert(diagnosticsStart >= 0 && diagnosticsEnd > diagnosticsStart, 'SettingsPage DiagnosticsSection boundary missing')
const diagnosticsSection = settingsPage.slice(diagnosticsStart, diagnosticsEnd)
const diagnosticsIndex = diagnosticsSection.indexOf('诊断日志')
const copyDiagnosticsIndex = diagnosticsSection.indexOf('复制诊断日志')
const clearDiagnosticsIndex = diagnosticsSection.indexOf('清空诊断日志')
assert(diagnosticsIndex >= 0 && copyDiagnosticsIndex > diagnosticsIndex && clearDiagnosticsIndex > copyDiagnosticsIndex, 'DiagnosticsSection controls must stay grouped in visible order')
assert(!diagnosticsSection.includes('API 域名'), 'DiagnosticsSection must not contain API 域名 row')
const apiDomainStart = settingsPage.indexOf('  ApiDomainAdvancedSection() {')
const apiDomainEnd = settingsPage.indexOf('\n  @Builder', apiDomainStart + 1)
assert(apiDomainStart >= 0 && apiDomainEnd > apiDomainStart, 'SettingsPage ApiDomainAdvancedSection boundary missing')
const apiDomainSection = settingsPage.slice(apiDomainStart, apiDomainEnd)
assert(apiDomainSection.includes('API 域名'), 'ApiDomainAdvancedSection must contain API 域名 row')
for (const token of ['诊断日志', '复制诊断日志', '清空诊断日志']) {
  assert(!apiDomainSection.includes(token), `ApiDomainAdvancedSection must not contain diagnostics token ${token}`)
}
assert(!settingsPage.includes('this.AdvancedSection()'), 'SettingsPage must not use the old combined AdvancedSection entry')

const autoDaily = read(files.autoDaily)
for (const event of [
  'auto_daily_checkin_skip_disabled',
  'auto_daily_checkin_skip_no_cookie',
  'auto_daily_checkin_skip_in_flight',
  'auto_daily_checkin_skip_already_attempted',
  'auto_daily_checkin_attempt_start',
  'auto_daily_checkin_attempt_saved',
  'auto_daily_checkin_mission_loaded',
  'auto_daily_checkin_not_redeemable',
  'auto_daily_checkin_redeem_start',
  'auto_daily_checkin_redeem_success',
  'auto_daily_checkin_error',
]) assert(autoDaily.includes(event), `AutoDailyCheckinService missing ${event}`)
const autoDailyLoggerLines = autoDaily.split('\n').filter((line) => line.includes('DiagnosticLogger.')).join('\n')
for (const forbidden of ['cleanCookie', 'cookie:', 'once:', 'authToken']) {
  assert(!autoDailyLoggerLines.includes(forbidden), `AutoDailyCheckinService DiagnosticLogger line contains forbidden token ${forbidden}`)
}
assert(!autoDaily.includes('redeemPath: mission.redeemPath'), 'AutoDailyCheckinService must not log raw redeemPath')

const notificationPage = read(files.notificationPage)
for (const event of [
  'notification_auth_snapshot_start', 'notification_auth_snapshot_stale_drop', 'notification_identity_changed',
  'notification_refresh_start', 'notification_refresh_skip', 'notification_refresh_stale_drop', 'notification_refresh_success', 'notification_refresh_error',
  'notification_load_more_start', 'notification_load_more_success', 'notification_load_more_error',
  'notification_cache_load_start', 'notification_cache_load_skip', 'notification_cache_apply', 'notification_cache_drop', 'notification_cache_save_success', 'notification_cache_save_error',
  'notification_force_refresh_queued', 'notification_force_refresh_replayed', 'notification_reset',
  'notification_two_factor_required', 'notification_session_expired', 'notification_delete_start', 'notification_delete_success', 'notification_delete_error'
]) assert(notificationPage.includes(event), `NotificationPage missing ${event}`)

const notificationVm = read(files.notificationVm)
for (const event of ['notification_source_selected', 'notification_page_loaded', 'notification_page_load_error']) {
  assert(notificationVm.includes(event), `NotificationCenterViewModel missing ${event}`)
}
const notificationCache = read(files.notificationCache)
for (const event of ['notification_cache_coordinator_load', 'notification_cache_coordinator_load_result', 'notification_cache_coordinator_save_result']) {
  assert(notificationCache.includes(event), `NotificationCacheCoordinator missing ${event}`)
}
const accountPage = read(files.accountPage)
for (const event of [
  'account_auth_snapshot_loaded', 'account_cookie_restore_success', 'account_cookie_restore_error',
  'account_session_validate_start', 'account_session_validate_success', 'account_session_validate_error', 'account_session_two_factor_required', 'account_session_expired',
  'account_meta_cache_load_hit', 'account_meta_cache_load_miss', 'account_meta_cache_load_error', 'account_meta_fetch_start', 'account_meta_fetch_success', 'account_meta_fetch_error', 'account_meta_cache_save_success', 'account_meta_cache_save_error',
  'account_daily_redeem_skip', 'account_daily_redeem_start', 'account_daily_redeem_success', 'account_daily_redeem_error', 'account_logout_all_start', 'account_logout_all_complete'
]) assert(accountPage.includes(event), `AccountPage missing ${event}`)

for (const [name, rel] of Object.entries({ autoDaily: files.autoDaily, notificationPage: files.notificationPage, notificationVm: files.notificationVm, notificationCache: files.notificationCache, accountPage: files.accountPage })) {
  const src = read(rel)
  const loggerLines = src.split('\n').filter((line) => line.includes('DiagnosticLogger.')).join('\n')
  for (const forbidden of ['cleanCookie', 'token:', 'cookie:', 'once:', 'redeemPath:', 'delete_once', 'content_rendered:', 'reply_content_rendered:', 'payload_rendered:', 'body:', 'replyContent:', 'payload:']) {
    assert(!loggerLines.includes(forbidden), `${name} DiagnosticLogger line contains forbidden token ${forbidden}`)
  }
}

// Static guard: ArkTS redactor must have recursive object/array sanitization with explicit bounds.
for (const token of [
  'MAX_REDACTION_DEPTH',
  'MAX_OBJECT_KEYS',
  'MAX_ARRAY_ITEMS',
  'private static sanitizeValue(',
  'private static sanitizeArray(',
  'sanitizeObject(value as DiagnosticContextObject, depth)',
  'sanitizeArray(key, value as DiagnosticContextValue[], depth)',
  'keys.slice(0, MAX_OBJECT_KEYS)',
  'values.slice(0, MAX_ARRAY_ITEMS)',
]) {
  assert(redactor.includes(token), `recursive redactor structure missing ${token}`)
}


// Faithful JS mirror of the intended recursive redaction algorithm for contract samples.
const REDACTED = '<redacted>'
const DROPPED = '<omitted>'
const MAX_STRING_LENGTH = 160
const MAX_REDACTION_DEPTH = 5
const MAX_OBJECT_KEYS = 80
const MAX_ARRAY_ITEMS = 80

function safeToken(value) {
  return String(value || '').replace(/[^a-zA-Z0-9_.:-]/g, '_').slice(0, 80)
}
function dropDangerousPath(value) {
  return String(value || '')
    .replace(/\/delete\/notification\/\d+/gi, '/delete/notification/<id>')
    .replace(/\/mission\/daily\/redeem/gi, '/mission/daily/redeem')
    .replace(/\/thank\/(reply|topic)\/\d+/gi, '/thank/$1/<id>')
    .replace(/\/favorite\/(topic|node)\/[^/?]+/gi, '/favorite/$1/<id>')
}
function sanitizeUrl(value) {
  const clean = String(value || '').trim()
  if (!clean) return ''
  const noFragment = clean.split('#')[0]
  const queryIndex = noFragment.indexOf('?')
  if (queryIndex < 0) return dropDangerousPath(noFragment)
  const base = dropDangerousPath(noFragment.slice(0, queryIndex))
  const query = noFragment.slice(queryIndex + 1)
  if (!query) return base
  const pairs = query.split('&').filter((part) => part.length > 0)
    .map((part) => `${safeToken(part.split('=')[0] || 'param')}=${REDACTED}`)
  return `${base}?${pairs.join('&')}`
}
function sanitizeString(value) {
  let clean = String(value || '')
  clean = clean.replace(/(Cookie|Set-Cookie)\s*[:=][^;\n]+/gi, `$1=${REDACTED}`)
  clean = clean.replace(/Authorization\s*[:=]\s*(Bearer\s+)?[^\s;]+/gi, `Authorization=${REDACTED}`)
  clean = clean.replace(/Bearer\s+[A-Za-z0-9._~+\/-]+/gi, `Bearer ${REDACTED}`)
  clean = clean.replace(/([?&](once|token|auth|code|password|delete_once|redeem)[^=]*=)[^&#\s]+/gi, `$1${REDACTED}`)
  clean = clean.replace(/\/mission\/daily\/redeem\?[^\s]+/gi, '/mission/daily/redeem?once=<redacted>')
  clean = clean.replace(/\/delete\/notification\/\d+\?[^\s]+/gi, '/delete/notification/<id>?once=<redacted>')
  clean = clean.replace(/\/thank\/(reply|topic)\/\d+\?[^\s]+/gi, '/thank/$1/<id>?once=<redacted>')
  clean = clean.replace(/\/favorite\/(topic|node)\/[^\s?]+\?[^\s]+/gi, '/favorite/$1/<id>?once=<redacted>')
  if (clean.indexOf('<html') >= 0 || clean.indexOf('<div') >= 0 || clean.indexOf('content_rendered') >= 0) return DROPPED
  return clean.length > MAX_STRING_LENGTH ? `${clean.slice(0, MAX_STRING_LENGTH)}…` : clean
}
function isDangerousKey(key) {
  const lower = String(key || '').toLowerCase()
  return lower.includes('cookie') || lower.includes('token') || lower.includes('authorization') ||
    lower.includes('password') || lower === 'pass' || lower.includes('twofactor') ||
    lower.includes('two_factor') || lower === 'code' || lower.includes('once') ||
    lower.includes('redeempath') || lower.includes('rawhtml') || lower === 'html' ||
    lower.includes('content_rendered') || lower.includes('reply_content_rendered') ||
    lower.includes('payload_rendered') || lower === 'body' || lower.includes('replycontent') ||
    lower.includes('payload') || (lower.includes('path') && (lower.includes('delete') || lower.includes('redeem') || lower.includes('thank') || lower.includes('favorite')))
}
function looksLikeUrlKey(key) {
  const lower = String(key || '').toLowerCase()
  return lower === 'url' || lower.endsWith('url') || lower === 'href'
}
function looksLikeUrl(value) {
  return /^https?:\/\//i.test(value) || /^\/[a-z0-9/_-]+\?/i.test(value)
}
function sanitizeValue(key, value, depth) {
  if (value === null || value === undefined) return null
  if (typeof value === 'string') return (looksLikeUrlKey(key) || looksLikeUrl(value)) ? sanitizeUrl(value) : sanitizeString(value)
  if (typeof value === 'number' || typeof value === 'boolean') return value
  if (Array.isArray(value)) return sanitizeArray(key, value, depth)
  if (typeof value === 'object') return sanitizeObject(value, depth)
  return DROPPED
}
function sanitizeArray(key, values, depth) {
  if (depth > MAX_REDACTION_DEPTH) return []
  const result = values.slice(0, MAX_ARRAY_ITEMS).map((value) => sanitizeValue(key, value, depth + 1))
  if (values.length > MAX_ARRAY_ITEMS) result.push(`<truncated:${values.length - MAX_ARRAY_ITEMS}>`)
  return result
}
function sanitizeObject(context, depth = 0) {
  const result = {}
  if (depth > MAX_REDACTION_DEPTH) return result
  const keys = Object.keys(context || {})
  for (const key of keys.slice(0, MAX_OBJECT_KEYS)) {
    result[key] = isDangerousKey(key) ? REDACTED : sanitizeValue(key, context[key], depth + 1)
  }
  if (keys.length > MAX_OBJECT_KEYS) result.__truncated_keys = keys.length - MAX_OBJECT_KEYS
  return result
}

const sample = JSON.stringify(sanitizeObject({
  outer: {
    cookie: 'A=B',
    nested: {
      Authorization: 'Bearer secret-token',
      url: '/delete/notification/123?once=456',
      harmlessText: 'Cookie: sid=secret; Authorization: Bearer another-secret',
    },
  },
  array: [
    { token: 'array-token', href: 'https://v2ex.com/mission/daily/redeem?once=abc&auth=def' },
    { twoFactorCode: '123456', password: 'pw-secret' },
    { content_rendered: '<div>private</div>', payload_rendered: '<html>raw</html>' },
    { body: 'private body', replyContent: 'private reply' },
  ],
  rawHtml: '<html>secret document</html>',
  safeUrl: 'https://v2ex.com/t/1?p=1&once=777#fragment',
}))
for (const secret of [
  'A=B', 'secret-token', 'once=456', 'sid=secret', 'another-secret', 'array-token',
  'once=abc', 'auth=def', '123456', 'pw-secret', '<div>private</div>', '<html>raw</html>',
  'private body', 'private reply', '<html>secret document</html>', 'once=777', '#fragment'
]) {
  assert(!sample.includes(secret), `recursive redaction mirror leaked ${secret}`)
}
assert(sample.includes('<redacted>'), 'recursive redaction mirror should mark redacted values')
assert(sample.includes('/delete/notification/<id>?once=<redacted>'), 'nested delete once URL should be sanitized')
assert(sample.includes('/mission/daily/redeem?once=<redacted>&auth=<redacted>'), 'array redeem URL should be sanitized')

const manyKeys = {}
for (let i = 0; i < MAX_OBJECT_KEYS + 5; i += 1) manyKeys[`k${i}`] = i
assert(sanitizeObject(manyKeys).__truncated_keys === 5, 'object redaction must be size bounded')
const manyItems = new Array(MAX_ARRAY_ITEMS + 3).fill(0).map((_, index) => ({ index }))
assert(sanitizeArray('items', manyItems, 0).at(-1) === '<truncated:3>', 'array redaction must be size bounded')

const accountTwoFactorEventLines = accountPage.split('\n')
  .filter((line) => line.includes('DiagnosticLogger.') && line.includes('account_session_two_factor_required'))
assert(accountTwoFactorEventLines.length === 1, 'AccountPage must log account_session_two_factor_required only once')

console.log('diagnostics logger contract passed')
