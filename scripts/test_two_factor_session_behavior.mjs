#!/usr/bin/env node
// Runs production ETS logic in Node with synthetic responses and storage only.
import fs from 'node:fs'
import vm from 'node:vm'
import assert from 'node:assert/strict'
import { stripTypeScriptTypes } from 'node:module'

const root = process.cwd()
function load(rel, names, deps = {}) {
  const source = fs.readFileSync(`${root}/${rel}`, 'utf8')
    .replace(/^import[\s\S]*?from\s+['"][^'"]+['"]\s*\n/gm, '').replace(/^export /gm, '')
  const context = vm.createContext({ ...deps, console, setTimeout, clearTimeout })
  vm.runInContext(stripTypeScriptTypes(source, { mode: 'strip' }) + `\nglobalThis.result = {${names.join(',')}}`, context)
  return context.result
}
const network = 'shared/src/main/ets/network/'
const diagnostics = 'shared/src/main/ets/diagnostics/'
const { V2exCookieHeaders } = load(network + 'V2exCookieHeaders.ets', ['V2exCookieHeaders'])
assert.equal(V2exCookieHeaders.merge('A2=old; keep=ok', ['A2=B; Path=/', 'A2=A; Path=/']), 'A2=A; keep=ok')
assert.equal(V2exCookieHeaders.merge('A2=old', ['A2=A', 'A2=B', 'A2=A']), 'A2=A')
assert.equal(V2exCookieHeaders.merge('A2=old; keep=ok', ['A2=x; Max-Age=0']), 'keep=ok')
assert.equal(V2exCookieHeaders.merge('A2=old', ['A2=x; Expires=Wed, 01 Jan 2020 00:00:00 GMT']), '')
assert.equal(V2exCookieHeaders.merge('A2=old', ['A2=x; Max-Age=60; Expires=Wed, 01 Jan 2020 00:00:00 GMT']), 'A2=x')
assert.equal(V2exCookieHeaders.merge('', ['A2="value=="; HttpOnly']), 'A2="value=="')
assert.equal(V2exCookieHeaders.extract({ 'sEt-CoOkIe': 'A2=x; Expires=Wed, 01 Jan 2020 00:00:00 GMT, B=y' }).length, 2)

const entries = []
const { DiagnosticsRedactor } = load(diagnostics + 'DiagnosticsRedactor.ets', ['DiagnosticsRedactor'])
const record = (level, category, event, context) => entries.push(DiagnosticsRedactor.sanitizeEvent({ ts: Date.now(), level, category, event, message: event, context }))
const DiagnosticLogger = {
  info: (...args) => record('info', ...args), warn: (...args) => record('warn', ...args),
  exception: () => {},
}
const { TwoFactorTrace } = load(diagnostics + 'TwoFactorTrace.ets', ['TwoFactorTrace'], { DiagnosticLogger })
let activePersisted = 'A2=old-secret'
const state = { visible: false, cookie: '', source: '' }
const { TwoFactorChallengeService: service } = load('shared/src/main/ets/services/TwoFactorChallengeService.ets', ['TwoFactorChallengeService'], {
  TwoFactorTrace, CookieJarSettings: { getCurrentCookie: () => activePersisted },
  HttpClient: { getInstance: () => ({ getBaseUrl: () => 'https://www.v2ex.com' }) },
  publishTwoFactorVisible: value => state.visible = value,
  publishTwoFactorCookie: value => state.cookie = value,
  publishTwoFactorSource: value => state.source = value,
})
const http = { RequestMethod: { GET: 'GET', POST: 'POST' }, ResponseCode: { OK: 200 }, HttpDataType: { STRING: 0 } }
const ApiConstants = { BASE_URL_COM: 'https://www.v2ex.com' }
const parser = load('shared/src/main/ets/parser/V2exSigninParser.ets', ['V2exSigninParser'])
const session = load('shared/src/main/ets/parser/V2exSessionParser.ets', ['V2exSessionParser'])
const retry = load(network + 'HttpRetryPolicy.ets', ['HttpStatusError', 'HttpRetryPolicy', 'HttpJsonParseError'], { http })
let responses = []
const requests = []
const NetworkProxyRequest = { request: async (url, options) => {
  requests.push({ url, ...options })
  const response = responses.shift()
  assert.ok(response, `unexpected request ${url}`)
  if (response.throw) throw response.throw
  for (const headers of response.hops || [response.header]) options.onHeadersReceive?.(headers)
  return response
} }
const { HttpClient } = load(network + 'HttpClient.ets', ['HttpClient'], {
  http, ApiConstants, ...retry, NetworkProxyRequest, DiagnosticLogger, V2exCookieHeaders,
})
const ApiErrors = new Proxy({}, { get: (_, name) => () => new Error(String(name)) })
const authDeps = {
  ...parser, ...session, http, ApiConstants, HttpClient, NetworkProxyRequest, ApiErrors,
  TwoFactorTrace, V2exCookieHeaders, ...retry, NetworkProxySettings: { current: () => ({ mode: 'off' }) },
  V2exDomainUtils: { hostForBaseUrl: value => new URL(value).hostname, isV2exOwnedHost: host => host === 'www.v2ex.com' },
}
const { V2exNativeAuthService: Auth, NativeTwoFactorRequiredError } = load(network + 'V2exNativeAuthService.ets', ['V2exNativeAuthService', 'NativeTwoFactorRequiredError'], authDeps)
const { ApiService } = load(network + 'ApiService.ets', ['ApiService'], {
  ...authDeps, DiagnosticLogger, TwoFactorChallengeService: service,
  CookieJarSettings: { getCookieForBaseUrl: () => activePersisted },
  V2exCookieTwoFactorRequiredError: class extends Error {},
})
const response = (responseCode, result = '', header = {}, hops) => ({ responseCode, result, header, effectiveUrl: '', hops })
const form = nonce => `<form method="post" action="/2fa"><input name="code" type="text"><input type="hidden" name="once" value="${nonce}"><input type="submit" name="submit" value="不要重放"></form>`
const loggedIn = '<a class="top" href="/member/testuser">testuser</a><a href="/signout?once=synthetic">退出</a>'
assert.equal(session.V2exSessionParser.extractUsername(loggedIn), 'testuser')

