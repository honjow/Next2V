import { socket } from '@kit.NetworkKit'
import util from '@ohos.util'

/**
 * Manual SOCKS5 handshake (RFC 1928 + RFC 1929) over an already-connected
 * `socket.TCPSocket`.
 *
 * Why this exists: HarmonyOS `@ohos.net.socket` `ProxyOptions` honours the
 * `address` field but the runtime SOCKS5 implementation always negotiates
 * `0x00` (no-auth) regardless of the supplied `username` / `password`.
 * Servers requiring user/pass auth answer with `auth method not acceptable`
 * (native log: `socks5 auth failed, errCode:211`, source
 * `socks5_user_pass_method.cpp` is never reached). We bypass the SDK SOCKS5
 * layer and speak the protocol bytes ourselves on a raw TCP socket.
 *
 * Usage:
 *   const tcp = socket.constructTCPSocketInstance()
 *   await tcp.connect({ address: { address: proxyHost, port: proxyPort }, timeout })
 *   await Socks5Handshake.perform(tcp, target.host, target.port, user, pass, timeout)
 *   // tcp is now a transparent tunnel to target.host:target.port
 *
 * After `perform()` returns (success or throw) all listeners installed by
 * the handshake have been detached; the caller may freely install its own
 * `message` / `close` / `error` handlers.
 */
export class Socks5Handshake {
  private static readonly VER_SOCKS5 = 0x05
  private static readonly VER_AUTH_SUBNEG = 0x01
  private static readonly METHOD_NO_AUTH = 0x00
  private static readonly METHOD_USER_PASS = 0x02
  private static readonly METHOD_NO_ACCEPTABLE = 0xff
  private static readonly CMD_CONNECT = 0x01
  private static readonly ATYP_IPV4 = 0x01
  private static readonly ATYP_DOMAIN = 0x03
  private static readonly ATYP_IPV6 = 0x04

