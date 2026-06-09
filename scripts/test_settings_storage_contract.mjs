#!/usr/bin/env node
import fs from 'node:fs'
import path from 'node:path'

const repo = process.cwd()
const read = (rel) => fs.readFileSync(path.join(repo, rel), 'utf8')
const assert = (condition, message) => {
  if (!condition) {
    throw new Error(message)
  }
}


const findMatchingBrace = (text, openBraceIndex) => {
  let depth = 0
  let quote = null
  let escaped = false
  let lineComment = false
  let blockComment = false

  for (let i = openBraceIndex; i < text.length; i += 1) {
    const char = text[i]
    const next = text[i + 1]

    if (lineComment) {
      if (char === '\n') {
        lineComment = false
      }
      continue
    }
    if (blockComment) {
      if (char === '*' && next === '/') {
        blockComment = false
        i += 1
      }
      continue
    }
    if (quote !== null) {
      if (escaped) {
        escaped = false
      } else if (char === '\\') {
        escaped = true
      } else if (char === quote) {
        quote = null
      }
      continue
    }

    if (char === '/' && next === '/') {
      lineComment = true
      i += 1
      continue
    }
    if (char === '/' && next === '*') {
      blockComment = true
      i += 1
      continue
    }
    if (char === '\'' || char === '"' || char === '`') {
      quote = char
      continue
    }
    if (char === '{') {
      depth += 1
    } else if (char === '}') {
      depth -= 1
      if (depth === 0) {
        return i
      }
    }
  }

  return -1
}

const extractMethodBody = (text, methodName) => {
  const methodRegex = new RegExp(`(?:static\\s+async|private\\s+static\\s+async|private\\s+static)\\s+${methodName}\\s*\\(`)
  const methodMatch = methodRegex.exec(text)
  assert(methodMatch !== null, `SettingsBootstrap.${methodName} method missing`)
  const openBraceIndex = text.indexOf('{', methodMatch.index)
  assert(openBraceIndex !== -1, `SettingsBootstrap.${methodName} opening brace missing`)
  const closeBraceIndex = findMatchingBrace(text, openBraceIndex)
  assert(closeBraceIndex !== -1, `SettingsBootstrap.${methodName} closing brace missing`)
  return text.slice(openBraceIndex + 1, closeBraceIndex)
}

const storageKeysText = read('shared/src/main/ets/constants/StorageKeys.ets')
const storageKeyRegex = /static readonly (\w+): string =\s*(?:\n\s*)?'([^']+)'/g
const orderedStorageKeys = []
const storageKeys = new Map()
let match
while ((match = storageKeyRegex.exec(storageKeysText)) !== null) {
  orderedStorageKeys.push([match[1], match[2]])
  storageKeys.set(match[1], match[2])
}