// A normal request must pass the newly rotated session to the global prompt.
responses = [response(302, '', { location: '/2fa', 'set-cookie': 'A2=trigger-secret; Path=/' })]
const ordinary = await HttpClient.getInstance().requestTextResponse('/notifications', 'GET', 0, { Cookie: 'A2=old-secret' })
const api = Object.create(ApiService.prototype)
api.http = HttpClient.getInstance()
assert.throws(() => api.assertNoTwoFactorChallenge('/notifications', 'A2=old-secret', ordinary.text, ordinary.location, ordinary.setCookie, ordinary.statusCode))
assert.equal(state.cookie, 'A2=trigger-secret')
const trace = service.currentTrace()
service.request('A2=stale-secret', '/t/123')
assert.equal(service.currentTrace(), trace)
assert.equal(state.cookie, 'A2=trigger-secret')

// Failed POST rotates the session; retries must fetch a fresh form using that rotation.
const auth = new Auth()
responses = [
  response(200, form('nonce-one-secret'), { 'set-cookie': 'A2=form-secret' }),
  response(200, '<div class="problem"><ul><li>验证码不正确</li></ul></div>' + form('nonce-two-secret'), { 'set-cookie': 'A2=retry-secret' }),
]
let failure
try { await auth.completeTwoFactorWithCookie(state.cookie, '654321', trace) } catch (error) { failure = error }
assert.ok(failure instanceof NativeTwoFactorRequiredError)
assert.equal(requests.at(-1).header.Cookie, 'A2=form-secret')
assert.equal(requests.at(-1).extraData, 'code=654321&once=nonce-one-secret')
assert.equal(failure.challenge.cookie, 'A2=retry-secret')
service.updateRetry(trace, failure.challenge.cookie)
assert.equal(state.cookie, 'A2=retry-secret')
responses = [
  response(200, form('nonce-three-secret')),
  response(302, '', { location: '/', 'set-cookie': 'A2=verified-secret' }),
  response(200, loggedIn), response(200, loggedIn),
]
const result = await auth.completeTwoFactorWithCookie(service.retryCookie('A2=stale-secret'), '１２３４５６', trace)
assert.equal(requests.at(-4).header.Cookie, 'A2=retry-secret')
assert.equal(requests.at(-3).extraData, 'code=123456&once=nonce-three-secret')
assert.equal(requests.at(-2).header.Cookie, 'A2=verified-secret')
assert.equal(result.cookie, 'A2=verified-secret')
assert.equal(result.username, 'testuser')

// A login page/anti-bot response is not an empty 2FA form to POST blindly.
responses = [response(200, '<html>anti-bot</html>'), response(503, 'unavailable')]
await assert.rejects(auth.completeTwoFactorWithCookie('A2=old-secret', '123456', trace))
assert.equal(responses.length, 0)
responses = [response(503, 'unavailable', { 'set-cookie': 'A2=after-503-secret' })]
await assert.rejects(auth.completeTwoFactorWithCookie('A2=old-secret', '123456', trace), retry.HttpStatusError)
assert.equal(auth.getTwoFactorRetryCookie(), 'A2=after-503-secret')

