/** AppStorage key constants to avoid cross-module hard-coded strings */
export class StorageKeys {
  // Runtime window/layout state
  // NOTE: the former TOP_AVOID_HEIGHT / BOTTOM_AVOID_HEIGHT / KEYBOARD_HEIGHT
  // ('topAvoidHeight' / 'bottomAvoidHeight' / 'keyboardHeight') legacy AppStorage keys were removed —
  // they had zero runtime consumers after the safe-area V2 migration. Window insets + keyboard height
  // now live in the AppStorageV2 'v2:layoutSafeArea' mirror (LayoutSafeAreaState.ets); EntryAbility is
  // the sole publisher and no longer dual-writes them into V1 AppStorage. Do not reintroduce these keys.
  // NOTE: the former NAV_PATH_STACK ('ns') legacy AppStorage key was removed — it had zero runtime
  // consumers. The nav stack now lives in the AppStorageV2 'v2:navStack' holder (NavStackHolder.ets);
  // do not reintroduce a legacy 'ns' AppStorage key.

  // Persistent user settings / preferences-backed AppStorage
  static readonly USE_CO_DOMAIN: string = 'useCoDomain'
  static readonly SELECTED_BASE_URL: string = 'selectedBaseUrl'
  static readonly MEDIA_AUTO_LOAD_IMAGES: string = 'mediaAutoLoadImages'
  static readonly MEDIA_ONLY_LOAD_IMAGES_ON_WIFI: string = 'mediaOnlyLoadImagesOnWifi'
  static readonly READING_TEXT_SCALE: string = 'readingTextScale'
  static readonly READING_LINE_HEIGHT: string = 'readingLineHeight'
  static readonly READING_DENSITY: string = 'readingDensity'
  static readonly READING_RESTORE_POSITION: string = 'readingRestorePosition'
  static readonly READING_BASE64_DECODE_MODE: string = 'readingBase64DecodeMode'
  static readonly REPLY_DISPLAY_MODE: string = 'replyDisplayMode'
  static readonly REPLY_CARD_STYLE: string = 'replyCardStyle'
  static readonly REPLY_ACTION_ALIGNMENT_MODE: string = 'replyActionAlignmentMode'
  static readonly AVATAR_APPEARANCE: string = 'avatarAppearance'
  static readonly THEME_MODE: string = 'themeMode'
  static readonly THEME_EFFECTIVE_DARK: string = 'themeEffectiveDark'
  static readonly SYSTEM_COLOR_MODE: string = 'systemColorMode'
  static readonly LANGUAGE_MODE: string = 'languageMode'
  static readonly DIAGNOSTICS_ENABLED: string = 'diagnosticsEnabled'
  static readonly DIAGNOSTICS_MIN_LEVEL: string = 'diagnosticsMinLevel'
  static readonly NETWORK_PROXY_MODE: string = 'networkProxyMode'
  static readonly NETWORK_PROXY_HOST: string = 'networkProxyHost'
  static readonly NETWORK_PROXY_PORT: string = 'networkProxyPort'
  static readonly NETWORK_PROXY_SCHEME: string = 'networkProxyScheme'
  static readonly NETWORK_PROXY_USERNAME: string = 'networkProxyUsername'
  static readonly NETWORK_PROXY_PASSWORD: string = 'networkProxyPassword'
  static readonly NETWORK_PROXY_EXCLUSION_LIST: string = 'networkProxyExclusionList'

  // Auth/session state
  static readonly TOPIC_READ_STATES: string = 'topicReadStates'
  static readonly AUTH_TOKEN_CONFIGURED: string = 'authTokenConfigured'
  static readonly AUTH_USERNAME: string = 'authUsername'
  static readonly AUTH_COOKIE_CONFIGURED: string = 'authCookieConfigured'
  static readonly AUTH_LOGIN_MODE: string = 'authLoginMode'
  static readonly AUTH_SESSION_USERNAME: string = 'authSessionUsername'
  static readonly AUTH_SESSION_AVATAR: string = 'authSessionAvatar'
  static readonly AUTH_SESSION_VALIDATED_AT: string = 'authSessionValidatedAt'
  static readonly AUTH_SESSION_UPDATED_AT: string = 'authSessionUpdatedAt'
  static readonly ACTIVE_ACCOUNT_ID: string = 'activeAccountId'
  static readonly BLOCKED_LIST_OWNER_KEY: string = 'blockedListOwnerKey'
  static readonly BLOCKED_LIST_IGNORED_TOPIC_IDS: string = 'blockedListIgnoredTopicIds'
  static readonly BLOCKED_LIST_BLOCKED_MEMBER_IDS: string = 'blockedListBlockedMemberIds'
  static readonly BLOCKED_LIST_BLOCKED_MEMBER_METAS: string = 'blockedListBlockedMemberMetas'
  static readonly BLOCKED_LIST_IGNORED_TOPIC_METAS: string = 'blockedListIgnoredTopicMetas'
  static readonly BLOCKED_LIST_UPDATED_AT: string = 'blockedListUpdatedAt'
  static readonly BLOCKED_LIST_SELECTED_TAB: string = 'blockedListSelectedTab'
  static readonly TWO_FACTOR_VISIBLE: string = 'twoFactorVisible'
  static readonly TWO_FACTOR_COOKIE: string = 'twoFactorCookie'
  static readonly TWO_FACTOR_SOURCE: string = 'twoFactorSource'
  static readonly TWO_FACTOR_REQUESTED_AT: string = 'twoFactorRequestedAt'
  static readonly TWO_FACTOR_COMPLETED_AT: string = 'twoFactorCompletedAt'

