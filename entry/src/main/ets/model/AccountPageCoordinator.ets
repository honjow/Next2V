import {
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
  static readonly SECTION_ACCOUNT: string = '账号'
  static readonly SECTION_ACCOUNT_CONTENT: string = '账号内容'
  static readonly SECTION_LOCAL_CONTENT: string = '本地内容'
  static readonly SECTION_MORE: string = '更多'
  static readonly SECTION_ADVANCED_API: string = '高级 API'

  static readonly LOGIN_TITLE: string = '未登录'
  static readonly LOGIN_SUBTITLE: string = '点击登录 V2EX'

  static readonly PROFILE_TITLE: string = '个人主页'
  static readonly BALANCE_DETAIL_TITLE: string = '余额明细'
  static readonly WEB_ACCOUNT_SETTINGS_TITLE: string = '网页账号设置'
  static readonly LOGOUT_TITLE: string = '退出登录'

  static readonly ACCOUNT_SAVED_TOPICS_TITLE: string = '收藏主题'
  static readonly ACCOUNT_SAVED_NODES_TITLE: string = '收藏节点'
  static readonly ACCOUNT_FOLLOWING_TITLE: string = '关注用户'
  static readonly ACCOUNT_BLACKLIST_TITLE: string = '屏蔽与忽略'

  static readonly API_TOKEN_TITLE: string = 'Personal Access Token'
  static readonly API_TOKEN_SUBTITLE: string = '已保存，仅用于 V2EX API v2 高级能力'
  static readonly CLEAR_API_AUTH_TITLE: string = '清除 API 授权'
  static readonly CLEAR_API_AUTH_MESSAGE: string = '仅清除本地保存的 Personal Access Token，不会退出网页登录。'

  static readonly LOCAL_SEARCH_TITLE: string = '搜索'
  static readonly LOCAL_TOPIC_DRAFT_TITLE: string = '发帖草稿'
  static readonly LOCAL_READ_LATER_TITLE: string = '稍后读'
  static readonly LOCAL_VIEWED_TOPICS_TITLE: string = '最近浏览'
  static readonly LOCAL_SAVED_NODES_TITLE: string = '本地关注节点'
  static readonly ABOUT_TITLE: string = '关于 Next2V'

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
      return authTokenConfigured ? 'API 授权已配置' : ''
    }
    if (accountBalance) {
      return accountBalance.summary
    }
    if (isAccountMetaLoading) {
      return '虚拟币同步中'
    }
    if (accountMetaError) {
      return '虚拟币信息不可用'
    }
    return ''
  }

  static dailyMissionButtonText(isDailyRedeeming: boolean, dailyMission: V2exDailyMission | null): string {
    if (isDailyRedeeming) {
      return '签到中'
    }
    if (dailyMission && !dailyMission.canRedeem) {
      return '已签到'
    }
    return '签到'
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
