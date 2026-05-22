import {
  AppStrings,
  V2exAuthenticatedMember,
  V2exBalance,
  V2exDailyMission,
  V2exTokenInfo
} from 'shared'

export interface AccountIdentity {
  username: string
  avatarUrl: string
}

export class AccountPageCoordinator {
  static get SECTION_ACCOUNT(): string { return AppStrings.t(AppStrings.R_ACCOUNT_SECTION, 'Account') }
  static get SECTION_ACCOUNT_CONTENT(): string { return AppStrings.t(AppStrings.R_ACCOUNT_CONTENT_SECTION, 'Account content') }
  static get SECTION_LOCAL_CONTENT(): string { return AppStrings.t(AppStrings.R_LOCAL_CONTENT_SECTION, 'Local content') }
  static get SECTION_MORE(): string { return AppStrings.t(AppStrings.R_MORE_SECTION, 'More') }
  static get SECTION_ADVANCED_API(): string { return AppStrings.t(AppStrings.R_ADVANCED_API_SECTION, 'Advanced API') }

  static get LOGIN_TITLE(): string { return AppStrings.t(AppStrings.R_NOT_LOGGED_IN, 'Not logged in') }
  static get LOGIN_SUBTITLE(): string { return AppStrings.t(AppStrings.R_TAP_TO_LOGIN_V2EX, 'Tap to log in to V2EX') }

  static get PROFILE_TITLE(): string { return AppStrings.t(AppStrings.R_PROFILE_HOME, 'Profile') }
  static get BALANCE_DETAIL_TITLE(): string { return AppStrings.t(AppStrings.R_BALANCE_DETAILS, 'Balance details') }
  static get WEB_ACCOUNT_SETTINGS_TITLE(): string { return AppStrings.t(AppStrings.R_WEB_ACCOUNT_SETTINGS, 'Web account settings') }
  static get LOGOUT_TITLE(): string { return AppStrings.t(AppStrings.R_LOGOUT, 'Log out') }

  static get ACCOUNT_SAVED_TOPICS_TITLE(): string { return AppStrings.t(AppStrings.R_NAV_SAVED_TOPICS, 'Favorite topics') }
  static get ACCOUNT_SAVED_NODES_TITLE(): string { return AppStrings.t(AppStrings.R_NAV_SAVED_NODES, 'Favorite nodes') }
  static get ACCOUNT_FOLLOWING_TITLE(): string { return AppStrings.t(AppStrings.R_NAV_FOLLOWING, 'Following') }
  static get ACCOUNT_BLACKLIST_TITLE(): string { return AppStrings.t(AppStrings.R_NAV_BLACKLIST, 'Blocked and ignored') }

  static readonly API_TOKEN_TITLE: string = 'Personal Access Token'
  static get API_TOKEN_SUBTITLE(): string { return AppStrings.t(AppStrings.R_API_TOKEN_SUBTITLE, 'Saved, used only for V2EX API v2 advanced features') }
  static get CLEAR_API_AUTH_TITLE(): string { return AppStrings.t(AppStrings.R_CLEAR_API_AUTH, 'Clear API authorization') }
  static get CLEAR_API_AUTH_MESSAGE(): string { return AppStrings.t(AppStrings.R_CLEAR_API_AUTH_MESSAGE, 'Only clears the locally saved Personal Access Token. Web login stays signed in.') }

  static get LOCAL_SEARCH_TITLE(): string { return AppStrings.t(AppStrings.R_NAV_SEARCH, 'Search') }
  static get LOCAL_TOPIC_DRAFT_TITLE(): string { return AppStrings.t(AppStrings.R_NAV_TOPIC_DRAFT, 'Topic draft') }
  static get LOCAL_READ_LATER_TITLE(): string { return AppStrings.t(AppStrings.R_NAV_READ_LATER, 'Read later') }
  static get LOCAL_VIEWED_TOPICS_TITLE(): string { return AppStrings.t(AppStrings.R_NAV_RECENTLY_VIEWED, 'Recently viewed') }
  static get LOCAL_SAVED_NODES_TITLE(): string { return AppStrings.t(AppStrings.R_NAV_LOCAL_NODES, 'Local followed nodes') }
  static get ABOUT_TITLE(): string { return AppStrings.t(AppStrings.R_ABOUT_NEXT2V, 'About Next2V') }

