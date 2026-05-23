import { http, socket } from '@kit.NetworkKit'
import util from '@ohos.util'
import type { NetworkProxySettingsSnapshot } from '../settings/NetworkProxySettings'
import type { NetworkProxyRequestOptions, NetworkProxyResponse } from './NetworkProxyRequest'
import { Socks5Handshake } from './Socks5Handshake'

/**
 * SOCKS5 HTTP/1.1 client built on top of `@ohos.net.socket` TCPSocket/TLSSocket
 * with a hand-rolled SOCKS5 handshake (`Socks5Handshake.ets`). The SDK's
 * `TCPConnectOptions.proxy` SOCKS5 path does not honour user/pass auth on
 * device — it always advertises no-auth only — so we drive the SOCKS5 bytes
 * ourselves on a raw TCP socket and (for HTTPS) wrap the tunnelled TCP with
 * `constructTLSSocketInstance(tcp)`.
 *
 * Scope: single-shot HTTP/1.1 over a SOCKS5 tunnel; `Connection: close` only;
 * no redirect following; no keep-alive; no compression (Accept-Encoding: identity).
 * Supports Content-Length and Transfer-Encoding: chunked response bodies.
 */
export class Socks5HttpClient {
  private static readonly DEFAULT_USER_AGENT = 'Mozilla/5.0'
  private static readonly DEFAULT_CONNECT_TIMEOUT_MS = 10000
  private static readonly DEFAULT_READ_TIMEOUT_MS = 15000

  static async request(
    url: string,
    options: NetworkProxyRequestOptions,
    settings: NetworkProxySettingsSnapshot,
  ): Promise<NetworkProxyResponse> {
    const target = Socks5HttpClient.parseUrl(url)
    const connectTimeout = options.connectTimeout || Socks5HttpClient.DEFAULT_CONNECT_TIMEOUT_MS
    const readTimeout = options.readTimeout || Socks5HttpClient.DEFAULT_READ_TIMEOUT_MS

    const proxyHost = settings.host
    const proxyPort = settings.port
    const username = settings.username || ''
    const password = settings.password || ''

    // Manual SOCKS5 handshake on a raw TCP socket — the SDK's ProxyOptions
    // user/pass path is broken on device (sub-negotiation never sent;
    // greeting always advertises no-auth only). See Socks5Handshake.ets.
    const credRedacted = username ? '<user>:<pass>@' : ''
    console.info(`[socks5-socket] connect start target=${target.host}:${target.port} scheme=${target.scheme} via ${credRedacted}${proxyHost}:${proxyPort}`)

    const requestBytes = Socks5HttpClient.buildRequestBytes(url, target, options)

    if (target.scheme === 'https') {
      return Socks5HttpClient.runTls(target, proxyHost, proxyPort, username, password, connectTimeout, readTimeout, requestBytes, options, url)
    }
    return Socks5HttpClient.runTcp(target, proxyHost, proxyPort, username, password, connectTimeout, readTimeout, requestBytes, options, url)
  }

  private static async runTcp(
    target: ParsedUrl,
    proxyHost: string,
    proxyPort: number,
    username: string,
    password: string,
    connectTimeout: number,
    readTimeout: number,
    requestBytes: Uint8Array,
    options: NetworkProxyRequestOptions,
    originalUrl: string,
  ): Promise<NetworkProxyResponse> {
    const tcp = socket.constructTCPSocketInstance()
    const reader = new ResponseReader()
    try {
      await tcp.connect({
        address: { address: proxyHost, port: proxyPort },
        timeout: connectTimeout,
      })
      await Socks5Handshake.perform(tcp, target.host, target.port, username, password, connectTimeout)
      Socks5HttpClient.attachTcpListeners(tcp, reader)
      console.info(`[socks5-socket] connect complete target=${target.host}:${target.port}`)
      const buf = Socks5HttpClient.uint8ToArrayBuffer(requestBytes)
      await tcp.send({ data: buf })
      console.info(`[socks5-socket] request sent bytes=${requestBytes.length}`)
      const bodyBytes = await reader.awaitComplete(readTimeout)
      return Socks5HttpClient.finalize(bodyBytes, reader, options, originalUrl)
    } finally {
      Socks5HttpClient.detachTcpListeners(tcp, reader)
      try { await tcp.close() } catch (_e) { /* ignore */ }
    }
  }

