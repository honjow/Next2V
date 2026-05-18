#!/usr/bin/env node
import fs from 'node:fs'
import assert from 'node:assert/strict'

// Sanitized fixture/source assertions for the V2EX signin parser. This script mirrors the
// small parser surface so it can run under Node; the build validates the production ArkTS path.

function decodeHtml(value) {
  return value
    .replace(/&amp;/g, '&')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
}

function compactText(html) {
  return decodeHtml(html.replace(/<[^>]+>/g, ' ')).replace(/\s+/g, ' ').trim()
}

function extractAttr(tag, attrName) {
  const re = new RegExp(`${attrName}\\s*=\\s*(['"])(.*?)\\1`, 'i')
  const m = tag.match(re)
  return m && m[2] ? decodeHtml(m[2]) : ''
}

function inputContext(html, index, length) {
  const start = nearestContextStart(html, index)
  const end = nearestContextEnd(html, index + length)
  if (start >= 0 && end > index) return compactText(html.slice(start, end))
  const before = html.slice(Math.max(0, index - 64), index)
  const after = html.slice(index + length, Math.min(html.length, index + length + 64))
  return compactText(`${before} ${after}`)
}

function nearestContextStart(html, index) {
  const prefix = html.slice(0, index)
  const matches = prefix.match(/<(tr|div|p|label)\b[^>]*>/gi)
  if (!matches || matches.length === 0) return -1
  return prefix.lastIndexOf(matches[matches.length - 1])
}

function nearestContextEnd(html, index) {
  const suffix = html.slice(index)
  const m = suffix.match(/<\/(tr|div|p|label)>/i)
  return m && typeof m.index === 'number' ? index + m.index + m[0].length : -1
}

function extractInputs(html) {
  const inputs = []
  const re = /<input\b[^>]*>/gi
  let m = re.exec(html)
  while (m) {
    const tag = m[0]
    inputs.push({
      type: extractAttr(tag, 'type') || 'text',
      name: extractAttr(tag, 'name'),
      value: extractAttr(tag, 'value'),
      placeholder: extractAttr(tag, 'placeholder'),
      context: inputContext(html, m.index, tag.length)
    })
    m = re.exec(html)
  }
  return inputs
}

function inputValue(inputs, name) {
  const found = inputs.find(input => input.name === name)
  return found ? found.value : ''
}

function findInputNameByType(inputs, inputType) {
  const found = inputs.find(input => input.type.toLowerCase() === inputType && input.name)
  return found ? found.name : ''
}

function findUsernameField(inputs) {
  const namedTextInputs = inputs.filter(input => input.type.toLowerCase() === 'text' && input.name)
  const preferred = namedTextInputs.find(input => {
    const placeholder = input.placeholder.toLowerCase()
    return placeholder.includes('username') || placeholder.includes('email')
  })
  return preferred ? preferred.name : (namedTextInputs.length > 0 ? namedTextInputs[0].name : '')
}

function findCaptchaField(inputs) {
  const found = inputs.find(input => {
    const placeholder = input.placeholder.toLowerCase()
    const name = input.name.toLowerCase()
    const context = input.context.toLowerCase()
    return input.type.toLowerCase() === 'text' && input.name &&
      (placeholder.includes('captcha') ||
        placeholder.includes('code') ||
        placeholder.includes('验证码') ||
        name.includes('captcha') ||
        context.includes('captcha') ||
        context.includes('验证码'))
  })
  return found ? found.name : ''
}

function extractCaptchaUrl(html) {
  const imageRe = /<img\b[^>]*>/gi
  let m = imageRe.exec(html)
  while (m) {
    const tag = m[0]
    const alt = extractAttr(tag, 'alt').toLowerCase()
    const src = extractAttr(tag, 'src')
    if (src && (alt.includes('captcha') || src.includes('captcha'))) {
      return src
    }
    m = imageRe.exec(html)
  }
  return ''
}