const expectedStorageKeys = [
  ['USE_CO_DOMAIN', 'useCoDomain'],
  ['SELECTED_BASE_URL', 'selectedBaseUrl'],
  ['MEDIA_AUTO_LOAD_IMAGES', 'mediaAutoLoadImages'],
  ['MEDIA_ONLY_LOAD_IMAGES_ON_WIFI', 'mediaOnlyLoadImagesOnWifi'],
  ['READING_TEXT_SCALE', 'readingTextScale'],
  ['READING_LINE_HEIGHT', 'readingLineHeight'],
  ['READING_DENSITY', 'readingDensity'],
  ['READING_RESTORE_POSITION', 'readingRestorePosition'],
  ['READING_BASE64_DECODE_MODE', 'readingBase64DecodeMode'],
  ['REPLY_DISPLAY_MODE', 'replyDisplayMode'],
  ['REPLY_CARD_STYLE', 'replyCardStyle'],
  ['REPLY_ACTION_ALIGNMENT_MODE', 'replyActionAlignmentMode'],
  ['AVATAR_APPEARANCE', 'avatarAppearance'],
  ['THEME_COLOR', 'themeColor'],
  ['THEME_MODE', 'themeMode'],
  ['THEME_EFFECTIVE_DARK', 'themeEffectiveDark'],
  ['SYSTEM_COLOR_MODE', 'systemColorMode'],
  ['LANGUAGE_MODE', 'languageMode'],
  ['DIAGNOSTICS_ENABLED', 'diagnosticsEnabled'],
  ['DIAGNOSTICS_MIN_LEVEL', 'diagnosticsMinLevel'],
  ['NETWORK_PROXY_MODE', 'networkProxyMode'],
  ['NETWORK_PROXY_HOST', 'networkProxyHost'],
  ['NETWORK_PROXY_PORT', 'networkProxyPort'],
  ['NETWORK_PROXY_SCHEME', 'networkProxyScheme'],
  ['NETWORK_PROXY_USERNAME', 'networkProxyUsername'],
  ['NETWORK_PROXY_PASSWORD', 'networkProxyPassword'],
  ['NETWORK_PROXY_EXCLUSION_LIST', 'networkProxyExclusionList'],
  ['TOPIC_READ_STATES', 'topicReadStates'],
  ['AUTH_TOKEN_CONFIGURED', 'authTokenConfigured'],
  ['AUTH_USERNAME', 'authUsername'],
  ['AUTH_COOKIE_CONFIGURED', 'authCookieConfigured'],
  ['AUTH_LOGIN_MODE', 'authLoginMode'],
  ['AUTH_SESSION_USERNAME', 'authSessionUsername'],
  ['AUTH_SESSION_AVATAR', 'authSessionAvatar'],
  ['AUTH_SESSION_VALIDATED_AT', 'authSessionValidatedAt'],
  ['AUTH_SESSION_UPDATED_AT', 'authSessionUpdatedAt'],
  ['ACTIVE_ACCOUNT_ID', 'activeAccountId'],
  ['BLOCKED_LIST_OWNER_KEY', 'blockedListOwnerKey'],
  ['BLOCKED_LIST_IGNORED_TOPIC_IDS', 'blockedListIgnoredTopicIds'],
  ['BLOCKED_LIST_BLOCKED_MEMBER_IDS', 'blockedListBlockedMemberIds'],
  ['BLOCKED_LIST_BLOCKED_MEMBER_METAS', 'blockedListBlockedMemberMetas'],
  ['BLOCKED_LIST_IGNORED_TOPIC_METAS', 'blockedListIgnoredTopicMetas'],
  ['BLOCKED_LIST_UPDATED_AT', 'blockedListUpdatedAt'],
  ['BLOCKED_LIST_SELECTED_TAB', 'blockedListSelectedTab'],
  // Retired (now V2-only in the AppStorageV2 'v2:twoFactor' holder, zero runtime readers — Index reads the
  // mirror): the twoFactorVisible/Cookie/Source keys AND the write-only twoFactorRequestedAt/
  // twoFactorCompletedAt timestamp breadcrumbs. All five are asserted absent below.
  ['AUTO_DAILY_CHECKIN_ENABLED', 'autoDailyCheckinEnabled'],
  ['AUTO_DAILY_CHECKIN_LAST_ATTEMPT_DATE', 'autoDailyCheckinLastAttemptDate'],
  ['AUTO_DAILY_CHECKIN_LAST_ATTEMPT_IDENTITY', 'autoDailyCheckinLastAttemptIdentity'],
  ['AUTO_DAILY_CHECKIN_LAST_SUCCESS_DATE', 'autoDailyCheckinLastSuccessDate'],
  ['CLOUD_SYNC_ENABLED', 'cloudSyncEnabled'],
  ['CLOUD_SYNC_FEATURE_PREFIX', 'cloudSyncFeat_'],
  ['CLOUD_SYNC_LAST_AT', 'cloudSyncLastAt'],
  ['CLOUD_SYNC_LAST_OK', 'cloudSyncLastOk'],
  ['CLOUD_SYNC_LAST_CLOUD_DISABLED', 'cloudSyncLastCloudDisabled'],
  ['CLOUD_SYNC_REUPLOAD_FLUSH_DONE', 'cloudSyncReuploadFlushDone'],
  ['LOCAL_DATA_UPDATED_AT', 'localDataUpdatedAt'],
  ['LOCAL_SAVED_TOPIC_COUNT', 'localSavedTopicCount'],
  ['LOCAL_SAVED_NODE_COUNT', 'localSavedNodeCount'],
  ['LOCAL_VIEWED_TOPIC_COUNT', 'localViewedTopicCount'],
  ['FEED_TAB', 'feedTab'],
  ['FEED_TAB_KEYS', 'feedTabKeys'],
  ['FEED_TAB_VISUAL_INDEX', 'feedTabVisualIndex'],
  ['HOME_TAB_AUTO_HIDE', 'homeTabAutoHide'],
  ['TOPIC_DETAIL_REPLY_BUTTON_AUTO_HIDE', 'topicDetailReplyButtonAutoHide'],
  ['MOTION_HOLDING_HAND_SUPPORTED', 'motionHoldingHandSupported'],
  // Retired this lane (now V2-only in their AppStorageV2 'v2:*' holders, zero runtime readers):
  // the topic-detail + user-profile appbar identity keys (topicDetailSavedLater/SiteFavorited/Thanked,
  // topicDetailAppbar*, userProfileActions*/FollowLabel/BlockLabel/Following/Blocked, userProfileAppbar*),
  // motionHandEdge, pendingSearchQuery and accountWebViewUrl.
  ['NOTIFICATION_UNREAD_COUNT', 'notificationUnreadCount'],
  ['DISCOVER_NODE_KEYWORD', 'discoverNodeKeyword'],
]
assert(
  orderedStorageKeys.length === expectedStorageKeys.length,
  `StorageKeys declaration count changed: expected ${expectedStorageKeys.length}, got ${orderedStorageKeys.length}`,
)
for (let i = 0; i < expectedStorageKeys.length; i += 1) {
  const [expectedName, expectedValue] = expectedStorageKeys[i]
  const [actualName, actualValue] = orderedStorageKeys[i] || []
  assert(
    actualName === expectedName && actualValue === expectedValue,
    `StorageKeys declaration #${i + 1} changed: expected ${expectedName}='${expectedValue}', got ${actualName}='${actualValue}'`,
  )
}

