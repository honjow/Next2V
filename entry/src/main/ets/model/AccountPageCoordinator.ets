import {
  AppStrings,
  V2exAuthenticatedMember,
  V2exBalance,
  V2exDailyMission,
  V2exTokenInfo,
} from 'shared'

export interface AccountIdentity {
  username: string
  avatarUrl: string
}

export class AccountPageCoordinator {
  static get SECTION_ACCOUNT(): ResourceStr {
    return $r('app.string.account_section')
  }
  static get SECTION_ACCOUNT_CONTENT(): ResourceStr {
    return $r('app.string.account_content_section')
  }
  static get SECTION_LOCAL_CONTENT(): ResourceStr {
    return $r('app.string.local_content_section')
  }
  static get SECTION_MORE(): ResourceStr {
    return $r('app.string.more_section')
  }
  static get SECTION_ADVANCED_API(): ResourceStr {
    return $r('app.string.advanced_api_section')
  }

  static get LOGIN_TITLE(): ResourceStr {
    return $r('app.string.not_logged_in')
  }
  static get LOGIN_SUBTITLE(): ResourceStr {
    return $r('app.string.tap_to_login_v2ex')
  }
  static get ADD_ANOTHER_ACCOUNT_TITLE(): ResourceStr {
    return $r('app.string.account_add_another')
  }

  static get ACCOUNT_LIST_HEADER(): ResourceStr {
    return $r('app.string.account_list_header')
  }
  static get ACCOUNT_ACTIVE_LABEL(): ResourceStr {
    return $r('app.string.account_active_label')
  }
  static get REMOVE_ACCOUNT_TITLE(): ResourceStr {
    return $r('app.string.account_remove_title')
  }
  static removeAccountMessage(username: string): string {
    return AppStrings.format(
      AppStrings.text(
        $r('app.string.account_remove_message_arg'),
        'Remove "{0}"? Other accounts will not be affected.',
      ),
      [username],
    )
  }
  static get SWITCH_LABEL(): ResourceStr {
    return $r('app.string.account_switch_label')
  }
  static get REMOVE_LABEL(): ResourceStr {
    return $r('app.string.account_remove_label')
  }

  static get PROFILE_TITLE(): ResourceStr {
    return $r('app.string.profile_home')
  }
  static get BALANCE_DETAIL_TITLE(): ResourceStr {
    return $r('app.string.balance_details')
  }
  static get WEB_ACCOUNT_SETTINGS_TITLE(): ResourceStr {
    return $r('app.string.web_account_settings')
  }
  static get LOGOUT_TITLE(): ResourceStr {
    return $r('app.string.logout')
  }

  static get ACCOUNT_SAVED_TOPICS_TITLE(): ResourceStr {
    return $r('app.string.nav_saved_topics')
  }
  static get ACCOUNT_SAVED_NODES_TITLE(): ResourceStr {
    return $r('app.string.nav_saved_nodes')
  }
  static get ACCOUNT_FOLLOWING_TITLE(): ResourceStr {
    return $r('app.string.nav_following')
  }

  static readonly API_TOKEN_TITLE: string = 'Personal Access Token'
  static get API_TOKEN_SUBTITLE(): ResourceStr {
    return $r('app.string.api_token_subtitle')
  }
  static get CLEAR_API_AUTH_TITLE(): ResourceStr {
    return $r('app.string.clear_api_auth')
  }
  static get CLEAR_API_AUTH_MESSAGE(): string {
    return AppStrings.text(
      $r('app.string.clear_api_auth_message'),
      'Only clears the locally saved Personal Access Token. Web login stays signed in.',
    )
  }

  static get LOCAL_SEARCH_TITLE(): ResourceStr {
    return $r('app.string.nav_search')
  }
  static get LOCAL_READ_LATER_TITLE(): ResourceStr {
    return $r('app.string.nav_read_later')
  }
  static get LOCAL_VIEWED_TOPICS_TITLE(): ResourceStr {
    return $r('app.string.nav_recently_viewed')
  }
  static get LOCAL_SAVED_NODES_TITLE(): ResourceStr {
    return $r('app.string.nav_local_nodes')
  }
  static get ABOUT_TITLE(): ResourceStr {
    return $r('app.string.about_next2v')
  }