// POST already succeeded before a verification network failure: recover without another code POST.
responses = [response(302, '', { location: '/' }), response(200, loggedIn), response(200, loggedIn)]
const beforeRecovery = requests.length
assert.equal((await auth.completeTwoFactorWithCookie('A2=verified-secret', '123456', trace)).username, 'testuser')
assert.ok(requests.slice(beforeRecovery).every(request => request.method === 'GET'))

// A 200 anti-bot page at the gated endpoint is not proof of completed verification.
responses = [response(302, '', { location: '/' }), response(200, '<html>checking your browser</html>')]
await assert.rejects(auth.completeTwoFactorWithCookie('A2=verified-secret', '123456', trace))
assert.equal(responses.length, 0)

// Response callbacks may observe A -> B -> A; final header duplication must not resurrect B.
responses = [response(200, form('nonce-four-secret'), { 'set-cookie': 'A2=A' }, [
  { 'set-cookie': 'A2=A' }, { 'set-cookie': 'A2=B' }, { 'set-cookie': 'A2=A' },
]), response(302, '', { location: '/' }), response(200, loggedIn), response(200, loggedIn)]
assert.equal((await auth.completeTwoFactorWithCookie('A2=old-secret', '123456', trace)).cookie, 'A2=A')

service.cancel()
service.request('A2=new-account-secret', 'nativeLogin')
service.updateRetry(trace, 'A2=stale-secret')
assert.equal(state.cookie, 'A2=new-account-secret')
assert.notEqual(service.currentTrace().flowId, trace.flowId)

// Verify the actual prompt catch wiring, not only the service API in isolation.
const promptSource = fs.readFileSync('entry/src/main/ets/components/V2exTwoFactorPrompt.ets', 'utf8')
const submitMethods = promptSource.slice(promptSource.indexOf('  private submit(): void'), promptSource.indexOf('  private async persistSnapshot('))
const promptContext = vm.createContext({
  TwoFactorChallengeService: service, TwoFactorTrace, NativeTwoFactorRequiredError,
  CookieJarSettings: { getCookieForBaseUrl: () => activePersisted },
  ApiErrors, AppStrings: { text: (_, fallback) => fallback }, $r: () => ({}), translateApiError: () => 'failure',
})
vm.runInContext(stripTypeScriptTypes(`class Prompt { ${submitMethods} }; globalThis.Prompt = Prompt`, { mode: 'strip' }), promptContext)
const prompt = new promptContext.Prompt()
prompt.auth = { completeTwoFactorWithCookie: async () => { throw failure }, getTwoFactorRetryCookie: () => '' }
prompt.http = HttpClient.getInstance()
prompt.getUIContext = () => ({ getHostContext: () => ({}) })
prompt.code = '123456'
prompt.cookie = 'A2=fallback-secret'
prompt.submit()
await new Promise(resolve => setImmediate(resolve))
assert.equal(service.retryCookie(''), 'A2=retry-secret')
assert.equal(prompt.isSubmitting, false)
assert.equal(prompt.code, '')

// A deleted session must not fall back to the original stale header.
const persistenceTrace = service.currentTrace()
activePersisted = 'A2=own-persisted-secret'
assert.equal(service.matchesContext(persistenceTrace), false)
service.acceptPersistedSession(persistenceTrace, 'A2=own-persisted-secret')
assert.equal(service.matchesContext(persistenceTrace), true)
service.updateRetry(service.currentTrace(), '')
assert.equal(service.retryCookie('A2=fallback-secret'), '')
activePersisted = 'A2=switched-secret'
assert.equal(service.matchesContext(service.currentTrace()), false)
service.cancel()
assert.throws(() => api.assertNoTwoFactorChallenge('/notifications', 'A2=old-secret', '', '/2fa', ['A2=late-secret'], 302))
assert.equal(state.visible, false, 'a late A response must not open a challenge over account B')
assert.equal(service.currentTrace(), undefined)
const output = JSON.stringify(entries)
for (const secret of ['old-secret', 'trigger-secret', 'retry-secret', 'verified-secret', 'nonce-one-secret', 'nonce-two-secret', '123456', '654321']) {
  assert.ok(!output.includes(secret), `sensitive value leaked: ${secret}`)
}
assert.ok(entries.some(entry => entry.event === 'response_received' && entry.context.challengeFieldPresent === true))
assert.ok(entries.some(entry => entry.event === 'response_received' && entry.context.problemKind === 'verification_rejected'))
assert.ok(entries.some(entry => entry.event === 'response_received' && entry.context.sessionChanged === true))
console.log('2FA behavior: rotation, once submission, retries, gated success, stale flows and log privacy PASS')

export { load, entries, DiagnosticsRedactor }