// Retired two-factor AppStorage keys must not be reintroduced — the 2FA challenge state is V2-only in the
// AppStorageV2 'v2:twoFactor' holder (TwoFactorState). Guard both the constant names and their string values.
const retiredTwoFactorKeys = [
  ['TWO_FACTOR_REQUESTED_AT', 'twoFactorRequestedAt'],
  ['TWO_FACTOR_COMPLETED_AT', 'twoFactorCompletedAt'],
  ['TWO_FACTOR_VISIBLE', 'twoFactorVisible'],
  ['TWO_FACTOR_COOKIE', 'twoFactorCookie'],
  ['TWO_FACTOR_SOURCE', 'twoFactorSource'],
]
const storageValues = new Set(storageKeys.values())
for (const [retiredName, retiredValue] of retiredTwoFactorKeys) {
  assert(!storageKeys.has(retiredName), `StorageKeys must not reintroduce retired two-factor key ${retiredName} (V2-only)`)
  assert(!storageValues.has(retiredValue), `StorageKeys must not reintroduce retired two-factor value '${retiredValue}' (V2-only)`)
}

for (const heading of [
  'Persistent user settings / preferences-backed AppStorage',
  'Runtime window/layout state',
  'Navigation/action bus and page appbar state',
]) {
  assert(storageKeysText.includes(heading), `StorageKeys missing section comment: ${heading}`)
}

// Layout/safe-area metrics are V2-only: EntryAbility publishes window insets + keyboard height
// exclusively into the AppStorageV2 'v2:layoutSafeArea' mirror (LayoutSafeAreaState.ets). The
// legacy V1 AppStorage layout keys (topAvoidHeight/bottomAvoidHeight/keyboardHeight) and their
// dual-write were retired and the StorageKeys constants removed; guard against re-introducing the V1 half.
const layoutSafeAreaText = read('shared/src/main/ets/state/LayoutSafeAreaState.ets')
assert(layoutSafeAreaText.includes('AppStorageV2.connect'), 'LayoutSafeAreaState must connect the layout mirror via AppStorageV2')
assert(layoutSafeAreaText.includes("'v2:layoutSafeArea'"), "LayoutSafeAreaState must own the 'v2:layoutSafeArea' mirror key")
assert(!layoutSafeAreaText.includes('AppStorage.setOrCreate'), 'LayoutSafeAreaState must not dual-write layout metrics into legacy V1 AppStorage')
assert(!/import\s*\{[^}]*\bStorageKeys\b[^}]*\}/.test(layoutSafeAreaText), 'LayoutSafeAreaState must not import StorageKeys after retiring the V1 dual-write')
assert(layoutSafeAreaText.includes('state.topAvoidHeight !== topAvoidHeight'), 'LayoutSafeAreaBridge.publishInsets must avoid unchanged top inset writes')
assert(layoutSafeAreaText.includes('state.bottomAvoidHeight !== bottomAvoidHeight'), 'LayoutSafeAreaBridge.publishInsets must avoid unchanged bottom inset writes')
assert(layoutSafeAreaText.includes('state.keyboardHeight !== keyboardHeight'), 'LayoutSafeAreaBridge.publishKeyboardHeight must avoid unchanged keyboard writes')

const values = new Set(storageKeys.values())
const settingsDir = path.join(repo, 'shared/src/main/ets/settings')
const settingsFiles = fs.readdirSync(settingsDir)
  .filter((name) => name.endsWith('.ets') && name !== 'SettingsStorage.ets')
for (const file of settingsFiles) {
  const rel = `shared/src/main/ets/settings/${file}`
  const text = read(rel)
  const regex = /const\s+KEY_\w+\s*:\s*string\s*=\s*'([^']+)'/g
  let keyMatch
  while ((keyMatch = regex.exec(text)) !== null) {
    const nearby = text.slice(Math.max(0, keyMatch.index - 220), Math.min(text.length, keyMatch.index + 220)).toLowerCase()
    const documentedLegacy = nearby.includes('legacy') || nearby.includes('compatibility') || nearby.includes('兼容')
    assert(!values.has(keyMatch[1]) || documentedLegacy, `${rel} repeats StorageKeys value '${keyMatch[1]}' without legacy/compatibility comment`)
  }
  assert(!text.includes('private static setAppStorageValue'), `${rel} still declares private setAppStorageValue`)
}

const descriptorRel = 'shared/src/main/ets/settings/SettingsDescriptor.ets'
assert(fs.existsSync(path.join(repo, descriptorRel)), 'SettingsDescriptor.ets must exist')
const descriptorText = read(descriptorRel)
assert(/export\s+interface\s+SettingDescriptor\s*<\s*T\s*>/.test(descriptorText), 'SettingsDescriptor must export SettingDescriptor<T>')
assert(/export\s+function\s+readDescriptorValue\s*<\s*T\s*>/.test(descriptorText), 'SettingsDescriptor must export readDescriptorValue<T>')
assert(/export\s+function\s+applyDescriptorValue\s*<\s*T\s*>/.test(descriptorText), 'SettingsDescriptor must export applyDescriptorValue<T>')
assert(descriptorText.includes('SettingsPreferencesStore'), 'SettingsDescriptor.readDescriptorValue must use SettingsPreferencesStore')
assert(descriptorText.includes('setAppStorageValue<T>(descriptor.storageKey, normalized)'), 'SettingsDescriptor.applyDescriptorValue must apply normalized value through setAppStorageValue')
assert(!descriptorText.includes('getPreferences') && !descriptorText.includes('flushSync') && !descriptorText.includes('UIAbilityContext'), 'SettingsDescriptor must not own preferences save/context side effects')

