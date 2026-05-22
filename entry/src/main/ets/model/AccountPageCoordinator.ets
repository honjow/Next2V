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
  static get SECTION_ACCOUNT(): ResourceStr { return AppStrings.R_ACCOUNT_SECTION }
  static get SECTION_ACCOUNT_CONTENT(): ResourceStr { return AppStrings.R_ACCOUNT_CONTENT_SECTION }
  static get SECTION_LOCAL_CONTENT(): ResourceStr { return AppStrings.R_LOCAL_CONTENT_SECTION }
  static get SECTION_MORE(): ResourceStr { return AppStrings.R_MORE_SECTION }
  static get SECTION_ADVANCED_API(): ResourceStr { return AppStrings.R_ADVANCED_API_SECTION }

  static get LOGIN_TITLE(): ResourceStr { return AppStrings.R_NOT_LOGGED_IN }
  static get LOGIN_SUBTITLE(): ResourceStr { return AppStrings.R_TAP_TO_LOGIN_V2EX }

  static get PROFILE_TITLE(): ResourceStr { return AppStrings.R_PROFILE_HOME }
  static get BALANCE_DETAIL_TITLE(): ResourceStr { return AppStrings.R_BALANCE_DETAILS }
  static get WEB_ACCOUNT_SETTINGS_TITLE(): ResourceStr { return AppStrings.R_WEB_ACCOUNT_SETTINGS }
  static get LOGOUT_TITLE(): ResourceStr { return AppStrings.R_LOGOUT }

  static get ACCOUNT_SAVED_TOPICS_TITLE(): ResourceStr { return AppStrings.R_NAV_SAVED_TOPICS }
  static get ACCOUNT_SAVED_NODES_TITLE(): ResourceStr { return AppStrings.R_NAV_SAVED_NODES }
  static get ACCOUNT_FOLLOWING_TITLE(): ResourceStr { return AppStrings.R_NAV_FOLLOWING }

  static readonly API_TOKEN_TITLE: string = 'Personal Access Token'
  static get API_TOKEN_SUBTITLE(): ResourceStr { return AppStrings.R_API_TOKEN_SUBTITLE }
  static get CLEAR_API_AUTH_TITLE(): ResourceStr { return AppStrings.R_CLEAR_API_AUTH }
  static get CLEAR_API_AUTH_MESSAGE(): string { return AppStrings.text(AppStrings.R_CLEAR_API_AUTH_MESSAGE, 'Only clears the locally saved Personal Access Token. Web login stays signed in.') }

  static get LOCAL_SEARCH_TITLE(): ResourceStr { return AppStrings.R_NAV_SEARCH }
  static get LOCAL_TOPIC_DRAFT_TITLE(): ResourceStr { return AppStrings.R_NAV_TOPIC_DRAFT }
  static get LOCAL_READ_LATER_TITLE(): ResourceStr { return AppStrings.R_NAV_READ_LATER }
  static get LOCAL_VIEWED_TOPICS_TITLE(): ResourceStr { return AppStrings.R_NAV_RECENTLY_VIEWED }
  static get LOCAL_SAVED_NODES_TITLE(): ResourceStr { return AppStrings.R_NAV_LOCAL_NODES }
  static get ABOUT_TITLE(): ResourceStr { return AppStrings.R_ABOUT_NEXT2V }

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
  ): ResourceStr {
    if (!hasCookieAccount) {
      return authTokenConfigured ? AppStrings.R_API_AUTH_CONFIGURED : ''
    }
    if (accountBalance) {
      return accountBalance.summary
    }
    if (isAccountMetaLoading) {
      return AppStrings.R_BALANCE_SYNCING
    }
    if (accountMetaError) {
      return AppStrings.R_BALANCE_UNAVAILABLE
    }
    return ''
  }

  static dailyMissionMessage(message: string): ResourceStr {
    const clean = (message || '').trim()
    if (clean === 'already_checked_in_today') {
      return AppStrings.R_ALREADY_CHECKED_IN_TODAY
    }
    if (clean === 'daily_checkin_available') {
      return AppStrings.R_DAILY_CHECKIN
    }
    if (clean === 'daily_checkin_unavailable') {
      return AppStrings.R_DAILY_CHECKED_IN
    }
    return clean
  }

  static dailyMissionButtonText(isDailyRedeeming: boolean, dailyMission: V2exDailyMission | null): ResourceStr {
    if (isDailyRedeeming) {
      return AppStrings.R_DAILY_CHECKING_IN
    }
    if (dailyMission && !dailyMission.canRedeem) {
      return AppStrings.R_DAILY_CHECKED_IN
    }
    return AppStrings.R_DAILY_CHECKIN
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