  private static async runTls(
    target: ParsedUrl,
    proxyHost: string,
    proxyPort: number,
    username: string,
    password: string,
    connectTimeout: number,
    readTimeout: number,
    requestBytes: Uint8Array,
    options: NetworkProxyRequestOptions,
    originalUrl: string,
  ): Promise<NetworkProxyResponse> {
    // Layered transport: raw TCP → manual SOCKS5 handshake → TLS wrap. The
    // SDK's TCPConnectOptions.proxy SOCKS5 path does not honour user/pass
    // credentials on device (greeting always advertises no-auth only), so
    // we drive the SOCKS5 bytes ourselves on a raw TCP socket; then
    // `constructTLSSocketInstance(tcp)` upgrades the tunnelled TCP to TLS
    // against the real target's SNI/cert.
    const tcp = socket.constructTCPSocketInstance()
    let tls: socket.TLSSocket | null = null
    const reader = new ResponseReader()
    try {
      await tcp.connect({
        address: { address: proxyHost, port: proxyPort },
        timeout: connectTimeout,
      })
      await Socks5Handshake.perform(tcp, target.host, target.port, username, password, connectTimeout)
      console.info(`[socks5-socket] socks5-tcp-up target=${target.host}:${target.port}`)
      try {
        tls = socket.constructTLSSocketInstance(tcp)
      } catch (e) {
        const err = e as Error
        throw new Error(`constructTLSSocketInstance(tcp) failed: ${err && err.message ? err.message : err}`)
      }
      Socks5HttpClient.attachTlsListeners(tls, reader)
      await tls.connect({
        address: { address: target.host, port: target.port },
        secureOptions: {
          protocols: [socket.Protocol.TLSv12, socket.Protocol.TLSv13],
        },
        ALPNProtocols: ['http/1.1'],
      })
      console.info(`[socks5-socket] tls-handshake-up target=${target.host}:${target.port}`)
      console.info(`[socks5-socket] connect complete target=${target.host}:${target.port}`)
      const buf = Socks5HttpClient.uint8ToArrayBuffer(requestBytes)
      await tls.send(buf)
      console.info(`[socks5-socket] request sent bytes=${requestBytes.length}`)
      const bodyBytes = await reader.awaitComplete(readTimeout)
      return Socks5HttpClient.finalize(bodyBytes, reader, options, originalUrl)
    } finally {
      if (tls) {
        Socks5HttpClient.detachTlsListeners(tls, reader)
        try { await tls.close() } catch (_e) { /* ignore */ }
      }
      try { await tcp.close() } catch (_e) { /* ignore */ }
    }
  }

  private static attachTcpListeners(s: socket.TCPSocket, reader: ResponseReader): void {
    s.on('message', reader.messageHandler)
    s.on('close', reader.closeHandler)
    s.on('error', reader.errorHandler)
  }
  private static detachTcpListeners(s: socket.TCPSocket, reader: ResponseReader): void {
    try { s.off('message', reader.messageHandler) } catch (_e) { /* ignore */ }
    try { s.off('close', reader.closeHandler) } catch (_e) { /* ignore */ }
    try { s.off('error', reader.errorHandler) } catch (_e) { /* ignore */ }
  }
  private static attachTlsListeners(s: socket.TLSSocket, reader: ResponseReader): void {
    s.on('message', reader.messageHandler)
    s.on('close', reader.closeHandler)
    s.on('error', reader.errorHandler)
  }
  private static detachTlsListeners(s: socket.TLSSocket, reader: ResponseReader): void {
    try { s.off('message', reader.messageHandler) } catch (_e) { /* ignore */ }
    try { s.off('close', reader.closeHandler) } catch (_e) { /* ignore */ }
    try { s.off('error', reader.errorHandler) } catch (_e) { /* ignore */ }
  }

