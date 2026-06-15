import { V2exDomainUtils } from './V2exDomainUtils'

export type V2exRouteKind = 'topic' | 'member' | 'node' | 'search'

export interface V2exRoute {
  kind: V2exRouteKind
  topicId?: number
  targetFloor?: number
  username?: string
  nodeName?: string
  query?: string
}

export class V2exUrlRouter {
  static parse(rawUrl: string): V2exRoute | null {
    const path = V2exUrlRouter.pathFromUrl(rawUrl)
    if (!path) {
      return null
    }

    const topicMatch = path.match(/^\/t\/(\d+)(?:\/[^#?]*)?(?:\?[^#]*)?(?:#(?:reply|r_?)?(\d+)|#(\d+))?$/i)
    if (topicMatch && topicMatch[1]) {
      const topicId = Number.parseInt(topicMatch[1])
      if (topicId > 0) {
        const floor = Number.parseInt(topicMatch[2] || topicMatch[3] || '0')
        return {
          kind: 'topic',
          topicId: topicId,
          targetFloor: Number.isFinite(floor) && floor > 0 ? floor : 0
        }
      }
    }

    const memberMatch = path.match(/^\/member\/([0-9A-Za-z_]+)\/?$/i)
    if (memberMatch && memberMatch[1]) {
      return { kind: 'member', username: memberMatch[1] }
    }

    const nodeMatch = path.match(/^\/go\/([0-9A-Za-z_-]+)\/?$/i)
    if (nodeMatch && nodeMatch[1]) {
      return { kind: 'node', nodeName: nodeMatch[1] }
    }

    const searchMatch = path.match(/^\/search(?:\?([^#]*))?$/i)
    if (searchMatch) {
      const query = V2exUrlRouter.queryValue(searchMatch[1] || '', 'q') ||
        V2exUrlRouter.queryValue(searchMatch[1] || '', 'query')
      if (query) {
        return { kind: 'search', query: query }
      }
    }

    return null
  }

  static pathFromUrl(rawUrl: string): string {
    const path = V2exUrlRouter.normalizeFirstPartyPath(rawUrl)
    if (!path) {
      return ''
    }
    return path
  }

  static withSelectedBaseUrl(rawUrl: string, selectedBaseUrl: string): string {
    const path = V2exUrlRouter.normalizeFirstPartyPath(rawUrl)
    if (!path) {
      return (rawUrl || '').trim()
    }
    const baseUrl = V2exUrlRouter.cleanBaseUrl(selectedBaseUrl)
    if (!baseUrl) {
      return path
    }
    return `${baseUrl}${path}`
  }

  static isFirstPartySiteUrl(rawUrl: string): boolean {
    return V2exUrlRouter.normalizeFirstPartyPath(rawUrl).length > 0
  }

  static normalizeFirstPartyPath(rawUrl: string): string {
    const clean = (rawUrl || '').trim()
    if (!clean) {
      return ''
    }
    if (clean.startsWith('/')) {
      return V2exUrlRouter.isSitePath(clean) ? clean : ''
    }
    const match = clean.match(/^https?:\/\/([^/?#]+)([^]*)?$/i)
    if (!match || !match[1]) {
      return ''
    }
    const host = match[1].toLowerCase()
    if (!V2exUrlRouter.isV2exSiteHost(host)) {
      return ''
    }
    const path = match[2] || '/'
    return V2exUrlRouter.isSitePath(path) ? path : ''
  }

  private static cleanBaseUrl(baseUrl: string): string {
    const clean = (baseUrl || '').trim()
    if (!clean) {
      return ''
    }
    return clean.endsWith('/') ? clean.slice(0, clean.length - 1) : clean
  }

  private static isV2exSiteHost(host: string): boolean {
    return V2exDomainUtils.isV2exOwnedHost(host)
  }

  private static isSitePath(pathWithQueryAndHash: string): boolean {
    const path = (pathWithQueryAndHash || '').trim()
    if (!path.startsWith('/')) {
      return false
    }
    if (path === '/' || path.startsWith('/?')) {
      return true
    }
    const pathOnly = path.split('?')[0].split('#')[0]
    return pathOnly === '/settings' ||
      pathOnly === '/balance' ||
      pathOnly === '/signin' ||
      pathOnly === '/mission/daily' ||
      pathOnly === '/notifications' ||
      pathOnly === '/recent' ||
      pathOnly === '/search' ||
      pathOnly.startsWith('/t/') ||
      pathOnly.startsWith('/go/') ||
      pathOnly.startsWith('/member/')
  }

  private static queryValue(rawQuery: string, key: string): string {
    if (!rawQuery) {
      return ''
    }
    const pairs = rawQuery.split('&')
    for (let i = 0; i < pairs.length; i++) {
      const pair = pairs[i] || ''
      const eq = pair.indexOf('=')
      const rawKey = eq >= 0 ? pair.slice(0, eq) : pair
      if (V2exUrlRouter.decodeQueryPart(rawKey) !== key) {
        continue
      }
      const rawValue = eq >= 0 ? pair.slice(eq + 1) : ''
      return V2exUrlRouter.decodeQueryPart(rawValue).trim()
    }
    return ''
  }

  private static decodeQueryPart(value: string): string {
    try {
      return decodeURIComponent((value || '').replace(/\+/g, ' '))
    } catch (_error) {
      return value || ''
    }
  }
}
