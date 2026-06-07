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
  static readonly THEME_COLOR: string = 'themeColor'
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
  // NOTE: the global 2FA challenge sheet state is V2-only — it lives in its AppStorageV2 'v2:twoFactor'
  // holder (TwoFactorState). TwoFactorChallengeService is the single writer (via the publish* helpers) and
  // @ComponentV2 Index is the sole reader (@Monitor('twoFactor.visible') + this.twoFactor.cookie/source).
  // The former twoFactorVisible/Cookie/Source keys AND the write-only twoFactorRequestedAt/
  // twoFactorCompletedAt timestamp breadcrumbs were removed — all had zero runtime readers. No legacy V1
  // two-factor AppStorage keys remain; do not reintroduce any.

  // Auto daily check-in state
  static readonly AUTO_DAILY_CHECKIN_ENABLED: string = 'autoDailyCheckinEnabled'
  static readonly AUTO_DAILY_CHECKIN_LAST_ATTEMPT_DATE: string = 'autoDailyCheckinLastAttemptDate'
  static readonly AUTO_DAILY_CHECKIN_LAST_ATTEMPT_IDENTITY: string =
    'autoDailyCheckinLastAttemptIdentity'
  static readonly AUTO_DAILY_CHECKIN_LAST_SUCCESS_DATE: string = 'autoDailyCheckinLastSuccessDate'

  // Device-cloud sync (端云协同) user toggle. Default OFF (opt-in).
  static readonly CLOUD_SYNC_ENABLED: string = 'cloudSyncEnabled'

  // Per-feature cloud-sync toggles. The full preference key is this prefix + a CloudSyncFeature key
  // (e.g. 'cloudSyncFeat_collections'). Each defaults ON, so enabling cloud sync syncs everything
  // unless the user opts a feature out.
  static readonly CLOUD_SYNC_FEATURE_PREFIX: string = 'cloudSyncFeat_'

  // Last cloud-sync outcome, persisted so Settings can show "上次同步:…" immediately on open (the
  // in-memory CloudSyncState resets to 0 on restart). LAST_AT is a millisecond epoch; LAST_OK its result.
  static readonly CLOUD_SYNC_LAST_AT: string = 'cloudSyncLastAt'
  static readonly CLOUD_SYNC_LAST_OK: string = 'cloudSyncLastOk'
  // True when the last sync finished with RDB_CLOUD_DISABLED (the system 云空间 sync is off for this app).
  // Persisted so Settings can show the "enable cloud sync in system settings" hint after a restart.
  static readonly CLOUD_SYNC_LAST_CLOUD_DISABLED: string = 'cloudSyncLastCloudDisabled'
  // One-time guard: rows written by the old `INSERT OR REPLACE` upsert were never flagged for cloud
  // upload. After the ON-CONFLICT fix, a one-shot re-touch re-marks existing local rows dirty so they
  // finally upload. Set once that flush has run on this device.
  static readonly CLOUD_SYNC_REUPLOAD_FLUSH_DONE: string = 'cloudSyncReuploadFlushDone'

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
  // NOTE: motionHandEdge was removed — the floating reply-button hand edge lives only in its
  // AppStorageV2 'v2:motionHandEdge' holder (MotionHandEdgeState). MotionHandStateService is its single
  // writer and reads it back there; @ComponentV2 TopicDetailPage @Monitors it. Do not reintroduce it.
  static readonly MOTION_HOLDING_HAND_SUPPORTED: string = 'motionHoldingHandSupported'

  // Navigation/action bus and page appbar state
  // NOTE: the transient action-bus + pending-deep-link AppStorage keys (topicDetailAction,
  // nodeTopicAction, userProfileAction, userProfileShown, notificationAction, searchAction,
  // webLoginAction, nativeLoginShown, imagePreviewAction, accountWebViewAction, pendingV2exUrl) and the
  // node-topic appbar OUTPUT keys (nodeTopicTitle/Subtitle/Saved/SiteFavorited) were removed earlier.
  // This lane additionally removed the topic-detail + user-profile appbar identity keys
  // (topicDetailSavedLater/SiteFavorited/Thanked, topicDetailAppbar*, userProfileActions*/FollowLabel/
  // BlockLabel/Following/Blocked, userProfileAppbar*), the pending-search bus (pendingSearchQuery) and
  // the account-webview target (accountWebViewUrl): each had zero runtime readers once its pages moved
  // to the matching AppStorageV2 'v2:*' holder (TopicDetailAppbarState / UserProfileAppbarState /
  // SearchActionState.pendingQuery / AccountWebViewUrlState). Do not reintroduce the legacy V1 keys.
  static readonly NOTIFICATION_UNREAD_COUNT: string = 'notificationUnreadCount'
  static readonly DISCOVER_NODE_KEYWORD: string = 'discoverNodeKeyword'
}