  private static finalize(
    rawBytes: Uint8Array,
    reader: ResponseReader,
    options: NetworkProxyRequestOptions,
    originalUrl: string,
  ): NetworkProxyResponse {
    const parsed = Socks5HttpClient.parseResponse(rawBytes)
    if (options.onHeadersReceive) {
      options.onHeadersReceive(parsed.header as Object)
    }
    const wantsArrayBuffer = options.expectDataType === http.HttpDataType.ARRAY_BUFFER
    const result: string | ArrayBuffer = wantsArrayBuffer
      ? Socks5HttpClient.uint8ToArrayBuffer(parsed.body)
      : Socks5HttpClient.decodeUtf8(parsed.body)
    console.info(`[socks5-socket] parse complete status=${parsed.responseCode} bodyBytes=${parsed.body.length}`)
    return {
      responseCode: parsed.responseCode,
      result,
      header: parsed.header as Object,
      effectiveUrl: originalUrl,
    }
  }

  // ─── URL / request building ──────────────────────────────────────────────

  private static parseUrl(url: string): ParsedUrl {
    // scheme://host[:port]/path?query
    const schemeIdx = url.indexOf('://')
    if (schemeIdx < 0) {
      throw new Error(`Invalid URL: ${url}`)
    }
    const scheme = url.substring(0, schemeIdx).toLowerCase()
    if (scheme !== 'http' && scheme !== 'https') {
      throw new Error(`Unsupported scheme for SOCKS5 proxy: ${scheme}`)
    }
    const rest = url.substring(schemeIdx + 3)
    const pathStart = rest.indexOf('/')
    const authority = pathStart < 0 ? rest : rest.substring(0, pathStart)
    const pathAndQuery = pathStart < 0 ? '/' : rest.substring(pathStart)
    let host = authority
    let port = scheme === 'https' ? 443 : 80
    // Strip optional userinfo (defensive; v2ex urls don't have it)
    const atIdx = host.indexOf('@')
    if (atIdx >= 0) {
      host = host.substring(atIdx + 1)
    }
    // IPv6 [::1]:port
    if (host.startsWith('[')) {
      const close = host.indexOf(']')
      if (close < 0) throw new Error(`Invalid IPv6 host: ${authority}`)
      const after = host.substring(close + 1)
      const hostOnly = host.substring(1, close)
      if (after.startsWith(':')) {
        const p = Number(after.substring(1))
        if (!Number.isFinite(p) || p <= 0 || p > 65535) throw new Error(`Invalid port: ${after}`)
        port = p
      }
      host = hostOnly
    } else {
      const colonIdx = host.lastIndexOf(':')
      if (colonIdx >= 0) {
        const p = Number(host.substring(colonIdx + 1))
        if (!Number.isFinite(p) || p <= 0 || p > 65535) throw new Error(`Invalid port in URL: ${url}`)
        port = p
        host = host.substring(0, colonIdx)
      }
    }
    if (host.length === 0) throw new Error(`Empty host in URL: ${url}`)
    return { scheme, host, port, pathAndQuery }
  }

