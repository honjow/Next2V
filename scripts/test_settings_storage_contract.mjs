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
  ['READING_FONT_SIZE', 'readingFontSize'],
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

const helperText = read('shared/src/main/ets/settings/SettingsStorage.ets')
assert(helperText.includes("STORE_NAME_SETTINGS: string = 'next2v_settings'"), 'SettingsStorage must expose STORE_NAME_SETTINGS')
assert(helperText.includes('function setAppStorageValue<T>'), 'SettingsStorage must expose setAppStorageValue<T>')
assert(helperText.includes('AppStorage.set<T>') && helperText.includes('AppStorage.setOrCreate<T>'), 'setAppStorageValue must use set fallback setOrCreate')

for (const file of [
  'ApiDomainSettings.ets',
  'MediaSettings.ets',
  'ReadingSettings.ets',
  'ThemeSettings.ets',
  'ReplyDisplaySettings.ets',
  'ReplyCardStyleSettings.ets',
  'ReplyActionAlignmentSettings.ets',
  'AutoDailyCheckinSettings.ets',
]) {
  const text = read(`shared/src/main/ets/settings/${file}`)
  assert(text.includes('STORE_NAME_SETTINGS'), `${file} must use shared STORE_NAME_SETTINGS`)
  assert(text.includes('setAppStorageValue'), `${file} must use shared AppStorage helper`)
}

const entry = read('entry/src/main/ets/entryability/EntryAbility.ets')
const bootstrapRel = 'shared/src/main/ets/settings/SettingsBootstrap.ets'
assert(fs.existsSync(path.join(repo, bootstrapRel)), 'SettingsBootstrap.ets must exist')
const bootstrap = read(bootstrapRel)
assert(/class\s+SettingsBootstrap/.test(bootstrap), 'SettingsBootstrap class missing')
assert(/static\s+async\s+loadAll\s*\(\s*context\s*:\s*common\.UIAbilityContext\s*\)\s*:\s*Promise<void>/.test(bootstrap), 'SettingsBootstrap.loadAll signature missing')
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
      'ApiDomainSettings.load(context).catch',
      'restore api domain failed: ',
      'ApiDomainSettings.apply(false)',
    ],
  },
  {
    name: 'restoreTheme',
    required: [
      'ThemeSettings.load(context).catch',
      'restore theme settings failed: ',
      'ThemeSettings.apply(context, ThemeSettings.MODE_AUTO)',
    ],
  },
  {
    name: 'restoreMedia',
    required: [
      'MediaSettings.load(context).catch',
      'restore media settings failed: ',
      'MediaSettings.apply(true, false)',
    ],
  },
  {
    name: 'restoreReplyDisplay',
    required: [
      'ReplyDisplaySettings.load(context).catch',
      'restore reply display settings failed: ',
      'ReplyDisplaySettings.apply(ReplyDisplaySettings.MODE_THREAD)',
    ],
  },
  {
    name: 'restoreReading',
    required: [
      'ReadingSettings.load(context).catch',
      'restore reading settings failed: ',
      'ReadingSettings.apply(14, 20, ReadingSettings.DENSITY_STANDARD)',
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
      'AutoDailyCheckinSettings.load(context).catch',
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
      'ReplyCardStyleSettings.load(context).catch',
      'restore reply card style failed: ',
      'ReplyCardStyleSettings.apply(ReplyCardStyleSettings.STYLE_STANDARD)',
    ],
  },
  {
    name: 'restoreReplyActionAlignment',
    required: [
      'ReplyActionAlignmentSettings.load(context).catch',
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