  // Auto daily check-in state
  static readonly AUTO_DAILY_CHECKIN_ENABLED: string = 'autoDailyCheckinEnabled'
  static readonly AUTO_DAILY_CHECKIN_LAST_ATTEMPT_DATE: string = 'autoDailyCheckinLastAttemptDate'
  static readonly AUTO_DAILY_CHECKIN_LAST_ATTEMPT_IDENTITY: string =
    'autoDailyCheckinLastAttemptIdentity'
  static readonly AUTO_DAILY_CHECKIN_LAST_SUCCESS_DATE: string = 'autoDailyCheckinLastSuccessDate'

  // NOTE: the former API_RATE_LIMIT_* ('apiRateLimit*') legacy AppStorage keys were removed — they
  // had zero runtime consumers after the api-rate-limit V2 slice. The rate-limit snapshot now lives
  // in the AppStorageV2 'v2:apiRateLimit' store (ApiRateLimitState.ets); do not reintroduce legacy
  // API_RATE_LIMIT AppStorage keys.

  // Local data/cache metadata
  static readonly LOCAL_DATA_UPDATED_AT: string = 'localDataUpdatedAt'
  static readonly LOCAL_SAVED_TOPIC_COUNT: string = 'localSavedTopicCount'
  static readonly LOCAL_SAVED_NODE_COUNT: string = 'localSavedNodeCount'
  static readonly LOCAL_VIEWED_TOPIC_COUNT: string = 'localViewedTopicCount'

  // Feed tabs and motion state
  static readonly FEED_TAB: string = 'feedTab'
  static readonly FEED_TAB_KEYS: string = 'feedTabKeys'
  static readonly FEED_TAB_VISUAL_INDEX: string = 'feedTabVisualIndex'
  static readonly HOME_TAB_AUTO_HIDE: string = 'homeTabAutoHide'
  static readonly TOPIC_DETAIL_REPLY_BUTTON_AUTO_HIDE: string = 'topicDetailReplyButtonAutoHide'
  static readonly MOTION_HAND_EDGE: string = 'motionHandEdge'
  static readonly MOTION_HOLDING_HAND_SUPPORTED: string = 'motionHoldingHandSupported'

  // Navigation/action bus and page appbar state
  // NOTE: the transient action-bus + pending-deep-link AppStorage keys (topicDetailAction,
  // nodeTopicAction, userProfileAction, userProfileShown, notificationAction, searchAction,
  // webLoginAction, nativeLoginShown, imagePreviewAction, accountWebViewAction, pendingV2exUrl) and the
  // node-topic appbar OUTPUT keys (nodeTopicTitle/Subtitle/Saved/SiteFavorited) were removed — they had
  // zero runtime readers after the action/appbar V2 slice; each now lives only in its AppStorageV2
  // 'v2:*' holder. Do not reintroduce the legacy V1 keys. The TOPIC_DETAIL_APPBAR_* / USER_PROFILE_*
  // appbar identity keys below remain (their pages still read them back imperatively).
  static readonly TOPIC_DETAIL_SAVED_LATER: string = 'topicDetailSavedLater'
  static readonly TOPIC_DETAIL_SITE_FAVORITED: string = 'topicDetailSiteFavorited'
  static readonly TOPIC_DETAIL_THANKED: string = 'topicDetailThanked'
  static readonly TOPIC_DETAIL_APPBAR_TITLE: string = 'topicDetailAppbarTitle'
  static readonly TOPIC_DETAIL_APPBAR_AVATAR_URL: string = 'topicDetailAppbarAvatarUrl'
  static readonly TOPIC_DETAIL_APPBAR_USERNAME: string = 'topicDetailAppbarUsername'
  static readonly TOPIC_DETAIL_APPBAR_ROUTE_TOPIC_ID: string = 'topicDetailAppbarRouteTopicId'
  static readonly TOPIC_DETAIL_APPBAR_TITLE_STATES: string = 'topicDetailAppbarTitleStates'
  static readonly TOPIC_DETAIL_APPBAR_AVATAR_STATES: string = 'topicDetailAppbarAvatarStates'
  static readonly TOPIC_DETAIL_APPBAR_USERNAME_STATES: string = 'topicDetailAppbarUsernameStates'
  static readonly USER_PROFILE_ACTIONS_USERNAME: string = 'userProfileActionsUsername'
  static readonly USER_PROFILE_ACTIONS_AVAILABLE: string = 'userProfileActionsAvailable'
  static readonly USER_PROFILE_FOLLOW_LABEL: string = 'userProfileFollowLabel'
  static readonly USER_PROFILE_BLOCK_LABEL: string = 'userProfileBlockLabel'
  static readonly USER_PROFILE_FOLLOWING: string = 'userProfileFollowing'
  static readonly USER_PROFILE_BLOCKED: string = 'userProfileBlocked'
  static readonly USER_PROFILE_APPBAR_TITLE_USERNAME: string = 'userProfileAppbarTitleUsername'
  static readonly USER_PROFILE_APPBAR_TITLE_AVATAR_URL: string = 'userProfileAppbarTitleAvatarUrl'
  static readonly USER_PROFILE_APPBAR_TITLE_ROUTE_USERNAME: string =
    'userProfileAppbarTitleRouteUsername'
  static readonly USER_PROFILE_APPBAR_TITLE_STATES: string = 'userProfileAppbarTitleStates'
  static readonly USER_PROFILE_APPBAR_AVATAR_STATES: string = 'userProfileAppbarAvatarStates'
  static readonly NOTIFICATION_UNREAD_COUNT: string = 'notificationUnreadCount'
  static readonly PENDING_SEARCH_QUERY: string = 'pendingSearchQuery'
  static readonly DISCOVER_NODE_KEYWORD: string = 'discoverNodeKeyword'
  static readonly ACCOUNT_WEB_VIEW_URL: string = 'accountWebViewUrl'
}