  static async perform(
    tcp: socket.TCPSocket,
    targetHost: string,
    targetPort: number,
    username: string,
    password: string,
    timeoutMs: number,
  ): Promise<void> {
    if (!targetHost || targetHost.length === 0) throw new Error('socks5: empty target host')
    if (!Number.isFinite(targetPort) || targetPort <= 0 || targetPort > 65535) {
      throw new Error(`socks5: invalid target port ${targetPort}`)
    }
    const reader = new HandshakeReader()
    const onMessage = (info: socket.SocketMessageInfo): void => {
      reader.onBytes(new Uint8Array(info.message))
    }
    const onError = (err: Error): void => {
      reader.onError(err)
    }
    const onClose = (): void => {
      reader.onError(new Error('socks5: socket closed during handshake'))
    }
    tcp.on('message', onMessage)
    tcp.on('error', onError)
    tcp.on('close', onClose)
    const effectiveTimeout = timeoutMs > 0 ? timeoutMs : 10000
    try {
      // ── Phase 1: greeting ─────────────────────────────────────────────
      const greeting = new Uint8Array([
        Socks5Handshake.VER_SOCKS5,
        0x02,
        Socks5Handshake.METHOD_NO_AUTH,
        Socks5Handshake.METHOD_USER_PASS,
      ])
      await tcp.send({ data: Socks5Handshake.uint8ToArrayBuffer(greeting) })
      console.info('[socks5-manual] greeting sent')

      const methodResp = await Socks5Handshake.withTimeout(
        reader.readExact(2), effectiveTimeout, 'greeting')
      if (methodResp[0] !== Socks5Handshake.VER_SOCKS5) {
        throw new Error(`socks5: bad greeting version 0x${methodResp[0].toString(16)}`)
      }
      const method = methodResp[1]
      console.info(`[socks5-manual] method selected=0x${Socks5Handshake.hex2(method)}`)
      if (method === Socks5Handshake.METHOD_NO_ACCEPTABLE) {
        throw new Error('socks5: server selected unsupported method 0xff (no acceptable methods)')
      }

      // ── Phase 2: optional user/pass sub-negotiation ───────────────────
      if (method === Socks5Handshake.METHOD_USER_PASS) {
        if (!username) {
          throw new Error('socks5: server requires user/pass auth but no credentials configured')
        }
        const enc = new util.TextEncoder()
        const ub = enc.encodeInto(username)
        const pb = enc.encodeInto(password || '')
        if (ub.length === 0 || ub.length > 255) {
          throw new Error(`socks5: username byte length out of range (${ub.length})`)
        }
        if (pb.length > 255) {
          throw new Error(`socks5: password byte length out of range (${pb.length})`)
        }
        const authReq = new Uint8Array(3 + ub.length + pb.length)
        authReq[0] = Socks5Handshake.VER_AUTH_SUBNEG
        authReq[1] = ub.length
        authReq.set(ub, 2)
        authReq[2 + ub.length] = pb.length
        authReq.set(pb, 3 + ub.length)
        await tcp.send({ data: Socks5Handshake.uint8ToArrayBuffer(authReq) })

        const authResp = await Socks5Handshake.withTimeout(
          reader.readExact(2), effectiveTimeout, 'auth')
        if (authResp[0] !== Socks5Handshake.VER_AUTH_SUBNEG) {
          throw new Error(`socks5: bad auth subneg version 0x${authResp[0].toString(16)}`)
        }
        if (authResp[1] !== 0x00) {
          throw new Error(`socks5: auth failed status=0x${Socks5Handshake.hex2(authResp[1])}`)
        }
        console.info('[socks5-manual] auth ok')
      } else if (method !== Socks5Handshake.METHOD_NO_AUTH) {
        throw new Error(`socks5: server selected unsupported method 0x${Socks5Handshake.hex2(method)}`)
      }

      // ── Phase 3: CONNECT request ──────────────────────────────────────
      const hostBytes = new util.TextEncoder().encodeInto(targetHost)
      if (hostBytes.length === 0 || hostBytes.length > 255) {
        throw new Error(`socks5: target host byte length out of range (${hostBytes.length})`)
      }
      const req = new Uint8Array(4 + 1 + hostBytes.length + 2)
      req[0] = Socks5Handshake.VER_SOCKS5
      req[1] = Socks5Handshake.CMD_CONNECT
      req[2] = 0x00
      req[3] = Socks5Handshake.ATYP_DOMAIN
      req[4] = hostBytes.length
      req.set(hostBytes, 5)
      const portOff = 5 + hostBytes.length
      req[portOff] = (targetPort >> 8) & 0xff
      req[portOff + 1] = targetPort & 0xff
      await tcp.send({ data: Socks5Handshake.uint8ToArrayBuffer(req) })
      console.info(`[socks5-manual] connect req sent target=${targetHost}:${targetPort}`)

      // ── Phase 4: CONNECT response ─────────────────────────────────────
      const head = await Socks5Handshake.withTimeout(
        reader.readExact(4), effectiveTimeout, 'connect-head')
      if (head[0] !== Socks5Handshake.VER_SOCKS5) {
        throw new Error(`socks5: bad connect response version 0x${Socks5Handshake.hex2(head[0])}`)
      }
      const rep = head[1]
      if (rep !== 0x00) {
        throw new Error(`socks5: connect rep=0x${Socks5Handshake.hex2(rep)} (${Socks5Handshake.repName(rep)})`)
      }
      const atyp = head[3]
      let bndLen: number
      if (atyp === Socks5Handshake.ATYP_IPV4) {
        bndLen = 4
      } else if (atyp === Socks5Handshake.ATYP_IPV6) {
        bndLen = 16
      } else if (atyp === Socks5Handshake.ATYP_DOMAIN) {
        const lenByte = await Socks5Handshake.withTimeout(
          reader.readExact(1), effectiveTimeout, 'connect-bnd-len')
        bndLen = lenByte[0]
      } else {
        throw new Error(`socks5: unknown bnd atyp 0x${Socks5Handshake.hex2(atyp)}`)
      }
      // consume BND.ADDR + BND.PORT (2 bytes)
      await Socks5Handshake.withTimeout(
        reader.readExact(bndLen + 2), effectiveTimeout, 'connect-bnd-tail')

      if (reader.remaining() !== 0) {
        // Should never happen in practice: target won't speak before we do.
        // If a server pre-sends bytes we'd lose them when we detach. Surface
        // it loudly so we can revisit; in normal flow the buffer is empty.
        console.warn(`[socks5-manual] unexpected ${reader.remaining()} bytes buffered after handshake`)
      }
      console.info('[socks5-manual] tunnel up rep=0x00')
    } finally {
      try { tcp.off('message', onMessage) } catch (_e) { /* ignore */ }
      try { tcp.off('error', onError) } catch (_e) { /* ignore */ }
      try { tcp.off('close', onClose) } catch (_e) { /* ignore */ }
    }
  }

