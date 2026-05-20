export type DiagnosticContextValue = ESObject
export type DiagnosticContextObject = ESObject

export interface DiagnosticLogEntry {
  ts: number
  level: string
  category: string
  event: string
  message: string
  context?: DiagnosticContextObject
  error?: DiagnosticContextObject
}

const REDACTED: string = '<redacted>'
const DROPPED: string = '<omitted>'
const MAX_STRING_LENGTH: number = 160
const MAX_REDACTION_DEPTH: number = 5
const MAX_OBJECT_KEYS: number = 80
const MAX_ARRAY_ITEMS: number = 80

export class DiagnosticsRedactor {
  static sanitizeEvent(entry: DiagnosticLogEntry): DiagnosticLogEntry {
    try {
      return {
        ts: entry.ts > 0 ? entry.ts : Date.now(),
        level: DiagnosticsRedactor.safeToken(entry.level || 'info'),
        category: DiagnosticsRedactor.safeToken(entry.category || 'app'),
        event: DiagnosticsRedactor.safeToken(entry.event || 'unknown'),
        message: DiagnosticsRedactor.sanitizeString(entry.message || ''),
        context: DiagnosticsRedactor.sanitizeObject(entry.context || {}, 0),
        error: DiagnosticsRedactor.sanitizeObject(entry.error || {}, 0)
      }
    } catch (_error) {
      const fallback: DiagnosticLogEntry = {
        ts: Date.now(),
        level: 'error',
        category: 'diagnostics',
        event: 'diagnostics_redaction_error',
        message: 'Diagnostic redaction failed',
        context: {}
      }
      return fallback
    }
  }

  static sanitizeContext(context: DiagnosticContextObject): DiagnosticContextObject {
    try {
      return DiagnosticsRedactor.sanitizeObject(context || {}, 0)
    } catch (_error) {
      return {}
    }
  }

  static ownerHash(value: string): string {
    const clean = (value || '').trim()
    if (!clean) {
      return ''
    }
    return `${clean.length}:${DiagnosticsRedactor.fnv1a(clean)}`
  }

  static sanitizeUrl(value: string): string {
    const clean = (value || '').trim()
    if (!clean) {
      return ''
    }
    const noFragment = clean.split('#')[0]
    const queryIndex = noFragment.indexOf('?')
    if (queryIndex < 0) {
      return DiagnosticsRedactor.dropDangerousPath(noFragment)
    }
    const base = DiagnosticsRedactor.dropDangerousPath(noFragment.slice(0, queryIndex))
    const query = noFragment.slice(queryIndex + 1)
    if (!query) {
      return base
    }
    const pairs = query.split('&').filter((part: string) => part.length > 0)
      .map((part: string) => {
        const key = part.split('=')[0] || 'param'
        return `${DiagnosticsRedactor.safeToken(key)}=${REDACTED}`
      })
    return `${base}?${pairs.join('&')}`
  }

  private static sanitizeObject(context: DiagnosticContextObject, depth: number): DiagnosticContextObject {
    const result: DiagnosticContextObject = new Object() as DiagnosticContextObject
    if (depth > MAX_REDACTION_DEPTH) {
      return result
    }
    const keys: string[] = Object.keys(context ? context : (new Object() as DiagnosticContextObject))
    keys.slice(0, MAX_OBJECT_KEYS).forEach((key: string) => {
      if (DiagnosticsRedactor.isDangerousKey(key)) {
        result[key] = REDACTED
        return
      }
      result[key] = DiagnosticsRedactor.sanitizeValue(key, context[key] as DiagnosticContextValue, depth + 1)
    })
    if (keys.length > MAX_OBJECT_KEYS) {
      result['__truncated_keys'] = keys.length - MAX_OBJECT_KEYS
    }
    return result
  }

  private static sanitizeArray(key: string, values: DiagnosticContextValue[], depth: number): DiagnosticContextValue[] {
    if (depth > MAX_REDACTION_DEPTH) {
      return []
    }
    const result: DiagnosticContextValue[] = values.slice(0, MAX_ARRAY_ITEMS)
      .map((value: DiagnosticContextValue): DiagnosticContextValue => {
        return DiagnosticsRedactor.sanitizeValue(key, value, depth + 1)
      })
    if (values.length > MAX_ARRAY_ITEMS) {
      result.push(`<truncated:${values.length - MAX_ARRAY_ITEMS}>`)
    }
    return result
  }