function extractForm(html) {
  const inputs = extractInputs(html)
  const once = inputValue(inputs, 'once')
  const next = inputValue(inputs, 'next')
  const usernameField = findUsernameField(inputs)
  const passwordField = findInputNameByType(inputs, 'password')
  const captchaField = findCaptchaField(inputs)
  const captchaUrl = extractCaptchaUrl(html)
  if (!once || !next || !usernameField || !passwordField) return null
  return { usernameField, passwordField, captchaField, captchaUrl, once, next }
}

function extractProblemMessage(html) {
  const problemRe = /<div[^>]*class=['"][^'"]*problem[^'"]*['"][^>]*>([\s\S]*?)<\/div>/gi
  let problem = problemRe.exec(html)
  while (problem) {
    const message = problem[1] ? compactText(problem[1]) : ''
    if (message) return message
    problem = problemRe.exec(html)
  }
  return ''
}

function hasSigninForm(html) {
  const forms = extractForms(html)
  return forms.some(form => locationPath(extractFormAction(form)) === '/signin') || extractForm(html) !== null
}

function loginInputErrorMessage(challenge, problemMessage) {
  const problem = (problemMessage || '').trim()
  if (problem) {
    if (problem.includes('验证码') || problem.toLowerCase().includes('captcha')) {
      return '验证码不正确，请重新输入'
    }
    if (problem.includes('密码') || problem.toLowerCase().includes('password') ||
      problem.toLowerCase().includes('username') || problem.includes('用户名')) {
      return '用户名或密码不正确，请检查后重试'
    }
    return problem
  }
  return challenge.captchaField ? '用户名、密码或验证码不正确，请检查后重试' : '用户名或密码不正确，请检查后重试'
}

function extractForms(html) {
  const forms = []
  const re = /<form\b[^>]*>[\s\S]*?<\/form>/gi
  let m = re.exec(html)
  while (m) {
    forms.push(m[0])
    m = re.exec(html)
  }
  return forms
}

function looksLikeTwoFactorForm(html) {
  const text = compactText(html).toLowerCase()
  return text.includes('2fa') || text.includes('two-factor') || text.includes('two factor') ||
    text.includes('authentication code') || text.includes('one-time') || text.includes('totp') ||
    text.includes('两步') || text.includes('二步') || text.includes('动态验证码') || text.includes('安全码')
}

function looksLikeTwoFactorFormByActionOrInputs(html) {
  const actionPath = locationPath(extractFormAction(html))
  if (actionPath === '/2fa' || actionPath.indexOf('/2fa?') === 0) return true
  return findTwoFactorCodeField(extractInputs(html)) === 'code'
}

function extractFormAction(formHtml) {
  const formTag = formHtml.match(/<form\b[^>]*>/i)
  return formTag ? extractAttr(formTag[0], 'action') : ''
}

function findTwoFactorCodeField(inputs) {
  const candidates = inputs.filter(input => {
    const type = input.type.toLowerCase()
    return input.name && (type === 'text' || type === 'tel' || type === 'number' || type === 'password' || type === '')
  })
  const preferred = candidates.find(input => {
    const name = input.name.toLowerCase()
    const placeholder = input.placeholder.toLowerCase()
    return name.includes('2fa') || name.includes('otp') || name.includes('code') ||
      placeholder.includes('2fa') || placeholder.includes('otp') || placeholder.includes('code') ||
      placeholder.includes('验证码') || placeholder.includes('动态') || placeholder.includes('安全码')
  })
  return preferred ? preferred.name : (candidates.length === 1 ? candidates[0].name : '')
}

function extractTwoFactorForm(html) {
  const forms = extractForms(html)
  const preferred = forms.find(form => looksLikeTwoFactorForm(form)) ||
    forms.find(form => looksLikeTwoFactorFormByActionOrInputs(form)) ||
    (looksLikeTwoFactorForm(html) || looksLikeTwoFactorFormByActionOrInputs(html) ? html : '')
  if (!preferred) return null
  const inputs = extractInputs(preferred)
  const codeField = findTwoFactorCodeField(inputs)
  if (!codeField) return null
  const hiddenFields = {}
  inputs.filter(input => {
    const type = input.type.toLowerCase()
    return input.name && (type === 'hidden' || type === 'submit' || type === 'button')
  })
    .forEach(input => { hiddenFields[input.name] = input.value })
  return { action: extractFormAction(preferred), codeField, hiddenFields }
}

function locationPath(location) {
  const trimmed = (location || '').trim()
  if (!trimmed) return ''
  const schemeIdx = trimmed.indexOf('://')
  if (schemeIdx >= 0) {
    const pathStart = trimmed.indexOf('/', schemeIdx + 3)
    return pathStart >= 0 ? trimmed.slice(pathStart) : '/'
  }
  return trimmed.indexOf('/') === 0 ? trimmed : `/${trimmed}`
}

function isLocationPath(location, path) {
  if (!location || !path) return false
  const normalized = locationPath(location)
  return normalized === path || normalized.indexOf(`${path}?`) === 0
}

function memberNameFromHref(href) {
  const m = (href || '').match(/^\/member\/([0-9A-Za-z_]+)(?:[?#].*)?$/)
  return m && m[1] ? m[1] : ''
}

function hasClass(className, expected) {
  return (className || '').split(/\s+/).some(part => part === expected)
}

function extractSessionUsername(html) {
  const links = html.match(/<a\b[^>]*>/gi) || []
  for (const link of links) {
    const member = memberNameFromHref(extractAttr(link, 'href'))
    if (member && hasClass(extractAttr(link, 'class'), 'top')) return member
  }
  return ''
}

const signinChineseCaptcha = `
<form action="/signin" method="post">
  <input type="hidden" name="once" value="[REDACTED_ONCE]">
  <input type="hidden" name="next" value="/settings">
  <div class="row"><label>用户名</label><input type="text" name="u_redacted"></div>
  <div class="row"><label>密码</label><input type="password" name="p_redacted"></div>
  <div class="row"><label>验证码</label><img src="/captcha/[REDACTED].png" alt="captcha"><input type="text" name="captcha_redacted"></div>
</form>`

assert.deepEqual(extractForm(signinChineseCaptcha), {
  usernameField: 'u_redacted',
  passwordField: 'p_redacted',
  captchaField: 'captcha_redacted',
  captchaUrl: '/captcha/[REDACTED].png',
  once: '[REDACTED_ONCE]',
  next: '/settings'
})

const signinEnglishLiveCaptcha = `
<form method="post" action="/signin">
  <table>
    <tr><td>Username</td><td><input type="text" name="u_live_redacted" placeholder="Username or Email" /></td></tr>
    <tr><td>Password</td><td><input type="password" name="p_live_redacted" /></td></tr>
    <tr>
      <td>Are you robot?</td>
      <td>
        <img id="captcha-image" width="320" height="80" src="/_captcha" alt="CAPTCHA" onclick="refreshCaptcha()">
        <div class="sep10"></div>
        <input type="text" name="captcha_live_redacted" placeholder="Enter the code above, click to change">
      </td>
    </tr>
    <tr><td></td><td><input type="hidden" value="[REDACTED_ONCE]" name="once" /><input type="submit" value="Sign In" /></td></tr>
  </table>
  <input type="hidden" value="/settings" name="next" />
</form>`

assert.deepEqual(extractForm(signinEnglishLiveCaptcha), {
  usernameField: 'u_live_redacted',
  passwordField: 'p_live_redacted',
  captchaField: 'captcha_live_redacted',
  captchaUrl: '/_captcha',
  once: '[REDACTED_ONCE]',
  next: '/settings'
})

const signinProblemWithHiddenEmptyDiv = `
<div class="box">
  <div id="problem" class="problem topic_content markdown_body" style="display: none;"></div>
  <div class="problem">Please fix following problems and submit again:<ul><li>输入的验证码不正确。</li></ul></div>
  <form method="post" action="/signin">
    <input type="text" name="u_live_redacted" placeholder="Username or Email" />
    <input type="password" name="p_live_redacted" />
    <input type="text" name="captcha_live_redacted" placeholder="Enter the code above, click to change" />
    <input type="hidden" value="[REDACTED_ONCE]" name="once" />
    <input type="hidden" value="/settings" name="next" />
  </form>
</div>`
assert.equal(extractProblemMessage(signinProblemWithHiddenEmptyDiv), 'Please fix following problems and submit again: 输入的验证码不正确。')
assert.equal(hasSigninForm(signinProblemWithHiddenEmptyDiv), true)
assert.equal(hasSigninForm('<html><body><a class="top" href="/member/live_user">live_user</a></body></html>'), false)
assert.equal(loginInputErrorMessage({ captchaField: 'captcha_live_redacted' }, extractProblemMessage(signinProblemWithHiddenEmptyDiv)), '验证码不正确，请重新输入')
assert.equal(loginInputErrorMessage({ captchaField: 'captcha_live_redacted' }, 'Username or password is incorrect'), '用户名或密码不正确，请检查后重试')
assert.equal(loginInputErrorMessage({ captchaField: 'captcha_live_redacted' }, ''), '用户名、密码或验证码不正确，请检查后重试')
assert.equal(loginInputErrorMessage({ captchaField: '' }, ''), '用户名或密码不正确，请检查后重试')

const twoFactorFixture = `
<form action="2fa" method="post">
  <div>两步验证</div>
  <input type="hidden" name="once" value="[REDACTED_ONCE]">
  <input type="text" name="otp_redacted" placeholder="动态验证码或恢复码">
  <input type="submit" name="submit_redacted" value="继续">
</form>`
assert.deepEqual(extractTwoFactorForm(twoFactorFixture), {
  action: '2fa',
  codeField: 'otp_redacted',
  hiddenFields: { once: '[REDACTED_ONCE]', submit_redacted: '继续' }
})

const actionlessTwoFactorFixture = `
<form method="post">
  <div>Two-factor authentication code</div>
  <input type="hidden" name="once" value="[REDACTED_ONCE]">
  <input type="text" name="otp_redacted" placeholder="Authentication code">
</form>`
assert.deepEqual(extractTwoFactorForm(actionlessTwoFactorFixture), {
  action: '',
  codeField: 'otp_redacted',
  hiddenFields: { once: '[REDACTED_ONCE]' }
})

const passwordTwoFactorFixture = `
<form action="/2fa" method="post">
  <div>Two-factor authentication code</div>
  <input type="hidden" name="once" value="[REDACTED_ONCE]">
  <input type="password" name="code" autocomplete="one-time-code">
</form>`
assert.deepEqual(extractTwoFactorForm(passwordTwoFactorFixture), {
  action: '/2fa',
  codeField: 'code',
  hiddenFields: { once: '[REDACTED_ONCE]' }
})

const actionOnlyTwoFactorFixture = `
<form action="/2fa" method="post">
  <input type="hidden" name="once" value="[REDACTED_ONCE]">
  <input type="password" name="code" autocomplete="one-time-code">
</form>`
assert.deepEqual(extractTwoFactorForm(actionOnlyTwoFactorFixture), {
  action: '/2fa',
  codeField: 'code',
  hiddenFields: { once: '[REDACTED_ONCE]' }
})

const bareCodeTwoFactorFixture = `
<form method="post">
  <input type="hidden" name="once" value="[REDACTED_ONCE]">
  <input type="password" name="code">
</form>`
assert.deepEqual(extractTwoFactorForm(bareCodeTwoFactorFixture), {
  action: '',
  codeField: 'code',
  hiddenFields: { once: '[REDACTED_ONCE]' }
})

assert.equal(
  extractSessionUsername('<a class="top active" data-redacted="1" href="/member/live_user">live_user</a>'),
  'live_user'
)
assert.equal(
  extractSessionUsername('<a href="/member/live_user?from=settings" rel="me" class="top">live_user</a>'),
  'live_user'
)

const source = fs.readFileSync('shared/src/main/ets/parser/V2exSigninParser.ets', 'utf8')
assert.match(source, /context\.indexOf\('验证码'\)/)
assert.match(source, /placeholder\.indexOf\('验证码'\)/)
assert.match(source, /placeholder\.indexOf\('code'\)/)
assert.match(source, /src\.indexOf\('captcha'\)/)
assert.match(source, /private static inputContext/)
assert.match(source, /static hasSigninForm/)
assert.match(source, /let problem: RegExpExecArray \| null = problemRe\.exec\(html\)/)
assert.match(source, /while \(problem\)/)
assert.match(source, /looksLikeTwoFactorFormByActionOrInputs/)
assert.match(source, /actionPath === '\/2fa'/)
assert.match(source, /findTwoFactorCodeField\(inputs\) === 'code'/)
const service = fs.readFileSync('shared/src/main/ets/network/V2exNativeAuthService.ets', 'utf8')
assert.match(service, /twoFactorChallengeFromHtml/)
assert.match(service, /private static readonly TWO_FACTOR_PATH: string = '\/2fa'/)
assert.match(service, /isLocationPath\(postRes\.location, V2exNativeAuthService\.TWO_FACTOR_PATH\)/)
assert.match(service, /fixedTwoFactorChallenge\(cookieAfterPost/)
assert.match(service, /twoFactorFormPairs\(challenge, cleanCode\)/)
assert.match(service, /pairs\.push\(\{ key: challenge\.codeField \|\| 'code', value: cleanCode \}\)/)
assert.match(service, /action: twoFactor\.action \|\| V2exNativeAuthService\.TWO_FACTOR_PATH/)
assert.match(service, /codeField: twoFactor\.codeField/)
assert.match(service, /challenge\.action \|\| V2exNativeAuthService\.TWO_FACTOR_PATH/)
assert.match(service, /requestText\(`\$\{baseUrl\}\$\{V2exNativeAuthService\.SETTINGS_PATH\}`/)
assert.match(service, /private static isSigninResponse/)
assert.match(service, /private static loginInputErrorMessage/)
assert.match(service, /V2exNativeAuthService\.isSigninResponse\(settingsRes\)/)
assert.match(service, /验证码不正确，请重新输入/)
assert.match(service, /用户名或密码不正确，请检查后重试/)
assert.match(service, /用户名、密码或验证码不正确，请检查后重试/)
assert.match(service, /无法确认登录状态，请改用网页登录/)
assert.match(service, /receivedSetCookieLines\.push\(\.\.\.V2exNativeAuthService\.extractSetCookieHeader\(headers\)\)/)
assert.match(service, /uniqueCookieLines\(receivedSetCookieLines\.concat\(finalSetCookie\)\)/)
assert.match(service, /V2exNativeAuthService\.extractSingleHeader\(headers, 'location'\) \|\| receivedLocation/)
assert.doesNotMatch(service, /getTextWithHeaders\('\/settings'/, 'native login must verify private proof through auth request path before saving')
assert.match(service, /path\.indexOf\('\/'\) !== 0/)
assert.doesNotMatch(service, /challenge\.action\s*\|\|\s*['"]\/signin['"]/, '2FA completion must not guess /signin')
assert.doesNotMatch(source, /extractFormAction\(preferred\)\s*\|\|\s*['"]\/signin['"]/, 'parser must not guess /signin for actionless 2FA forms')
const apiService = fs.readFileSync('shared/src/main/ets/network/ApiService.ets', 'utf8')
assert.match(apiService, /export class V2exCookieTwoFactorRequiredError extends Error/)
assert.match(apiService, /getTextResponseWithHeaders\(endpoint, \{ 'Cookie': cookie \}\)/)
assert.match(apiService, /assertNoTwoFactorChallenge\(endpoint, res\.text, res\.location\)/)
assert.match(apiService, /ApiService\.isLocationPath\(location, '\/2fa'\)[\s\S]*V2exSigninParser\.extractTwoFactorForm\(text\)/)
assert.match(apiService, /throw new V2exCookieTwoFactorRequiredError\(path\)/)
assert.ok(isLocationPath('/2fa', '/2fa'), 'relative /2fa redirect must be treated as typed 2FA')
assert.ok(isLocationPath('2fa?once=[REDACTED]', '/2fa'), 'bare relative 2fa redirect must be treated as typed 2FA')
assert.ok(isLocationPath('https://www.v2ex.com/2fa?next=%2Fsettings', '/2fa'), 'absolute /2fa redirect must be treated as typed 2FA')
const requestHtmlStart = apiService.indexOf('private async requestHtmlWithCookieAllowRedirect')
const requestHtmlAssert = apiService.indexOf('this.assertNoTwoFactorChallenge(clean, text, location)', requestHtmlStart)
const requestHtmlHttpThrow = apiService.indexOf('throw new Error(`HTTP ${statusCode}: ${url}`)', requestHtmlStart)
assert.ok(requestHtmlStart >= 0 && requestHtmlAssert >= 0 && requestHtmlHttpThrow >= 0)
assert.ok(
  requestHtmlAssert < requestHtmlHttpThrow,
  'cookie/private HTML helper must detect /2fa before generic HTTP status failure'
)
const httpClient = fs.readFileSync('shared/src/main/ets/network/HttpClient.ets', 'utf8')
assert.match(httpClient, /export interface TextResponseWithHeaders/)
assert.match(httpClient, /getTextResponseWithHeaders/)
assert.match(httpClient, /const location = HttpClient\.extractSingleHeader\(received, 'location'\)/)
assert.match(httpClient, /HttpClient\.extractSingleHeader\(responseHeaders, 'location'\) \|\| receivedLocation/)
assert.match(httpClient, /statusCode >= 300 && statusCode < 400[\s\S]*return \{ statusCode, text: \(response\.result as string\) \|\| '', location \}/)
const sessionParser = fs.readFileSync('shared/src/main/ets/parser/V2exSessionParser.ets', 'utf8')
assert.match(sessionParser, /const links = html\.match\(\/<a\\b\[\^>\]\*>\/gi\) \|\| \[\]/)
assert.match(sessionParser, /hasClass\(className, 'top'\)/)
const webPage = fs.readFileSync('entry/src/main/ets/pages/V2exWebLoginPage.ets', 'utf8')
assert.match(webPage, /private autoSaveTimerId: number = 0/)
assert.match(webPage, /this\.cancelAutoSave\(\)/)
assert.match(webPage, /private isCurrentSaveRequest\(requestId: number\): boolean \{\s*return this\.isPageActive && requestId === this\.saveRequestId\s*\}/s)
const page = fs.readFileSync('entry/src/main/ets/pages/V2exNativeLoginPage.ets', 'utf8')
assert.doesNotMatch(page, /@Prop twoFactorCookie: string = ''/)
assert.doesNotMatch(page, /@State private twoFactorCode: string = ''/)
assert.doesNotMatch(page, /private twoFactorChallenge:/)
assert.doesNotMatch(page, /private completeTwoFactor\(\): void/)
assert.match(page, /aboutToAppear\(\): void \{\s*this\.isPageActive = true\s*this\.clearSecretState\(\)\s*this\.loadChallenge\(\)\s*\}/s)
assert.match(page, /aboutToDisappear\(\): void \{\s*this\.isPageActive = false\s*this\.clearSecretState\(\)\s*\}/s)
assert.match(page, /private clearSecretState\(\): void/)
assert.match(page, /@State private captchaField: string = ''/)
assert.match(page, /private shouldShowCaptchaField\(\): boolean \{\s*return !!this\.captchaField \|\| !!this\.captchaUrl\s*\}/s)
assert.match(page, /this\.captchaField = challenge\.captchaField/)
assert.match(page, /this\.challengeRequestId\+\+/)
assert.match(page, /requestId !== this\.challengeRequestId/)
assert.match(page, /private isCurrentAuthRequest\(requestId: number\): boolean \{\s*return this\.isPageActive && requestId === this\.authRequestId\s*\}/s)
assert.match(page, /const requestId = \+\+this\.authRequestId[\s\S]*this\.auth\.loginWithChallenge\(challenge, cleanUsername, pwd, captchaCode\)[\s\S]*if \(!this\.isCurrentAuthRequest\(requestId\)\)/)
assert.match(page, /error instanceof NativeTwoFactorRequiredError[\s\S]*TwoFactorChallengeService\.request\(error\.challenge\.cookie, 'nativeLogin'\)/)
assert.match(page, /finishLogin\([\s\S]*requestId: number[\s\S]*if \(!this\.isCurrentAuthRequest\(requestId\)\)/)
const prompt = fs.readFileSync('entry/src/main/ets/components/V2exTwoFactorPrompt.ets', 'utf8')
assert.match(prompt, /export struct V2exTwoFactorPrompt/)
assert.match(prompt, /this\.auth\.completeTwoFactorWithCookie\(cleanCookie, cleanCode\)/)
assert.match(prompt, /CookieJarSettings\.saveForBaseUrl\(context, baseUrl, snapshot\.cookie\)/)
assert.match(prompt, /Text\('V2EX 需要完成两步验证后才能继续访问账号内容。'\)/)
assert.doesNotMatch(prompt, /@Prop message:/)
const indexPage = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8')
assert.match(indexPage, /GlobalTwoFactorSheet/)
assert.match(indexPage, /V2exTwoFactorPrompt/)
assert.match(indexPage, /\.bindSheet\(\$\$this\.twoFactorVisible, this\.GlobalTwoFactorSheet\(\)/)
assert.match(indexPage, /TwoFactorChallengeService\.complete\(\)/)
assert.match(indexPage, /source === 'nativeLogin'/)
const accountPage = fs.readFileSync('entry/src/main/ets/pages/AccountPage.ets', 'utf8')
assert.doesNotMatch(accountPage, /V2exTwoFactorPrompt/)
assert.doesNotMatch(accountPage, /\.bindSheet\(\$\$this\.twoFactorVisible, this\.TwoFactorSheet\(\)/)
assert.match(accountPage, /TwoFactorChallengeService\.request\(cookie, 'account'\)/)
assert.doesNotMatch(accountPage, /V2exNativeLoginParams/)
assert.doesNotMatch(accountPage, /pushPathByName\('V2exNativeLogin', params as Object\)/)
const myTopicsPage = fs.readFileSync('entry/src/main/ets/pages/MyTopicsPage.ets', 'utf8')
assert.doesNotMatch(myTopicsPage, /V2exTwoFactorPrompt/)
assert.doesNotMatch(myTopicsPage, /\.bindSheet\(\$\$this\.twoFactorVisible, this\.TwoFactorSheet\(\)/)
assert.match(myTopicsPage, /TwoFactorChallengeService\.request\(cookie, 'myTopics'\)/)
assert.doesNotMatch(myTopicsPage, /V2exNativeLoginParams/)
assert.doesNotMatch(myTopicsPage, /pushPathByName\('V2exNativeLogin', params as Object\)/)
const button = fs.readFileSync('shared/src/main/ets/components/AppActionButton.ets', 'utf8')
assert.ok(!button.includes('.layoutWeight(1)'), 'AppActionButton must not flex-grow by default')

console.log('sanitized signin parser/source assertions passed')