  static hasCookieAccount(authCookieConfigured: boolean): boolean {
    return authCookieConfigured
  }

  static hasAnyAccount(authCookieConfigured: boolean, authTokenConfigured: boolean): boolean {
    return authCookieConfigured || authTokenConfigured
  }

  static shouldShowApiDiagnostics(authTokenConfigured: boolean): boolean {
    return authTokenConfigured
  }

  static identity(
    sessionUsername: string,
    sessionAvatar: string,
    authProfile: V2exAuthenticatedMember | null,
    storedUsername: string
  ): AccountIdentity {
    return {
      username: sessionUsername || authProfile?.username || storedUsername || '',
      avatarUrl: sessionAvatar || authProfile?.avatar_normal || authProfile?.avatar_large || ''
    }
  }

  static accountMetaText(
    hasCookieAccount: boolean,
    authTokenConfigured: boolean,
    accountBalance: V2exBalance | null,
    isAccountMetaLoading: boolean,
    accountMetaError: string
  ): string {
    if (!hasCookieAccount) {
      return authTokenConfigured ? AppStrings.t(AppStrings.R_API_AUTH_CONFIGURED, 'API authorization configured') : ''
    }
    if (accountBalance) {
      return accountBalance.summary
    }
    if (isAccountMetaLoading) {
      return AppStrings.t(AppStrings.R_BALANCE_SYNCING, 'Balance syncing')
    }
    if (accountMetaError) {
      return AppStrings.t(AppStrings.R_BALANCE_UNAVAILABLE, 'Balance unavailable')
    }
    return ''
  }

  static dailyMissionMessage(message: string): string {
    const clean = (message || '').trim()
    if (clean === 'already_checked_in_today') {
      return AppStrings.t(AppStrings.R_ALREADY_CHECKED_IN_TODAY, 'Already checked in today')
    }
    if (clean === 'daily_checkin_available') {
      return AppStrings.t(AppStrings.R_DAILY_CHECKIN, 'Check in')
    }
    if (clean === 'daily_checkin_unavailable') {
      return AppStrings.t(AppStrings.R_DAILY_CHECKED_IN, 'Checked in')
    }
    return clean
  }

  static dailyMissionButtonText(isDailyRedeeming: boolean, dailyMission: V2exDailyMission | null): string {
    if (isDailyRedeeming) {
      return AppStrings.t(AppStrings.R_DAILY_CHECKING_IN, 'Checking in')
    }
    if (dailyMission && !dailyMission.canRedeem) {
      return AppStrings.t(AppStrings.R_DAILY_CHECKED_IN, 'Checked in')
    }
    return AppStrings.t(AppStrings.R_DAILY_CHECKIN, 'Check in')
  }

  static dailyMissionEnabled(
    hasCookieAccount: boolean,
    isAccountMetaLoading: boolean,
    isDailyRedeeming: boolean,
    dailyMission: V2exDailyMission | null
  ): boolean {
    return hasCookieAccount &&
      !isAccountMetaLoading &&
      !isDailyRedeeming &&
      (!dailyMission || dailyMission.canRedeem)
  }

  static profileTagline(authProfile: V2exAuthenticatedMember | null): string {
    return authProfile?.tagline || ''
  }

  static profileLocation(authProfile: V2exAuthenticatedMember | null): string {
    return authProfile?.location || ''
  }

  static profileCreatedAt(authProfile: V2exAuthenticatedMember | null): number {
    return authProfile?.created || 0
  }

  static tokenScope(tokenInfo: V2exTokenInfo | null): string {
    return tokenInfo?.scope || ''
  }

  static tokenExpiration(tokenInfo: V2exTokenInfo | null): number {
    return tokenInfo?.expiration || 0
  }

  static tokenLastUsed(tokenInfo: V2exTokenInfo | null): number {
    return tokenInfo?.last_used || 0
  }

  static hasApiRateLimitSnapshot(limit: number, updatedAt: number, resetAt: number): boolean {
    return limit > 0 || updatedAt > 0 || resetAt > 0
  }
}
