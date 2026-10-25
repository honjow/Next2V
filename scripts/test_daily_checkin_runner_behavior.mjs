#!/usr/bin/env node
// Executes the production runner methods; only ArkUI rendering and platform I/O are replaced.
import fs from 'node:fs'
import vm from 'node:vm'
import assert from 'node:assert/strict'
import { stripTypeScriptTypes } from 'node:module'

const scripts = fs.readFileSync('entry/src/main/ets/components/checkin/CheckinChallengeScripts.ets', 'utf8').replace(/export const/g, 'const')
const source = fs.readFileSync('entry/src/main/ets/components/DailyCheckinWebRunner.ets', 'utf8')
  .replace(/^import .*\n/gm, '')
  .replace(/^@ComponentV2\n/gm, '')
  .replace(/export struct /, 'class ')
  .replace(/@(Param|Event|Local)\s+/g, '')
  .replace(/^  @Monitor\([^\n]*\)\n/gm, '')
  .replace(/^  @Builder\n  private VerificationPrompt\(generation: number\) \{[\s\S]*?^  \}\n/gm, '')
  .replace(/^  @Builder\n  private VerificationContent\(\) \{[\s\S]*?^  \}\n/gm, '')
  .replace(/^  build\(\) \{[\s\S]*?^  \}\n/gm, '')
const flush = async () => { for (let i = 0; i < 8; i++) await Promise.resolve() }
function fixture() {
  const timers = new Map()
  let nextTimer = 0
  const results = []
  const diagnostics = []
  const controller = { loadUrl() {}, runJavaScript: async script => script.includes('var challenge=') ? 'content' : 'RClaimed' }
  const context = vm.createContext({
    webview: { WebviewController: class { constructor() { return controller } } },
    CookieJarSettings: { getCurrentCookie: () => 'fixture-session', isWebLoginCookieIsolationActive: () => false, restoreCurrentToWebCookieManager: async () => {} },
    connectAppForeground: () => ({ foreground: true }),
    AppPrompt: { modalSystemMaterial: () => undefined },
    DiagnosticLogger: { info: (...args) => diagnostics.push(args) },
    setTimeout: fn => { timers.set(++nextTimer, fn); return nextTimer },
    clearTimeout: id => timers.delete(id),
  })
  vm.runInContext(stripTypeScriptTypes(scripts + '\n' + source, { mode: 'strip' }) + '\nglobalThis.Runner = DailyCheckinWebRunner', context)
  const runner = new context.Runner()
  runner.trigger = 1
  runner.onRunResult = (status, coins) => results.push({ status, coins })
  runner.maybeStartRun()
  return { runner, controller, results, diagnostics, timeout: () => [...timers.values()].at(-1)() }
}
{
  const f = fixture()
  f.runner.step = 'redeem'
  f.runner.handleContent()
  await flush()
  assert.equal(f.runner.step, 'balance')
  f.timeout()
  assert.deepEqual(f.results, [{ status: 'success', coins: 0 }], 'confirmed claim must survive a balance timeout')
}
{
  const f = fixture()
  f.controller.loadUrl = () => { throw new Error('balance unavailable') }
  f.runner.step = 'redeem'
  f.runner.handleContent()
  await flush()
  assert.deepEqual(f.results, [{ status: 'success', coins: 0 }], 'balance load failure must not undo a confirmed claim')
}
{
  const f = fixture()
  f.runner.step = 'redeem'
  f.timeout()
  assert.deepEqual(f.results, [{ status: 'failed', coins: 0 }], 'without positive confirmation a timeout remains failure')
}
{
  const f = fixture()
  let resolveOld
  f.controller.runJavaScript = () => new Promise(resolve => { resolveOld = resolve })
  f.runner.step = 'redeem'
  f.runner.handleContent()
  f.timeout()
  f.runner.trigger = 2
  f.runner.maybeStartRun()
  resolveOld('RClaimed')
  await flush()
  assert.equal(f.runner.step, 'pending', 'late callback from a timed-out run must not navigate the new run')
  assert.equal(f.results.length, 1)
}
{
  const f = fixture()
  f.runner.step = 'redeem'
  f.controller.runJavaScript = async () => 'RWall'
  f.runner.handleContent()
  await flush()
  assert.deepEqual(f.results, [{ status: 'failed', coins: 0 }], 'anti-bot wall must never become success')
}
{
  const f = fixture()
  f.runner.onPageEnd({ url: 'https://www.v2ex.com/mission/daily/redeem?once=synthetic-secret' })
  f.timeout()
  assert.ok(f.diagnostics.some(entry => entry[1] === 'web_page_end' && entry[2].page === 'redeem'))
  assert.ok(f.diagnostics.some(entry => entry[1] === 'web_run_timeout' && entry[2].step === 'pending'))
  assert.equal(JSON.stringify(f.diagnostics).includes('synthetic-secret'), false, 'phase logs must not expose URL tokens')
}
console.log('PASS: confirmed claim, balance failures, unconfirmed timeout, late callbacks, anti-bot wall, redacted phases')