const firstDescriptorSettings = [
  'AvatarAppearanceSettings.ets',
  'ReplyDisplaySettings.ets',
  'ReplyCardStyleSettings.ets',
  'ReplyActionAlignmentSettings.ets',
]
for (const file of firstDescriptorSettings) {
  const text = read(`shared/src/main/ets/settings/${file}`)
  assert(text.includes('SettingDescriptor'), `${file} must define a typed descriptor`)
  assert(text.includes('readDescriptorValue'), `${file} loadFromStore must read via descriptor`)
  assert(text.includes('applyDescriptorValue'), `${file} apply/save must apply via descriptor`)
  assert(text.includes('STORE_NAME_SETTINGS'), `${file} must keep shared STORE_NAME_SETTINGS`)
  assert(text.includes('SettingsPreferencesStore'), `${file} must keep SettingsPreferencesStore type`)
  assert(/static\s+async\s+loadFromStore\s*\(\s*store\s*:\s*SettingsPreferencesStore/.test(text), `${file} must expose static async loadFromStore(store: SettingsPreferencesStore...)`)
  const saveBody = extractMethodBody(text, 'save')
  assert(saveBody.includes('preferences.getPreferences(context, STORE_NAME)'), `${file} save path must still fetch preferences STORE_NAME`)
  assert(/store\.putSync\([^\n]+,\s*normalized\)/.test(saveBody), `${file} save path must still put normalized value`)
  assert(saveBody.includes('store.flushSync()'), `${file} save path must still flush synchronously`)
}

for (const file of [
  'ThemeSettings.ets',
  'ThemeColorSettings.ets',
  'ApiDomainSettings.ets',
  'MediaSettings.ets',
  'AutoDailyCheckinSettings.ets',
  'ReadingSettings.ets',
  'FeedTabSettings.ets',
  'CookieJarSettings.ets',
]) {
  const text = read(`shared/src/main/ets/settings/${file}`)
  assert(!text.includes('SettingDescriptor') && !text.includes('readDescriptorValue') && !text.includes('applyDescriptorValue'), `${file} must not be descriptorized in Phase2C`)
}

const storesRel = 'shared/src/main/ets/settings/SettingsStores.ets'
assert(fs.existsSync(path.join(repo, storesRel)), 'SettingsStores.ets must centralize Preferences store names')
const storesText = read(storesRel)
const storeNameRegex = /export\s+const\s+(STORE_NAME_\w+)\s*:\s*string\s*=\s*'([^']+)'/g
const orderedStoreNames = []
const storeNames = new Map()
while ((match = storeNameRegex.exec(storesText)) !== null) {
  orderedStoreNames.push([match[1], match[2]])
  storeNames.set(match[1], match[2])
}
const expectedStoreNames = [
  ['STORE_NAME_SETTINGS', 'next2v_settings'],
  ['STORE_NAME_AUTH', 'next2v_auth'],
  ['STORE_NAME_AUTH_SESSION', 'next2v_auth_session'],
  ['STORE_NAME_ACCOUNT_META', 'next2v_account_meta'],
  ['STORE_NAME_COOKIEJAR', 'next2v_cookiejar'],
  ['STORE_NAME_FEED_TABS', 'next2v_feed_tabs'],
  ['STORE_NAME_CACHE', 'next2v_cache'],
  ['STORE_NAME_COLLECTIONS', 'next2v_collections'],
  ['STORE_NAME_DRAFTS', 'next2v_drafts'],
  ['STORE_NAME_SEARCH', 'next2v_search'],
  ['STORE_NAME_NOTIFICATIONS', 'next2v_notifications'],
  ['STORE_NAME_ACCOUNTS', 'next2v_accounts'],
]
assert(
  orderedStoreNames.length === expectedStoreNames.length,
  `SettingsStores declaration count changed: expected ${expectedStoreNames.length}, got ${orderedStoreNames.length}`,
)
for (let i = 0; i < expectedStoreNames.length; i += 1) {
  const [expectedName, expectedValue] = expectedStoreNames[i]
  const [actualName, actualValue] = orderedStoreNames[i] || []
  assert(
    actualName === expectedName && actualValue === expectedValue,
    `SettingsStores declaration #${i + 1} changed: expected ${expectedName}='${expectedValue}', got ${actualName}='${actualValue}'`,
  )
}
const expectedStoreValues = new Set(expectedStoreNames.map(([, value]) => value))
for (const value of expectedStoreValues) {
  const occurrences = storesText.match(new RegExp(`'${value}'`, 'g')) || []
  assert(occurrences.length === 1, `SettingsStores must declare '${value}' exactly once`)
}
const storeOwners = new Map([
  ['AuthSettings.ets', 'STORE_NAME_AUTH'],
  ['AuthSessionSettings.ets', 'STORE_NAME_AUTH_SESSION'],
  ['AccountMetaSettings.ets', 'STORE_NAME_ACCOUNT_META'],
  ['CookieJarSettings.ets', 'STORE_NAME_COOKIEJAR'],
  ['FeedTabSettings.ets', 'STORE_NAME_FEED_TABS'],
  ['CacheSettings.ets', 'STORE_NAME_CACHE'],
  ['CollectionSettings.ets', 'STORE_NAME_COLLECTIONS'],
  ['DraftSettings.ets', 'STORE_NAME_DRAFTS'],
  ['SearchSettings.ets', 'STORE_NAME_SEARCH'],
  ['NotificationSettings.ets', 'STORE_NAME_NOTIFICATIONS'],
])
for (const [file, storeConst] of storeOwners.entries()) {
  const text = read(`shared/src/main/ets/settings/${file}`)
  assert(text.includes(`import { ${storeConst} } from './SettingsStores'`), `${file} must import ${storeConst} from SettingsStores`)
  assert(text.includes(`STORE_NAME: string = ${storeConst}`), `${file} must bind STORE_NAME to ${storeConst}`)
}
for (const file of settingsFiles) {
  if (file === 'SettingsStores.ets') continue
  const rel = `shared/src/main/ets/settings/${file}`
  const text = read(rel)
  for (const value of expectedStoreValues) {
    assert(!text.includes(`'${value}'`), `${rel} must not hard-code Preferences store name '${value}' outside SettingsStores`)
  }
}
const helperText = read('shared/src/main/ets/settings/SettingsStorage.ets')
assert(helperText.includes("export { STORE_NAME_SETTINGS } from './SettingsStores'"), 'SettingsStorage must re-export STORE_NAME_SETTINGS from SettingsStores')
assert(helperText.includes('type SettingsPreferencesStore = preferences.Preferences'), 'SettingsStorage must expose SettingsPreferencesStore preferences.Preferences alias')
assert(helperText.includes('function setAppStorageValue<T>'), 'SettingsStorage must expose setAppStorageValue<T>')
assert(helperText.includes('AppStorage.set<T>') && helperText.includes('AppStorage.setOrCreate<T>'), 'setAppStorageValue must use set fallback setOrCreate')
for (const helperName of ['withPreferencesStore', 'readJsonArray', 'readJsonObject', 'writeJsonValue', 'deleteKeysAndFlush']) {
  assert(helperText.includes(`function ${helperName}`), `SettingsStorage must expose ${helperName}`)
}
assert(helperText.includes('preferences.getPreferences(context, storeName)'), 'withPreferencesStore must fetch the requested storeName without changing store ownership')
assert(helperText.includes('JSON.parse') && helperText.includes('JSON.stringify'), 'JSON preferences helpers must own parse/stringify primitives')
assert(helperText.includes('store.flushSync()'), 'JSON preferences write/delete helpers must flush synchronously')

