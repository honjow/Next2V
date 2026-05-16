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
  ['TOP_AVOID_HEIGHT', 'topAvoidHeight'],
  ['BOTTOM_AVOID_HEIGHT', 'bottomAvoidHeight'],
  ['KEYBOARD_HEIGHT', 'keyboardHeight'],
  ['NAV_PATH_STACK', 'ns'],
  ['USE_CO_DOMAIN', 'useCoDomain'],
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
  ['THEME_MODE', 'themeMode'],
  ['THEME_EFFECTIVE_DARK', 'themeEffectiveDark'],
  ['TOPIC_READ_STATES', 'topicReadStates'],
  ['AUTH_TOKEN_CONFIGURED', 'authTokenConfigured'],
  ['AUTH_USERNAME', 'authUsername'],
  ['AUTH_COOKIE_CONFIGURED', 'authCookieConfigured'],
  ['AUTH_LOGIN_MODE', 'authLoginMode'],
  ['AUTH_SESSION_USERNAME', 'authSessionUsername'],
  ['AUTH_SESSION_AVATAR', 'authSessionAvatar'],
  ['AUTH_SESSION_VALIDATED_AT', 'authSessionValidatedAt'],
  ['AUTH_SESSION_UPDATED_AT', 'authSessionUpdatedAt'],
  ['AUTO_DAILY_CHECKIN_ENABLED', 'autoDailyCheckinEnabled'],
  ['AUTO_DAILY_CHECKIN_LAST_ATTEMPT_DATE', 'autoDailyCheckinLastAttemptDate'],
  ['AUTO_DAILY_CHECKIN_LAST_ATTEMPT_IDENTITY', 'autoDailyCheckinLastAttemptIdentity'],
  ['AUTO_DAILY_CHECKIN_LAST_SUCCESS_DATE', 'autoDailyCheckinLastSuccessDate'],
  ['API_RATE_LIMIT_LIMIT', 'apiRateLimitLimit'],
  ['API_RATE_LIMIT_REMAINING', 'apiRateLimitRemaining'],
  ['API_RATE_LIMIT_RESET', 'apiRateLimitReset'],
  ['API_RATE_LIMIT_UPDATED_AT', 'apiRateLimitUpdatedAt'],
  ['LOCAL_DATA_UPDATED_AT', 'localDataUpdatedAt'],
  ['LOCAL_SAVED_TOPIC_COUNT', 'localSavedTopicCount'],
  ['LOCAL_SAVED_NODE_COUNT', 'localSavedNodeCount'],
  ['LOCAL_VIEWED_TOPIC_COUNT', 'localViewedTopicCount'],
  ['FEED_TAB', 'feedTab'],
  ['FEED_TAB_KEYS', 'feedTabKeys'],
  ['FEED_TAB_VISUAL_INDEX', 'feedTabVisualIndex'],
  ['BLOCKED_MEMBERS_UPDATED_AT', 'blockedMembersUpdatedAt'],
  ['MOTION_HAND_EDGE', 'motionHandEdge'],
  ['MOTION_HOLDING_HAND_SUPPORTED', 'motionHoldingHandSupported'],
  ['TOPIC_DETAIL_ACTION', 'topicDetailAction'],
  ['TOPIC_DETAIL_SAVED_LATER', 'topicDetailSavedLater'],
  ['TOPIC_DETAIL_SITE_FAVORITED', 'topicDetailSiteFavorited'],
  ['TOPIC_DETAIL_THANKED', 'topicDetailThanked'],
  ['TOPIC_DETAIL_APPBAR_TITLE', 'topicDetailAppbarTitle'],
  ['TOPIC_DETAIL_APPBAR_AVATAR_URL', 'topicDetailAppbarAvatarUrl'],
  ['TOPIC_DETAIL_APPBAR_USERNAME', 'topicDetailAppbarUsername'],
  ['TOPIC_DETAIL_APPBAR_ROUTE_TOPIC_ID', 'topicDetailAppbarRouteTopicId'],
  ['TOPIC_DETAIL_APPBAR_TITLE_STATES', 'topicDetailAppbarTitleStates'],
  ['TOPIC_DETAIL_APPBAR_AVATAR_STATES', 'topicDetailAppbarAvatarStates'],
  ['TOPIC_DETAIL_APPBAR_USERNAME_STATES', 'topicDetailAppbarUsernameStates'],
  ['NODE_TOPIC_ACTION', 'nodeTopicAction'],
  ['NODE_TOPIC_TITLE', 'nodeTopicTitle'],
  ['NODE_TOPIC_SUBTITLE', 'nodeTopicSubtitle'],
  ['NODE_TOPIC_SAVED', 'nodeTopicSaved'],
  ['NODE_TOPIC_SITE_FAVORITED', 'nodeTopicSiteFavorited'],
  ['USER_PROFILE_ACTION', 'userProfileAction'],
  ['USER_PROFILE_ACTIONS_USERNAME', 'userProfileActionsUsername'],
  ['USER_PROFILE_ACTIONS_AVAILABLE', 'userProfileActionsAvailable'],
  ['USER_PROFILE_FOLLOW_LABEL', 'userProfileFollowLabel'],
  ['USER_PROFILE_BLOCK_LABEL', 'userProfileBlockLabel'],
  ['USER_PROFILE_FOLLOWING', 'userProfileFollowing'],
  ['USER_PROFILE_BLOCKED', 'userProfileBlocked'],
  ['USER_PROFILE_APPBAR_TITLE_USERNAME', 'userProfileAppbarTitleUsername'],
  ['USER_PROFILE_APPBAR_TITLE_AVATAR_URL', 'userProfileAppbarTitleAvatarUrl'],
  ['USER_PROFILE_APPBAR_TITLE_ROUTE_USERNAME', 'userProfileAppbarTitleRouteUsername'],
  ['USER_PROFILE_APPBAR_TITLE_STATES', 'userProfileAppbarTitleStates'],
  ['USER_PROFILE_APPBAR_AVATAR_STATES', 'userProfileAppbarAvatarStates'],
  ['USER_PROFILE_SHOWN', 'userProfileShown'],
  ['NOTIFICATION_ACTION', 'notificationAction'],
  ['SEARCH_ACTION', 'searchAction'],
  ['WEB_LOGIN_ACTION', 'webLoginAction'],
  ['IMAGE_PREVIEW_ACTION', 'imagePreviewAction'],
  ['PENDING_V2EX_URL', 'pendingV2exUrl'],
  ['PENDING_SEARCH_QUERY', 'pendingSearchQuery'],
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