{
  const f = fixture()
  f.runner.step = 'mission'
  let page = 'challenge'
  let contentCalls = 0
  f.controller.runJavaScript = async script => {
    if (script.includes('var challenge=')) return page
    contentCalls++
    return 'DONE'
  }
  f.runner.onPageEnd({ url: 'https://www.v2ex.com/mission/daily' })
  await flush()
  assert.equal(f.runner.step, 'mission')
  assert.equal(contentCalls, 0, 'challenge must not execute claim DOM or advance phase')
  assert.equal(f.results.length, 0)
  page = 'content'
  f.runner.onPageEnd({ url: 'https://www.v2ex.com/mission/daily' })
  await flush()
  assert.deepEqual(f.results, [{ status: 'already', coins: 0 }])
}
{
  const f = fixture()
  f.runner.step = 'mission'
  f.controller.runJavaScript = async () => 'interactive'
  let offers = 0
  f.runner.offerVerification = () => { offers++; f.runner.promptShown = true }
  f.runner.onPageEnd()
  await flush()
  f.runner.onPageEnd()
  await flush()
  assert.equal(offers, 1, 'only a positive interactive signal offers manual verification')
  assert.equal(f.results.length, 0)
}

{
  const f = fixture()
  const dialogs = []
  const closed = []
  const prompt = {
    openCustomDialog: async options => { dialogs.push(options); return dialogs.length },
    closeCustomDialog: id => { closed.push(id) },
  }
  f.runner.getUIContext = () => ({ getPromptAction: () => prompt })
  f.runner.offerVerification()
  await flush()
  f.runner.finish('failed', 0)
  f.runner.trigger = 2
  f.runner.maybeStartRun()
  f.runner.offerVerification()
  await flush()
  dialogs[0].onWillDismiss({ dismiss() {} })
  assert.equal(f.runner.promptId, 2, 'a delayed dismissal must not clear a newer dialog identity')
  assert.equal(f.runner.active, true, 'a delayed dismissal must not finish a newer run')
  f.runner.finish('failed', 0)
  assert.deepEqual(closed, [1, 2], 'both runs must close their own verification dialogs')
}

{
  const f = fixture()
  const closed = []
  let resolveOpen
  const prompt = {
    openCustomDialog: () => new Promise(resolve => { resolveOpen = resolve }),
    closeCustomDialog: id => { closed.push(id) },
  }
  f.runner.getUIContext = () => ({ getPromptAction: () => prompt })
  f.runner.offerVerification()
  f.runner.finish('failed', 0)
  f.runner.trigger = 2
  f.runner.maybeStartRun()
  resolveOpen(7)
  await flush()
  assert.deepEqual(closed, [7], 'an opening dialog must still close if its run ends before the ID arrives')
  assert.equal(f.runner.promptId, -1)
  assert.equal(f.runner.active, true, 'late dialog creation must not finish the next run')
}
console.log('PASS: delayed dialog dismissal and creation stay isolated across runs')