const jsonBusinessSettingsContracts = [
  ['SearchSettings.ets', 'STORE_NAME_SEARCH', ['withPreferencesStore']],
  ['DraftSettings.ets', 'STORE_NAME_DRAFTS', ['withPreferencesStore', 'readJsonArray', 'readJsonObject', 'writeJsonValue', 'deleteKeysAndFlush']],
]
for (const [file, storeConst, helpers] of jsonBusinessSettingsContracts) {
  const text = read(`shared/src/main/ets/settings/${file}`)
  assert(!text.includes("import { preferences } from '@kit.ArkData'"), `${file} must use SettingsStorage preferences helpers instead of direct preferences import`)
  assert(text.includes(`STORE_NAME: string = ${storeConst}`), `${file} must keep ${storeConst} store binding`)
  for (const helper of helpers) {
    assert(text.includes(helper), `${file} must use ${helper}`)
  }
}
assert(read('shared/src/main/ets/settings/DraftSettings.ets').includes("KEY_REPLY_DRAFTS: string = 'replyDrafts'"), 'DraftSettings replyDrafts key changed')
assert(read('shared/src/main/ets/settings/DraftSettings.ets').includes("KEY_TOPIC_DRAFT: string = 'topicDraft'"), 'DraftSettings topicDraft key changed')
assert(read('shared/src/main/ets/settings/SearchSettings.ets').includes("KEY_HISTORY: string = 'searchHistory'"), 'SearchSettings searchHistory key changed')
assert(read('shared/src/main/ets/settings/SearchSettings.ets').includes("LocalDataStore.open(context)"), 'SearchSettings searchHistory must use LocalDataStore RDB')

const next2vSettingsFiles = [
  'ApiDomainSettings.ets',
  'AvatarAppearanceSettings.ets',
  'MediaSettings.ets',
  'ReadingSettings.ets',
  'ThemeSettings.ets',
  'ThemeColorSettings.ets',
  'ReplyDisplaySettings.ets',
  'ReplyCardStyleSettings.ets',
  'ReplyActionAlignmentSettings.ets',
  'AutoDailyCheckinSettings.ets',
]