  private static buildRequestBytes(
    url: string,
    target: ParsedUrl,
    options: NetworkProxyRequestOptions,
  ): Uint8Array {
    const method = Socks5HttpClient.methodToString(options.method)
    const callerHeaders = options.header || {}
    // Track which canonical keys to emit. We use parallel arrays so we can
    // honour caller header ordering while still overriding forced fields
    // (Accept-Encoding, Connection) without using the `delete` operator
    // (forbidden by arkts-no-delete).
    const keys: string[] = []
    const values: Record<string, string> = {}
    const seen: Record<string, string> = {}
    const FORCED_ACCEPT_ENCODING = 'identity'
    const FORCED_CONNECTION = 'close'
    Object.keys(callerHeaders).forEach((k: string) => {
      const lk = k.toLowerCase()
      // Skip caller-provided Accept-Encoding / Connection; we always force ours.
      if (lk === 'accept-encoding' || lk === 'connection') {
        return
      }
      if (seen[lk]) {
        values[seen[lk]] = callerHeaders[k]
        return
      }
      seen[lk] = k
      keys.push(k)
      values[k] = callerHeaders[k]
    })
    const ensure = (canonical: string, value: string) => {
      const lk = canonical.toLowerCase()
      if (!seen[lk]) {
        seen[lk] = canonical
        keys.push(canonical)
        values[canonical] = value
      }
    }
    ensure('Host', target.port === (target.scheme === 'https' ? 443 : 80) ? target.host : `${target.host}:${target.port}`)
    ensure('User-Agent', Socks5HttpClient.DEFAULT_USER_AGENT)
    ensure('Accept-Encoding', FORCED_ACCEPT_ENCODING)
    ensure('Connection', FORCED_CONNECTION)

    let bodyBytes: Uint8Array | null = null
    if (options.extraData !== undefined && options.extraData !== null) {
      const raw = options.extraData
      if (typeof raw === 'string') {
        bodyBytes = new util.TextEncoder().encodeInto(raw as string)
      } else {
        // ArkTS: future-proof; current interface declares string only.
        bodyBytes = new Uint8Array(raw as ArrayBuffer)
      }
      ensure('Content-Length', String(bodyBytes.length))
    }

    let head = `${method} ${target.pathAndQuery} HTTP/1.1\r\n`
    for (let i = 0; i < keys.length; i++) {
      const k = keys[i]
      head += `${k}: ${values[k]}\r\n`
    }
    head += '\r\n'
    const headBytes = new util.TextEncoder().encodeInto(head)
    if (!bodyBytes) {
      return headBytes
    }
    const out = new Uint8Array(headBytes.length + bodyBytes.length)
    out.set(headBytes, 0)
    out.set(bodyBytes, headBytes.length)
    return out
  }

  private static methodToString(m: http.RequestMethod): string {
    if (m === http.RequestMethod.POST) return 'POST'
    if (m === http.RequestMethod.PUT) return 'PUT'
    if (m === http.RequestMethod.DELETE) return 'DELETE'
    if (m === http.RequestMethod.HEAD) return 'HEAD'
    if (m === http.RequestMethod.OPTIONS) return 'OPTIONS'
    if (m === http.RequestMethod.CONNECT) return 'CONNECT'
    if (m === http.RequestMethod.TRACE) return 'TRACE'
    return 'GET'
  }

  // ─── Response parsing ────────────────────────────────────────────────────

