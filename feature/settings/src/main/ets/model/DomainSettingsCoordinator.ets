import { http } from '@kit.NetworkKit'
import {
  ApiConstants,
  ApiDomainSettings,
  AppStrings,
  CookieJarSettings,
  HttpClient,
  NetworkProxyRequest,
  type ApiDomainOption,
  type DomainValidationResult,
} from 'shared'

export class DomainSettingsCoordinator {
  static presetOptions(): ApiDomainOption[] {
    return ApiConstants.PRESET_DOMAINS
  }

  static hostname(baseUrl: string): string {
    const normalized = ApiDomainSettings.normalizeBaseUrl(baseUrl)
    return normalized.replace(/^https:\/\//, '')
  }

  static normalizeCustomBaseUrl(input: string): DomainValidationResult {
    const raw = (input || '').trim()
    if (!raw) {
      return { ok: false, baseUrl: '', message: AppStrings.text($r('app.string.domain_required'), 'Enter a domain') }
    }
    const candidate = raw.indexOf('://') >= 0 ? raw : `https://${raw}`
    const match = candidate.match(/^(https?):\/\/([^\/\s?#]+)(?:[\/?#].*)?$/i)
    if (!match) {
      return { ok: false, baseUrl: '', message: AppStrings.text($r('app.string.domain_invalid'), 'Enter a valid domain') }
    }
    if (match[1].toLowerCase() !== 'https') {
      return { ok: false, baseUrl: '', message: AppStrings.text($r('app.string.domain_https_only'), 'HTTPS domains only') }
    }
    const host = (match[2] || '').toLowerCase()
    if (!/^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?(?:\.[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?)+$/.test(host)) {
      return { ok: false, baseUrl: '', message: AppStrings.text($r('app.string.domain_invalid'), 'Enter a valid domain') }
    }
    return { ok: true, baseUrl: `https://${host}`, message: '' }
  }

  static isV2exOwnedHost(baseUrl: string): boolean {
    const host = DomainSettingsCoordinator.hostname(baseUrl).toLowerCase()
    return host === 'v2ex.com' || host.endsWith('.v2ex.com')
  }

  static async validateCustomDomain(input: string): Promise<DomainValidationResult> {
    const normalized = DomainSettingsCoordinator.normalizeCustomBaseUrl(input)
    if (!normalized.ok) {
      return normalized
    }
    try {
      // Custom domain validation probes /api/site/info.json and requires the response
      // to contain a 'domain' key whose value is a v2ex.com subdomain. This is a V2EX
      // server-side invariant observed on all working mirrors — they all report
      // 'domain: www.v2ex.com'. This check prevents users from pointing the app at
      // non-V2EX HTTPS servers that happen to return JSON with incidental key overlaps.
      const response = await NetworkProxyRequest.request(`${normalized.baseUrl}${ApiConstants.API_SITE_INFO}`, {
        method: http.RequestMethod.GET,
        header: { 'Accept': 'application/json', 'Accept-Encoding': 'gzip' },
        connectTimeout: 10000,
        readTimeout: 15000,
        usingCache: false,
      })
      if (response.responseCode !== 200) {
        return {
          ok: false,
          baseUrl: normalized.baseUrl,
          message: AppStrings.format(AppStrings.text($r('app.string.domain_validate_http_format'), 'Validation failed: HTTP {0}'), [`${response.responseCode}`])
        }
      }
      const parsed = JSON.parse(response.result as string) as Record<string, Object>
      const domain = `${parsed['domain'] || ''}`.toLowerCase()
      if (!domain || !(domain === 'v2ex.com' || domain.endsWith('.v2ex.com'))) {
        return { ok: false, baseUrl: normalized.baseUrl, message: AppStrings.text($r('app.string.domain_not_v2ex'), 'No V2EX site info returned') }
      }
      if (!DomainSettingsCoordinator.isV2exOwnedHost(normalized.baseUrl) && !CookieJarSettings.getCurrentCookie()) {
        return { ok: false, baseUrl: normalized.baseUrl, message: AppStrings.text($r('app.string.domain_requires_verified_session'), 'Custom domains require a verified session first') }
      }
      return { ok: true, baseUrl: normalized.baseUrl, message: AppStrings.text($r('app.string.domain_validated'), 'Validated') }
    } catch (error) {
      const e = error as Error
      const reason = e.message || AppStrings.text($r('app.string.domain_network_error'), 'Network error')
      return {
        ok: false,
        baseUrl: normalized.baseUrl,
        message: AppStrings.format(AppStrings.text($r('app.string.domain_validate_failed_format'), 'Validation failed: {0}'), [reason])
      }
    }
  }

  static applySelectedBaseUrl(baseUrl: string): void {
    HttpClient.getInstance().setBaseUrl(ApiDomainSettings.normalizeBaseUrl(baseUrl))
    CookieJarSettings.refreshConfiguredState()
    CookieJarSettings.restoreCurrentToWebCookieManager().catch((error: Error) => {
      console.error('restore web cookie failed: ' + error.message)
    })
  }
}