  private static withTimeout<T>(p: Promise<T>, ms: number, phase: string): Promise<T> {
    return new Promise<T>((resolve: (v: T) => void, reject: (e: Error) => void) => {
      let done = false
      const timer = setTimeout(() => {
        if (done) return
        done = true
        reject(new Error(`socks5: ${phase} timeout after ${ms}ms`))
      }, ms)
      p.then((v: T) => {
        if (done) return
        done = true
        clearTimeout(timer)
        resolve(v)
      }).catch((e: Error) => {
        if (done) return
        done = true
        clearTimeout(timer)
        reject(e)
      })
    })
  }

  private static uint8ToArrayBuffer(u8: Uint8Array): ArrayBuffer {
    const out = new ArrayBuffer(u8.length)
    new Uint8Array(out).set(u8)
    return out
  }

  private static hex2(n: number): string {
    const h = (n & 0xff).toString(16)
    return h.length === 1 ? `0${h}` : h
  }

  private static repName(rep: number): string {
    if (rep === 0x01) return 'general SOCKS server failure'
    if (rep === 0x02) return 'connection not allowed by ruleset'
    if (rep === 0x03) return 'Network unreachable'
    if (rep === 0x04) return 'Host unreachable'
    if (rep === 0x05) return 'Connection refused'
    if (rep === 0x06) return 'TTL expired'
    if (rep === 0x07) return 'Command not supported'
    if (rep === 0x08) return 'Address type not supported'
    return 'unknown'
  }
}

/**
 * Byte-buffering reader used during the handshake. Caller pumps bytes via
 * `onBytes()` from a `socket.on('message')` listener; consumers `await
 * readExact(n)` to pull exactly `n` bytes off the front of the buffer.
 */
class HandshakeReader {
  private chunks: Uint8Array[] = []
  private total = 0
  private pending: PendingRead | null = null
  private error: Error | null = null

  onBytes(view: Uint8Array): void {
    if (this.error) return
    if (view.length === 0) return
    const copy = new Uint8Array(view.length)
    copy.set(view)
    this.chunks.push(copy)
    this.total += copy.length
    this.tryServe()
  }

  onError(err: Error): void {
    if (this.error) return
    this.error = err
    if (this.pending) {
      const p = this.pending
      this.pending = null
      p.reject(err)
    }
  }

  remaining(): number {
    return this.total
  }

  readExact(n: number): Promise<Uint8Array> {
    if (n <= 0) return Promise.resolve(new Uint8Array(0))
    return new Promise<Uint8Array>((resolve: (v: Uint8Array) => void, reject: (e: Error) => void) => {
      if (this.error) {
        reject(this.error)
        return
      }
      if (this.pending) {
        reject(new Error('socks5: concurrent readExact not supported'))
        return
      }
      this.pending = { need: n, resolve, reject }
      this.tryServe()
    })
  }

  private tryServe(): void {
    if (!this.pending) return
    if (this.total < this.pending.need) return
    const need = this.pending.need
    const out = new Uint8Array(need)
    let written = 0
    while (written < need) {
      const head = this.chunks[0]
      const want = need - written
      if (head.length <= want) {
        out.set(head, written)
        written += head.length
        this.chunks.shift()
      } else {
        out.set(head.subarray(0, want), written)
        this.chunks[0] = head.subarray(want)
        written += want
      }
    }
    this.total -= need
    const p = this.pending
    this.pending = null
    p.resolve(out)
  }
}

interface PendingRead {
  need: number
  resolve: (v: Uint8Array) => void
  reject: (e: Error) => void
}
