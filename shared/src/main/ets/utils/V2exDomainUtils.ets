export class V2exDomainUtils {
  static hostForBaseUrl(baseUrl: string): string {
    const match = (baseUrl || '').trim().match(/^https?:\/\/([^\/\s?#]+)/i)
    return match ? (match[1] || '').toLowerCase() : ''
  }

  static isV2exOwnedHost(host: string): boolean {
    const normalized = (host || '').trim().toLowerCase()
    return V2exDomainUtils.isHostOrSubdomainOf(normalized, 'v2ex.com') ||
      V2exDomainUtils.isHostOrSubdomainOf(normalized, 'v2ex.co')
  }

  private static isHostOrSubdomainOf(host: string, root: string): boolean {
    return host === root || host.endsWith(`.${root}`)
  }
}