for (const heading of [
  'Persistent user settings / preferences-backed AppStorage',
  'Runtime window/layout state',
  'Navigation/action bus and page appbar state',
]) {
  assert(storageKeysText.includes(heading), `StorageKeys missing section comment: ${heading}`)
}

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

const helperText = read('shared/src/main/ets/settings/SettingsStorage.ets')
assert(helperText.includes("STORE_NAME_SETTINGS: string = 'next2v_settings'"), 'SettingsStorage must expose STORE_NAME_SETTINGS')
assert(helperText.includes('type SettingsPreferencesStore = preferences.Preferences'), 'SettingsStorage must expose SettingsPreferencesStore preferences.Preferences alias')
assert(helperText.includes('function setAppStorageValue<T>'), 'SettingsStorage must expose setAppStorageValue<T>')
assert(helperText.includes('AppStorage.set<T>') && helperText.includes('AppStorage.setOrCreate<T>'), 'setAppStorageValue must use set fallback setOrCreate')

const next2vSettingsFiles = [
  'ApiDomainSettings.ets',
  'MediaSettings.ets',
  'ReadingSettings.ets',
  'ThemeSettings.ets',
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

for (const file of ['FeedTabSettings.ets', 'CookieJarSettings.ets']) {
  const text = read(`shared/src/main/ets/settings/${file}`)
  assert(!text.includes('loadFromStore'), `${file} must not add loadFromStore`)
}
assert(read('shared/src/main/ets/settings/FeedTabSettings.ets').includes("STORE_NAME: string = 'next2v_feed_tabs'"), 'FeedTabSettings must keep independent next2v_feed_tabs store')
assert(read('shared/src/main/ets/settings/CookieJarSettings.ets').includes("STORE_NAME: string = 'next2v_cookiejar'"), 'CookieJarSettings must keep independent next2v_cookiejar store')

const entry = read('entry/src/main/ets/entryability/EntryAbility.ets')
const bootstrapRel = 'shared/src/main/ets/settings/SettingsBootstrap.ets'
assert(fs.existsSync(path.join(repo, bootstrapRel)), 'SettingsBootstrap.ets must exist')
const bootstrap = read(bootstrapRel)
assert(/class\s+SettingsBootstrap/.test(bootstrap), 'SettingsBootstrap class missing')
assert(/static\s+async\s+loadAll\s*\(\s*context\s*:\s*common\.UIAbilityContext\s*\)\s*:\s*Promise<void>/.test(bootstrap), 'SettingsBootstrap.loadAll signature missing')
assert(bootstrap.includes('STORE_NAME_SETTINGS'), 'SettingsBootstrap must import/use STORE_NAME_SETTINGS')
assert(bootstrap.includes('SettingsPreferencesStore'), 'SettingsBootstrap must use SettingsPreferencesStore')
const settingsStorePrefetches = bootstrap.match(/preferences\.getPreferences\(context, STORE_NAME_SETTINGS\)/g) || []
assert(settingsStorePrefetches.length === 1, `SettingsBootstrap must prefetch STORE_NAME_SETTINGS exactly once, got ${settingsStorePrefetches.length}`)
assert(!bootstrap.includes('settingsStore = undefined'), 'SettingsBootstrap must not abort or clear settingsStore after prefetch failure')
assert(entry.includes('SettingsBootstrap.loadAll(this.context)'), 'EntryAbility must call SettingsBootstrap.loadAll(this.context)')
const loadAllIndex = entry.indexOf('SettingsBootstrap.loadAll(this.context)')
const finallyIndex = entry.indexOf('.finally', loadAllIndex)
const loadContentIndex = entry.indexOf('this.loadContent(windowStage, win)', loadAllIndex)
assert(finallyIndex !== -1, 'EntryAbility SettingsBootstrap.loadAll must use finally before loadContent')
assert(loadContentIndex !== -1, 'EntryAbility must load content after SettingsBootstrap.loadAll')
assert(finallyIndex > loadAllIndex && loadContentIndex > finallyIndex, 'EntryAbility loadContent must be in or after SettingsBootstrap.loadAll finally')

const loadAllBody = extractMethodBody(bootstrap, 'loadAll')
const loadAllHelperSequence = [
  'restoreApiDomain',
  'restoreTheme',
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
      'ApiDomainSettings.apply(false)',
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
      'ReadingSettings.apply(ReadingSettings.TEXT_SCALE_DEFAULT, 20, ReadingSettings.DENSITY_STANDARD)',
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
      "comCookie: ''",
      "coCookie: ''",
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

