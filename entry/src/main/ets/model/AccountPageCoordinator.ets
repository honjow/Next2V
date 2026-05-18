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
  static hasCookieAccount(authCookieConfigured: boolean): boolean {
    return authCookieConfigured
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