  private static sanitizeValue(key: string, value: DiagnosticContextValue, depth: number): DiagnosticContextValue {
    if (value === null || value === undefined) {
      return DROPPED
    }
    if (typeof value === 'string') {
      if (DiagnosticsRedactor.looksLikeUrlKey(key) || DiagnosticsRedactor.looksLikeUrl(value)) {
        return DiagnosticsRedactor.sanitizeUrl(value)
      }
      return DiagnosticsRedactor.sanitizeString(value)
    }
    if (typeof value === 'number' || typeof value === 'boolean') {
      return value
    }
    if (Array.isArray(value)) {
      return DiagnosticsRedactor.sanitizeArray(key, value as DiagnosticContextValue[], depth)
    }
    if (typeof value === 'object') {
      return DiagnosticsRedactor.sanitizeObject(value as DiagnosticContextObject, depth)
    }
    return DROPPED
  }

  private static sanitizeString(value: string): string {
    let clean = value || ''
    clean = clean.replace(/(Cookie|Set-Cookie)\s*[:=][^;\n]+/gi, `$1=${REDACTED}`)
    clean = clean.replace(/Authorization\s*[:=]\s*(Bearer\s+)?[^\s;]+/gi, `Authorization=${REDACTED}`)
    clean = clean.replace(/Bearer\s+[A-Za-z0-9._~+\/-]+/gi, `Bearer ${REDACTED}`)
    clean = clean.replace(/([?&](once|token|auth|code|password|delete_once|redeem)[^=]*=)[^&#\s]+/gi, `$1${REDACTED}`)
    clean = clean.replace(/\/mission\/daily\/redeem\?[^\s]+/gi, '/mission/daily/redeem?once=<redacted>')
    clean = clean.replace(/\/delete\/notification\/\d+\?[^\s]+/gi, '/delete/notification/<id>?once=<redacted>')
    clean = clean.replace(/\/thank\/(reply|topic)\/\d+\?[^\s]+/gi, '/thank/$1/<id>?once=<redacted>')
    clean = clean.replace(/\/favorite\/(topic|node)\/[^\s?]+\?[^\s]+/gi, '/favorite/$1/<id>?once=<redacted>')
    if (clean.indexOf('<html') >= 0 || clean.indexOf('<div') >= 0 || clean.indexOf('content_rendered') >= 0) {
      return DROPPED
    }
    if (clean.length > MAX_STRING_LENGTH) {
      return clean.slice(0, MAX_STRING_LENGTH) + '…'
    }
    return clean
  }

  private static isDangerousKey(key: string): boolean {
    const lower = (key || '').toLowerCase()
    return lower.indexOf('cookie') >= 0 || lower.indexOf('token') >= 0 || lower.indexOf('authorization') >= 0 ||
      lower.indexOf('password') >= 0 || lower === 'pass' || lower.indexOf('twofactor') >= 0 ||
      lower.indexOf('two_factor') >= 0 || lower === 'code' || lower.indexOf('once') >= 0 ||
      lower.indexOf('redeempath') >= 0 || lower.indexOf('rawhtml') >= 0 || lower === 'html' ||
      lower.indexOf('content_rendered') >= 0 || lower.indexOf('reply_content_rendered') >= 0 ||
      lower.indexOf('payload_rendered') >= 0 || lower === 'body' || lower.indexOf('replycontent') >= 0 ||
      lower.indexOf('payload') >= 0 || (lower.indexOf('path') >= 0 && (lower.indexOf('delete') >= 0 || lower.indexOf('redeem') >= 0 || lower.indexOf('thank') >= 0 || lower.indexOf('favorite') >= 0))
  }

  private static looksLikeUrlKey(key: string): boolean {
    const lower = (key || '').toLowerCase()
    return lower === 'url' || lower.endsWith('url') || lower === 'href'
  }

  private static looksLikeUrl(value: string): boolean {
    return /^https?:\/\//i.test(value) || /^\/[a-z0-9/_-]+\?/i.test(value)
  }

  private static dropDangerousPath(value: string): string {
    return value
      .replace(/\/delete\/notification\/\d+/gi, '/delete/notification/<id>')
      .replace(/\/mission\/daily\/redeem/gi, '/mission/daily/redeem')
      .replace(/\/thank\/(reply|topic)\/\d+/gi, '/thank/$1/<id>')
      .replace(/\/favorite\/(topic|node)\/[^/?]+/gi, '/favorite/$1/<id>')
  }

  private static safeToken(value: string): string {
    return (value || '').replace(/[^a-zA-Z0-9_.:-]/g, '_').slice(0, 80)
  }

  private static fnv1a(value: string): string {
    let hash = 2166136261
    for (let i = 0; i < value.length; i += 1) {
      hash ^= value.charCodeAt(i)
      hash = Math.imul(hash, 16777619) >>> 0
    }
    return hash.toString(16)
  }
}