  private static parseResponse(raw: Uint8Array): ParsedResponse {
    const headerEnd = Socks5HttpClient.findHeaderTerminator(raw)
    if (headerEnd < 0) {
      throw new Error(`Malformed HTTP response: header terminator not found (bytes=${raw.length})`)
    }
    const headerText = Socks5HttpClient.decodeAscii(raw.subarray(0, headerEnd))
    const lines = headerText.split('\r\n')
    const statusLine = lines[0] || ''
    const statusMatch = statusLine.match(/^HTTP\/1\.[01] (\d{3})(?: (.*))?$/)
    if (!statusMatch) {
      throw new Error(`Malformed HTTP status line: ${statusLine}`)
    }
    const responseCode = Number(statusMatch[1])

    const header: Record<string, string> = {}
    const headerLower: Record<string, string> = {}
    for (let i = 1; i < lines.length; i++) {
      const line = lines[i]
      if (!line) continue
      const colon = line.indexOf(':')
      if (colon <= 0) continue
      const name = line.substring(0, colon).trim()
      const value = line.substring(colon + 1).trim()
      // Multiple Set-Cookie headers: comma-join (preserves visibility; callers
      // that need per-cookie parsing use http path, not socks5).
      const lname = name.toLowerCase()
      if (header[name] !== undefined) {
        header[name] = `${header[name]}, ${value}`
        headerLower[lname] = header[name]
      } else {
        header[name] = value
        headerLower[lname] = value
      }
    }

    const bodyStart = headerEnd + 4 // skip "\r\n\r\n"
    const bodyRaw = raw.subarray(bodyStart)

    const transferEncoding = (headerLower['transfer-encoding'] || '').toLowerCase()
    const contentEncoding = (headerLower['content-encoding'] || '').toLowerCase()
    if (contentEncoding && contentEncoding !== 'identity') {
      throw new Error(`Unsupported Content-Encoding for SOCKS5 path: ${contentEncoding}`)
    }

    let body: Uint8Array
    if (transferEncoding.indexOf('chunked') >= 0) {
      body = Socks5HttpClient.decodeChunked(bodyRaw)
    } else if (headerLower['content-length'] !== undefined) {
      const declared = Number(headerLower['content-length'])
      if (!Number.isFinite(declared) || declared < 0) {
        throw new Error(`Invalid Content-Length: ${headerLower['content-length']}`)
      }
      body = bodyRaw.length >= declared ? bodyRaw.subarray(0, declared) : bodyRaw
    } else {
      body = bodyRaw
    }

    return { responseCode, header, body }
  }

  private static findHeaderTerminator(buf: Uint8Array): number {
    for (let i = 0; i + 3 < buf.length; i++) {
      if (buf[i] === 0x0d && buf[i + 1] === 0x0a && buf[i + 2] === 0x0d && buf[i + 3] === 0x0a) {
        return i
      }
    }
    return -1
  }

  private static decodeChunked(buf: Uint8Array): Uint8Array {
    const chunks: Uint8Array[] = []
    let off = 0
    let total = 0
    while (off < buf.length) {
      // Read size line
      let lineEnd = -1
      for (let i = off; i + 1 < buf.length; i++) {
        if (buf[i] === 0x0d && buf[i + 1] === 0x0a) { lineEnd = i; break }
      }
      if (lineEnd < 0) {
        throw new Error('Malformed chunked response: missing size line CRLF')
      }
      const sizeLine = Socks5HttpClient.decodeAscii(buf.subarray(off, lineEnd))
      // Strip chunk extensions after ';'
      const semi = sizeLine.indexOf(';')
      const sizeHex = (semi >= 0 ? sizeLine.substring(0, semi) : sizeLine).trim()
      const size = parseInt(sizeHex, 16)
      if (!Number.isFinite(size) || size < 0) {
        throw new Error(`Malformed chunk size: "${sizeLine}"`)
      }
      off = lineEnd + 2
      if (size === 0) {
        break // ignore trailers
      }
      if (off + size > buf.length) {
        throw new Error(`Truncated chunk: declared=${size} available=${buf.length - off}`)
      }
      chunks.push(buf.subarray(off, off + size))
      total += size
      off += size
      // Trailing CRLF after chunk data
      if (off + 1 < buf.length && buf[off] === 0x0d && buf[off + 1] === 0x0a) {
        off += 2
      }
    }
    const out = new Uint8Array(total)
    let pos = 0
    for (const c of chunks) {
      out.set(c, pos)
      pos += c.length
    }
    return out
  }

  // ─── Encoding helpers ────────────────────────────────────────────────────

  private static decodeUtf8(buf: Uint8Array): string {
    if (buf.length === 0) return ''
    const decoder = util.TextDecoder.create('utf-8')
    return decoder.decodeToString(buf)
  }