for (const file of next2vSettingsFiles) {
  const text = read(`shared/src/main/ets/settings/${file}`)
  assert(text.includes('STORE_NAME_SETTINGS'), `${file} must use shared STORE_NAME_SETTINGS`)
  assert(text.includes('SettingsPreferencesStore'), `${file} must use shared SettingsPreferencesStore type`)
  if (firstDescriptorSettings.includes(file)) {
    assert(text.includes('applyDescriptorValue'), `${file} must use descriptor AppStorage helper`)
  } else {
    assert(text.includes('setAppStorageValue'), `${file} must use shared AppStorage helper`)
  }
  assert(/static\s+async\s+loadFromStore\s*\(\s*store\s*:\s*SettingsPreferencesStore/.test(text), `${file} must expose static async loadFromStore(store: SettingsPreferencesStore...)`)
  const loadBody = extractMethodBody(text, 'load')
  assert(loadBody.includes('preferences.getPreferences(context, STORE_NAME)'), `${file} load(context) must still fetch STORE_NAME before delegating`)
  assert(loadBody.includes('.loadFromStore(store'), `${file} load(context) must delegate to loadFromStore(store)`)
  const saveBody = extractMethodBody(text, 'save')
  assert(saveBody.includes('preferences.getPreferences(context, STORE_NAME)'), `${file} save path must keep fetching preferences STORE_NAME`)
}

const readingSettings = read('shared/src/main/ets/settings/ReadingSettings.ets')
const legacyReadingStorageName = 'READING_' + 'FONT_SIZE'
const legacyReadingStorageValue = 'reading' + 'FontSize'
assert(storageKeys.get('READING_TEXT_SCALE') === 'readingTextScale', "StorageKeys.READING_TEXT_SCALE must be 'readingTextScale'")
assert(!storageKeys.has(legacyReadingStorageName), 'legacy reading storage constant must be removed')
for (const [name, value] of storageKeys.entries()) {
  assert(value !== legacyReadingStorageValue, `legacy reading storage value must be absent (${name})`)
}
assert(readingSettings.includes('const KEY_TEXT_SCALE: string = StorageKeys.READING_TEXT_SCALE'), 'ReadingSettings must use KEY_TEXT_SCALE')
assert(!readingSettings.includes('numeric > 2'), 'normalizeTextScale must not convert legacy font-size values')
assert(!readingSettings.includes('/ ThemeConstants.FONT_SIZE_BODY : numeric'), 'normalizeTextScale must be scale-only')

const normalizeTextScaleContract = (value) => {
  const numeric = Number(value)
  const min = 12 / 14
  const max = 18 / 14
  if (!Number.isFinite(numeric)) return 1.0
  if (numeric < min) return min
  if (numeric > max) return max
  return Math.round(numeric * 100) / 100
}
for (const [input, expected] of [
  [0.5, 12 / 14],
  [0.86, 0.86],
  [1, 1],
  [1.234, 1.23],
  [12, 18 / 14],
  [14, 18 / 14],
  [18, 18 / 14],
  [Number.NaN, 1.0],
]) {
  assert(Object.is(normalizeTextScaleContract(input), expected), `normalizeTextScale scale-only contract failed for ${input}`)
}

const sourceRoots = [
  'entry/src/main/ets',
  'feature/detail/src/main/ets',
  'feature/feed/src/main/ets',
  'feature/node/src/main/ets',
  'feature/settings/src/main/ets',
  'feature/user/src/main/ets',
  'shared/src/main/ets',
  'scripts',
]
const walkTextFiles = (dir) => {
  const results = []
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name)
    if (entry.isDirectory()) {
      results.push(...walkTextFiles(full))
    } else if (/\.(ets|ts|js|mjs)$/.test(entry.name)) {
      results.push(full)
    }
  }
  return results
}
for (const root of sourceRoots) {
  const absRoot = path.join(repo, root)
  if (!fs.existsSync(absRoot)) continue
  for (const abs of walkTextFiles(absRoot)) {
    const rel = path.relative(repo, abs)
    const text = fs.readFileSync(abs, 'utf8')
    assert(!text.includes(legacyReadingStorageName), `${rel} must not reference legacy reading storage constant`)
    assert(!text.includes(legacyReadingStorageValue), `${rel} must not reference legacy reading storage key`)
  }
}
for (const method of ['saveTypography', 'saveRestorePosition', 'saveBase64DecodeMode']) {
  const body = extractMethodBody(readingSettings, method)
  assert(body.includes('preferences.getPreferences(context, STORE_NAME)'), `ReadingSettings.${method} path must keep fetching preferences STORE_NAME`)
}
const autoDailyCheckinSettings = read('shared/src/main/ets/settings/AutoDailyCheckinSettings.ets')
for (const method of ['saveLastAttemptDate', 'saveLastSuccessDate']) {
  const body = extractMethodBody(autoDailyCheckinSettings, method)
  assert(body.includes('preferences.getPreferences(context, STORE_NAME)'), `AutoDailyCheckinSettings.${method} path must keep fetching preferences STORE_NAME`)
}

const feedTabText = read('shared/src/main/ets/settings/FeedTabSettings.ets')
assert(!feedTabText.includes('loadFromStore'), 'FeedTabSettings must not add loadFromStore')
assert(read('shared/src/main/ets/settings/FeedTabSettings.ets').includes('STORE_NAME: string = STORE_NAME_FEED_TABS'), 'FeedTabSettings must keep independent next2v_feed_tabs store via SettingsStores')
assert(read('shared/src/main/ets/settings/CookieJarSettings.ets').includes('STORE_NAME: string = STORE_NAME_COOKIEJAR'), 'CookieJarSettings must keep independent next2v_cookiejar store via SettingsStores')

