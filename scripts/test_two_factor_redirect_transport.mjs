#!/usr/bin/env node
// Exercise the real transport selection with synthetic headers and no credentials.
import assert from 'node:assert/strict'
import { load } from './test_two_factor_session_behavior.mjs'

let settings = { mode: 'off', proxyScheme: 'http', exclusionList: [] }
let sentOptions
let incomingHeaders = { Location: '/', 'Set-Cookie': 'A2=synthetic' }
let failure = { code: 2300047 }
let sends = 0
let destroyed = 0
const http = {
  RequestMethod: { GET: 'GET', POST: 'POST' }, HttpDataType: { ARRAY_BUFFER: 1 },
  createHttp: () => {
    let onHeaders
    return {
      on: (_, callback) => { onHeaders = callback },
      request: async (_, options) => {
        sends++
        sentOptions = options
        if (incomingHeaders) onHeaders?.(incomingHeaders)
        if (failure) throw failure
        return { responseCode: 200, result: 'ok', header: {} }
      },
      destroy: () => { destroyed++ },
    }
  },
}
let rcpOptions
const rcp = {
  createSession: options => {
    rcpOptions = options
    return { fetch: async () => ({ statusCode: 302, headers: incomingHeaders, toString: () => '' }), close: () => {} }
  },
  Request: class {},
}
const NetworkProxySettings = {
  current: () => settings, normalize: value => value, validate: () => ({ ok: true }),
  buildHttpProxy: () => ({ host: 'proxy', port: 1234 }), buildHttpUrl: () => 'https://proxy:1234',
}
let socksCalls = 0
const Socks5HttpClient = { request: async () => { socksCalls++; return { responseCode: 302, header: {}, result: '' } } }
const { NetworkProxyRequest } = load('shared/src/main/ets/network/NetworkProxyRequest.ets', ['NetworkProxyRequest'], {
  http, rcp, NetworkProxySettings, Socks5HttpClient, ApiConstants: {},
})
const options = { method: 'POST', followRedirects: false }
for (const [mode, proxy] of [['off', false], ['system', true], ['http', 'proxy']]) {
  settings = { mode, proxyScheme: 'http', exclusionList: [] }
  const result = await NetworkProxyRequest.request('https://example.test/2fa', options)
  assert.equal(result.unfollowedRedirect, true)
  assert.equal(result.header.Location, '/')
  assert.equal(sentOptions.maxRedirects, 0)
  assert.equal(typeof proxy === 'string' ? sentOptions.usingProxy.host : sentOptions.usingProxy, proxy)
}
assert.equal(sends, 3, 'each one-time POST is sent only once')
assert.equal(destroyed, 3)
incomingHeaders = { 'Set-Cookie': 'A2=synthetic' }
await assert.rejects(NetworkProxyRequest.request('https://example.test/2fa', options), error => error.code === 2300047)
for (const value of [[], '  ', {}, ['  ']]) {
  incomingHeaders = { Location: value }
  await assert.rejects(NetworkProxyRequest.request('https://example.test/2fa', options), error => error.code === 2300047)
}
incomingHeaders = { Location: '/' }
failure = { code: 1234 }
await assert.rejects(NetworkProxyRequest.request('https://example.test/2fa', options), error => error.code === 1234)
failure = null
await NetworkProxyRequest.request('https://example.test/', { method: 'GET' })
assert.equal(sentOptions.maxRedirects, undefined)
settings = { mode: 'http', proxyScheme: 'https', exclusionList: [] }
await NetworkProxyRequest.request('https://example.test/2fa', options)
assert.equal(rcpOptions.requestConfiguration.transfer.autoRedirect, false)
settings = { mode: 'socks5', proxyScheme: 'socks5', exclusionList: [] }
await NetworkProxyRequest.request('https://example.test/2fa', options)
assert.equal(socksCalls, 1)
console.log('2FA redirect transport: single submission, headers, failures and proxy routes PASS')
