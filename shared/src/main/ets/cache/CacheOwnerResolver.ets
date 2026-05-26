import { common } from '@kit.AbilityKit'
import { HttpClient } from '../network/HttpClient'
import { AccountStore } from '../settings/AccountStore'

export type CacheOwnerType = 'public' | 'account'

export interface CacheScope {
  baseUrl: string
  ownerType: CacheOwnerType
  accountId: string
  loginMode: string
  ownerKey: string
}

export class CacheOwnerResolver {
  static resolvePublicScope(routeKey: string = ''): CacheScope {
    const baseUrl = CacheOwnerResolver.normalizeBaseUrl(HttpClient.getInstance().getBaseUrl())
    const ownerKey = CacheOwnerResolver.ownerKey({
      baseUrl,
      ownerType: 'public',
      accountId: '',
      loginMode: 'public',
      ownerKey: '',
    }, routeKey)
    return { baseUrl, ownerType: 'public', accountId: '', loginMode: 'public', ownerKey }
  }

  static async resolveActivePrivateScope(context: common.UIAbilityContext, routeKey: string = ''): Promise<CacheScope | null> {
    const activeId = await AccountStore.restoreActiveId(context)
    if (!activeId) {
      return null
    }
    const account = await AccountStore.getById(context, activeId)
    if (!account) {
      return null
    }
    const baseUrl = CacheOwnerResolver.normalizeBaseUrl(account.baseUrl || HttpClient.getInstance().getBaseUrl())
    const loginMode = account.loginMode || 'cookie'
    // Private/action overlays include domain + stable AccountStore id, because username-only keys can leak
    // state between two accounts with the same name on v2ex.com/v2ex.co or after account replacement.
    const ownerKey = CacheOwnerResolver.ownerKey({
      baseUrl,
      ownerType: 'account',
      accountId: account.id,
      loginMode,
      ownerKey: '',
    }, routeKey)
    return { baseUrl, ownerType: 'account', accountId: account.id, loginMode, ownerKey }
  }

  static ownerKey(scope: CacheScope, routeKey: string = ''): string {
    const baseUrl = CacheOwnerResolver.normalizeBaseUrl(scope.baseUrl)
    const accountId = (scope.accountId || '').trim()
    const loginMode = (scope.loginMode || scope.ownerType || 'public').trim()
    const route = (routeKey || '').trim()
    if (scope.ownerType === 'account') {
      return route ? `account:${baseUrl}:${accountId}:${loginMode}:${route}` : `account:${baseUrl}:${accountId}:${loginMode}`
    }
    return route ? `public:${baseUrl}:${route}` : `public:${baseUrl}`
  }

  static normalizeBaseUrl(baseUrl: string): string {
    const clean = (baseUrl || '').trim()
    if (clean.endsWith('/')) {
      return clean.substring(0, clean.length - 1)
    }
    return clean
  }
}