const entry = read('entry/src/main/ets/entryability/EntryAbility.ets')
const bootstrapRel = 'shared/src/main/ets/settings/SettingsBootstrap.ets'
assert(fs.existsSync(path.join(repo, bootstrapRel)), 'SettingsBootstrap.ets must exist')
const bootstrap = read(bootstrapRel)
assert(/class\s+SettingsBootstrap/.test(bootstrap), 'SettingsBootstrap class missing')
assert(/static\s+async\s+loadAll\s*\(\s*context\s*:\s*common\.UIAbilityContext\s*\)\s*:\s*Promise<void>/.test(bootstrap), 'SettingsBootstrap.loadAll signature missing')
assert(bootstrap.includes('STORE_NAME_SETTINGS'), 'SettingsBootstrap must import/use STORE_NAME_SETTINGS')
assert(bootstrap.includes('SettingsPreferencesStore'), 'SettingsBootstrap must use SettingsPreferencesStore')
const loadAllBody = extractMethodBody(bootstrap, 'loadAll')
const settingsStorePrefetches = loadAllBody.match(/preferences\.getPreferences\(context, STORE_NAME_SETTINGS\)/g) || []
assert(settingsStorePrefetches.length === 1, `SettingsBootstrap must prefetch STORE_NAME_SETTINGS exactly once, got ${settingsStorePrefetches.length}`)
assert(!bootstrap.includes('settingsStore = undefined'), 'SettingsBootstrap must not abort or clear settingsStore after prefetch failure')
assert(entry.includes('SettingsBootstrap.loadAll(this.context)'), 'EntryAbility must call SettingsBootstrap.loadAll(this.context)')
assert(entry.includes('refreshSafeAreaInsets(win, uiCtx'), 'EntryAbility must centralize live safe-area refreshes')
assert(entry.includes("win.on('avoidAreaChange'"), 'EntryAbility must refresh safe-area insets on avoidAreaChange')
assert(entry.includes("win.on('windowSizeChange'"), 'EntryAbility must refresh safe-area insets on windowSizeChange')
assert(entry.includes("win.off('avoidAreaChange'"), 'EntryAbility must unregister avoidAreaChange listener')
assert(entry.includes("win.off('windowSizeChange'"), 'EntryAbility must unregister windowSizeChange listener')
assert(entry.includes('TYPE_SYSTEM') && entry.includes('TYPE_NAVIGATION_INDICATOR'), 'EntryAbility safe-area refresh must re-read system and navigation avoid areas')
assert(entry.includes('TYPE_SYSTEM_GESTURE') && entry.includes('TYPE_CUTOUT'), 'EntryAbility bottom safe-area refresh must include gesture and cutout avoid areas')
assert(entry.includes('_settled'), 'EntryAbility must schedule a settled safe-area refresh after window geometry changes')
const loadAllIndex = entry.indexOf('SettingsBootstrap.loadAll(this.context)')
const finallyIndex = entry.indexOf('.finally', loadAllIndex)
const loadContentIndex = entry.indexOf('this.loadContent(windowStage, win)', loadAllIndex)
assert(finallyIndex !== -1, 'EntryAbility SettingsBootstrap.loadAll must use finally before loadContent')
assert(loadContentIndex !== -1, 'EntryAbility must load content after SettingsBootstrap.loadAll')
assert(finallyIndex > loadAllIndex && loadContentIndex > finallyIndex, 'EntryAbility loadContent must be in or after SettingsBootstrap.loadAll finally')