  private static decodeAscii(buf: Uint8Array): string {
    // Header bytes are ASCII per RFC 7230; reuse UTF-8 decoder safely.
    return Socks5HttpClient.decodeUtf8(buf)
  }

  private static uint8ToArrayBuffer(u8: Uint8Array): ArrayBuffer {
    // Always copy into a fresh ArrayBuffer to guarantee independence from
    // the source view's offset/length.
    const out = new ArrayBuffer(u8.length)
    new Uint8Array(out).set(u8)
    return out
  }
}

interface ParsedUrl {
  scheme: 'http' | 'https'
  host: string
  port: number
  pathAndQuery: string
}

interface ParsedResponse {
  responseCode: number
  header: Record<string, string>
  body: Uint8Array
}

/**
 * Accumulates `socket.on('message')` chunks and resolves either when the
 * socket emits `close` or when Content-Length/chunked-terminator is reached.
 * For `Connection: close` responses we rely on `close`; we also support an
 * inactivity-based read timeout.
 */
class ResponseReader {
  private chunks: Uint8Array[] = []
  private totalLen = 0
  private settled = false
  private resolver: ((value: Uint8Array) => void) | null = null
  private rejecter: ((reason: Error) => void) | null = null
  private firstBytesLogged = false
  private inactivityTimer: number | null = null
  private inactivityMs = 0

  messageHandler = (info: socket.SocketMessageInfo): void => {
    if (this.settled) return
    const view = new Uint8Array(info.message)
    if (view.length === 0) return
    // Copy because the underlying ArrayBuffer may be reused by the runtime.
    const copy = new Uint8Array(view.length)
    copy.set(view)
    this.chunks.push(copy)
    this.totalLen += copy.length
    if (!this.firstBytesLogged) {
      this.firstBytesLogged = true
      console.info(`[socks5-socket] first response bytes=${copy.length}`)
    }
    this.resetInactivityTimer()
  }

  closeHandler = (): void => {
    if (this.settled) return
    this.settle(null)
  }

  errorHandler = (err: Error): void => {
    if (this.settled) return
    this.settled = true
    this.clearTimer()
    const r = this.rejecter
    this.rejecter = null
    this.resolver = null
    if (r) r(err)
  }

  awaitComplete(readTimeoutMs: number): Promise<Uint8Array> {
    this.inactivityMs = readTimeoutMs > 0 ? readTimeoutMs : 0
    return new Promise<Uint8Array>((resolve: (v: Uint8Array) => void, reject: (e: Error) => void) => {
      if (this.settled) {
        resolve(this.collect())
        return
      }
      this.resolver = resolve
      this.rejecter = reject
      this.resetInactivityTimer()
    })
  }

  private settle(err: Error | null): void {
    this.settled = true
    this.clearTimer()
    if (err) {
      const r = this.rejecter
      this.rejecter = null
      this.resolver = null
      if (r) r(err)
      return
    }
    const r = this.resolver
    this.resolver = null
    this.rejecter = null
    if (r) r(this.collect())
  }

  private collect(): Uint8Array {
    const out = new Uint8Array(this.totalLen)
    let pos = 0
    for (const c of this.chunks) {
      out.set(c, pos)
      pos += c.length
    }
    return out
  }

  private resetInactivityTimer(): void {
    if (this.inactivityMs <= 0) return
    this.clearTimer()
    this.inactivityTimer = setTimeout(() => {
      if (this.settled) return
      this.settled = true
      const r = this.rejecter
      this.rejecter = null
      this.resolver = null
      if (r) r(new Error(`SOCKS5 read timeout after ${this.inactivityMs}ms (received=${this.totalLen})`))
    }, this.inactivityMs)
  }

  private clearTimer(): void {
    if (this.inactivityTimer !== null) {
      clearTimeout(this.inactivityTimer)
      this.inactivityTimer = null
    }
  }
}