  static hasCookieAccount(authCookieConfigured: boolean): boolean {
    return authCookieConfigured
  }

  /**
   * Returns true only when the app has identifiable accounts.
   *
   * Gate priority:
   *   1. AccountStore records exist (definitive identity)
   *   2. Token-based auth (PAT) is configured (legacy, token-only identity)
   *   3. Cookie is configured AND session contains a real username
   *
   * A lone stale cookie WITHOUT an accompanying session username
   * or AccountStore record does NOT qualify — this prevents the
   * generic "V2EX user" placeholder account-screen deception.
   */
  static hasAnyAccount(
    authCookieConfigured: boolean,
    authTokenConfigured: boolean,
    accountsCount: number,
    sessionUsername: string,
  ): boolean {
    if (accountsCount > 0) {
      return true
    }
    if (authTokenConfigured) {
      return true
    }
    if (authCookieConfigured && (sessionUsername || '').trim().length > 0) {
      return true
    }
    return false
  }

  static shouldShowApiDiagnostics(authTokenConfigured: boolean): boolean {
    return authTokenConfigured
  }

  static identity(
    sessionUsername: string,
    sessionAvatar: string,
    authProfile: V2exAuthenticatedMember | null,
    storedUsername: string,
    activeAccountUsername: string = '',
    activeAccountAvatar: string = '',
  ): AccountIdentity {
    return {
      username:
        sessionUsername || authProfile?.username || storedUsername || activeAccountUsername || '',
      avatarUrl:
        sessionAvatar ||
        authProfile?.avatar_normal ||
        authProfile?.avatar_large ||
        activeAccountAvatar ||
        '',
    }
  }

  static accountMetaText(
    hasCookieAccount: boolean,
    authTokenConfigured: boolean,
    accountBalance: V2exBalance | null,
    isAccountMetaLoading: boolean,
    accountMetaError: string,
  ): ResourceStr {
    if (!hasCookieAccount) {
      return authTokenConfigured ? $r('app.string.api_auth_configured') : ''
    }
    if (accountBalance) {
      return accountBalance.summary
    }
    if (isAccountMetaLoading) {
      return $r('app.string.balance_syncing')
    }
    if (accountMetaError) {
      return $r('app.string.balance_unavailable')
    }
    return ''
  }

  static dailyMissionMessage(message: string): ResourceStr {
    const clean = (message || '').trim()
    if (clean === 'already_checked_in_today') {
      return $r('app.string.already_checked_in_today')
    }
    if (clean === 'daily_checkin_available') {
      return $r('app.string.daily_checkin')
    }
    if (clean === 'daily_checkin_unavailable') {
      return $r('app.string.daily_checked_in')
    }
    return clean
  }

  static dailyMissionButtonText(
    isDailyRedeeming: boolean,
    dailyMission: V2exDailyMission | null,
  ): ResourceStr {
    if (isDailyRedeeming) {
      return $r('app.string.daily_checking_in')
    }
    if (dailyMission && !dailyMission.canRedeem) {
      return $r('app.string.daily_checked_in')
    }
    return $r('app.string.daily_checkin')
  }

  static dailyMissionEnabled(
    hasCookieAccount: boolean,
    isAccountMetaLoading: boolean,
    isDailyRedeeming: boolean,
    dailyMission: V2exDailyMission | null,
  ): boolean {
    // Block only on the COLD load (no mission state yet). Account-meta is re-harvested on every authed page
    // load (the startup auto check-in alone fetches /mission/daily several times), each toggling
    // isAccountMetaLoading; gating the button on that made it flicker colored<->grey during check-in. Once a
    // mission state is known, background refreshes no longer disable the button — a premature tap is already
    // safe (redeemDailyMission re-validates canRedeem before claiming).
    return (
      hasCookieAccount &&
      !isDailyRedeeming &&
      !(isAccountMetaLoading && !dailyMission) &&
      (!dailyMission || dailyMission.canRedeem)
    )
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