{
  const f = fixture()
  let rejectOpen
  const prompt = {
    openCustomDialog: () => new Promise((resolve, reject) => { rejectOpen = reject }),
    closeCustomDialog() {},
  }
  f.runner.getUIContext = () => ({ getPromptAction: () => prompt })
  f.runner.offerVerification()
  f.runner.contentHandled = true
  f.runner.step = 'redeem'
  f.runner.closeVerificationPrompt()
  rejectOpen(new Error('dialog no longer available'))
  await flush()
  assert.equal(f.runner.active, true, 'a discarded prompt failure must not abort automatic verification progress')
  assert.equal(f.results.length, 0)
}
console.log('PASS: automatic challenge preserves phase; explicit interaction only')

{
  let listener
  const child = {}, other = {}
  // ArkWeb's closed-shadow widget is a direct child but is absent from window.frames.
  const window = { frames: [], addEventListener: (_, fn) => { listener = fn } }
  window.top = window
  child.parent = window
  const ctx = vm.createContext({ window })
  vm.runInContext(stripTypeScriptTypes(scripts, { mode: 'strip' }) + '\neval(CHECKIN_CHALLENGE_OBSERVER)', ctx)
  const event = { isTrusted: true, origin: 'https://challenges.cloudflare.com', source: child,
    data: { source: 'cloudflare-challenge', widgetId: 'widget-a', event: 'interactiveBegin' } }
  listener({ ...event, isTrusted: false })
  listener({ ...event, source: other })
  listener({ ...event, origin: 'https://untrusted.example' })
  assert.equal(window.__v2nextCheckinInteractive, false)
  listener(event)
  assert.equal(window.__v2nextCheckinInteractive, true)
  assert.equal(window.__v2nextCheckinNeedsInteraction(), true)
  child.closed = true
  assert.equal(window.__v2nextCheckinNeedsInteraction(), false, 'discarded children must not retain an interactive state')
  child.closed = false
  listener({ ...event, data: { ...event.data, widgetId: 'widget-b', event: 'complete' } })
  assert.equal(window.__v2nextCheckinInteractive, true, 'another widget must not clear the active interaction')
  listener({ ...event, data: { ...event.data, event: 'interactiveEnd' } })
  assert.equal(window.__v2nextCheckinInteractive, false)
}
console.log('PASS: production challenge observer rejects foreign/untrusted messages and separates widgets')

{
  const f = fixture()
  f.runner.step = 'mission'
  let calls = 0
  f.controller.runJavaScript = async script => {
    if (script.includes('var challenge=')) return 'content'
    calls++
    return calls === 1 ? 'GO' : 'RNoClaim'
  }
  f.runner.onPageEnd({ url: 'https://www.v2ex.com/mission/daily' })
  await flush()
  f.runner.onPageEnd({ url: 'https://www.v2ex.com/mission/daily' })
  await flush()
  assert.equal(calls, 1, 'the same document must not execute a later phase before navigation')
  assert.equal(f.results.length, 0)
}

{
  const f = fixture()
  f.runner.runCookie = 'previous-session'
  f.runner.claimConfirmed = true
  f.runner.finish('success', 12)
  assert.equal(f.results.length, 0, 'an old account result must not update the new active account')
  assert.equal(f.runner.active, false)
}

{
  const f = fixture()
  f.runner.runCookie = 'previous-session'
  f.runner.trigger = 2
  f.runner.maybeStartRun()
  assert.equal(f.runner.runCookie, 'fixture-session')
  assert.equal(f.runner.step, 'pending', 'new account trigger must not be swallowed by an obsolete run')
  assert.equal(f.results.length, 0)
}

{
  const f = fixture()
  f.runner.runCookie = 'previous-session'
  f.runner.controllerIsAttached = true
  f.runner.step = 'mission'
  const loaded = []
  f.controller.stop = () => {}
  f.controller.loadUrl = url => loaded.push(url)
  f.runner.trigger = 2
  f.runner.maybeStartRun()
  await flush()
  assert.deepEqual(loaded, ['https://www.v2ex.com/mission/daily'], 'retained Web must load the new mission without a second attachment event')
  assert.equal(f.results.length, 0)
}