const loadAllHelperSequence = [
  'restoreApiDomain',
  'restoreThemeColor',
  'restoreTheme',
  'restoreAvatarAppearance',
  'restoreMedia',
  'restoreReplyDisplay',
  'restoreReading',
  'restoreFeedTabs',
  'restoreCookieJar',
  'restoreAutoDailyCheckin',
  'triggerStartupCheckin',
  'restoreReplyCardStyle',
  'restoreReplyActionAlignment',
]
let previousIndex = -1
for (const helper of loadAllHelperSequence) {
  const call = `SettingsBootstrap.${helper}(`
  const index = loadAllBody.indexOf(call, previousIndex + 1)
  assert(index !== -1, `SettingsBootstrap.loadAll no longer calls ${helper}`)
  assert(index > previousIndex, `SettingsBootstrap.loadAll helper order changed near ${helper}`)
  previousIndex = index
}
assert(!/await\s+SettingsBootstrap\.triggerStartupCheckin\s*\(/.test(loadAllBody), 'SettingsBootstrap.triggerStartupCheckin must not be awaited')
assert(!/await\s+AutoDailyCheckinService\.tryCheckin/.test(bootstrap), 'AutoDailyCheckinService.tryCheckin must remain fire-and-forget')

const helperContracts = [
  {
    name: 'restoreApiDomain',
    required: [
      'ApiDomainSettings.loadFromStore(settingsStore)',
      'ApiDomainSettings.load(context)',
      ').catch',
      'restore api domain failed: ',
      "ApiDomainSettings.apply('https://www.v2ex.com')",
    ],
  },
  {
    name: 'restoreThemeColor',
    required: [
      'ThemeColorSettings.loadFromStore(settingsStore)',
      'ThemeColorSettings.load(context)',
      ').catch',
      'restore theme color settings failed: ',
      'ThemeColorSettings.apply(ThemeColorSettings.DEFAULT_COLOR)',
    ],
  },
  {
    name: 'restoreTheme',
    required: [
      'ThemeSettings.loadFromStore(settingsStore, context)',
      'ThemeSettings.load(context)',
      ').catch',
      'restore theme settings failed: ',
      'ThemeSettings.apply(context, ThemeSettings.MODE_AUTO)',
    ],
  },
  {
    name: 'restoreAvatarAppearance',
    required: [
      'AvatarAppearanceSettings.loadFromStore(settingsStore)',
      'AvatarAppearanceSettings.load(context)',
      ').catch',
      'restore avatar appearance failed: ',
      'AvatarAppearanceSettings.apply(AvatarAppearanceSettings.APPEARANCE_SOFT)',
    ],
  },
  {
    name: 'restoreMedia',
    required: [
      'MediaSettings.loadFromStore(settingsStore)',
      'MediaSettings.load(context)',
      ').catch',
      'restore media settings failed: ',
      'MediaSettings.apply(true, false)',
    ],
  },
  {
    name: 'restoreReplyDisplay',
    required: [
      'ReplyDisplaySettings.loadFromStore(settingsStore)',
      'ReplyDisplaySettings.load(context)',
      ').catch',
      'restore reply display settings failed: ',
      'ReplyDisplaySettings.apply(ReplyDisplaySettings.MODE_THREAD)',
    ],
  },
  {
    name: 'restoreReading',
    required: [
      'ReadingSettings.loadFromStore(settingsStore)',
      'ReadingSettings.load(context)',
      ').catch',
      'restore reading settings failed: ',
      // The fallback apply args are formatted across multiple lines; assert the call + each argument
      // independently (same intent: apply(TEXT_SCALE_DEFAULT, 20, DENSITY_STANDARD) on load failure).
      'ReadingSettings.apply(',
      'ReadingSettings.TEXT_SCALE_DEFAULT',
      'ReadingSettings.DENSITY_STANDARD',
    ],
  },
  {
    name: 'restoreFeedTabs',
    required: [
      'FeedTabSettings.load(context).catch',
      'restore feed tab settings failed: ',
      'FeedTabSettings.apply(FeedTabSettings.defaultKeysJson())',
    ],
  },
  {
    name: 'restoreCookieJar',
    required: [
      'CookieJarSettings.load(context).catch',
      'restore cookie jar failed: ',
      'CookieJarSettings.apply({',
      'cookiesByBaseUrl: {},',
      'updatedAt: 0',
    ],
  },
  {
    name: 'restoreAutoDailyCheckin',
    required: [
      'AutoDailyCheckinSettings.loadFromStore(settingsStore)',
      'AutoDailyCheckinSettings.load(context)',
      ').catch',
      'restore auto daily check-in setting failed: ',
      'AutoDailyCheckinSettings.apply(true)',
    ],
  },
  {
    name: 'triggerStartupCheckin',
    required: [
      'AutoDailyCheckinService.tryCheckin(',
      'CookieJarSettings.getCurrentCookie()',
      "'startup'",
      '.catch((error: Error) => {',
      'auto daily check-in startup trigger failed: ',
    ],
  },
  {
    name: 'restoreReplyCardStyle',
    required: [
      'ReplyCardStyleSettings.loadFromStore(settingsStore)',
      'ReplyCardStyleSettings.load(context)',
      ').catch',
      'restore reply card style failed: ',
      'ReplyCardStyleSettings.apply(ReplyCardStyleSettings.STYLE_STANDARD)',
    ],
  },
  {
    name: 'restoreReplyActionAlignment',
    required: [
      'ReplyActionAlignmentSettings.loadFromStore(settingsStore)',
      'ReplyActionAlignmentSettings.load(context)',
      ').catch',
      'restore reply action alignment failed: ',
      'ReplyActionAlignmentSettings.apply(ReplyActionAlignmentSettings.MODE_UNSET)',
    ],
  },
]
for (const contract of helperContracts) {
  const helperBody = extractMethodBody(bootstrap, contract.name)
  for (const required of contract.required) {
    assert(helperBody.includes(required), `SettingsBootstrap.${contract.name} missing preserved load/catch/fallback/log string: ${required}`)
  }
}

const media = read('shared/src/main/ets/settings/MediaSettings.ets')
assert(media.includes("KEY_AUTO_LOAD_IMAGES: string = 'autoLoadImages'"), 'MediaSettings legacy autoLoadImages preferences key changed')
assert(media.includes("KEY_ONLY_LOAD_IMAGES_ON_WIFI: string = 'onlyLoadImagesOnWifi'"), 'MediaSettings legacy onlyLoadImagesOnWifi preferences key changed')
assert(/legacy|compatibility|兼容/i.test(media), 'MediaSettings legacy key compatibility comment missing')

console.log('settings storage contract OK')
