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

function extractFormAction(formHtml) {
  const formTag = formHtml.match(/<form\b[^>]*>/i)
  return formTag ? extractAttr(formTag[0], 'action') : ''
}

function findTwoFactorCodeField(inputs) {
  const candidates = inputs.filter(input => {
    const type = input.type.toLowerCase()
    return input.name && (type === 'text' || type === 'tel' || type === 'number' || type === '')
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
  const preferred = forms.find(form => looksLikeTwoFactorForm(form)) || (looksLikeTwoFactorForm(html) ? html : '')
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

const source = fs.readFileSync('shared/src/main/ets/parser/V2exSigninParser.ets', 'utf8')
assert.match(source, /context\.indexOf\('验证码'\)/)
assert.match(source, /placeholder\.indexOf\('验证码'\)/)
assert.match(source, /placeholder\.indexOf\('code'\)/)
assert.match(source, /src\.indexOf\('captcha'\)/)
assert.match(source, /private static inputContext/)
const service = fs.readFileSync('shared/src/main/ets/network/V2exNativeAuthService.ets', 'utf8')
assert.match(service, /twoFactorChallengeFromHtml/)
assert.match(service, /path\.indexOf\('\/'\) !== 0/)
assert.doesNotMatch(service, /challenge\.action\s*\|\|\s*['"]\/signin['"]/, '2FA completion must not guess /signin')
assert.doesNotMatch(source, /extractFormAction\(preferred\)\s*\|\|\s*['"]\/signin['"]/, 'parser must not guess /signin for actionless 2FA forms')
const page = fs.readFileSync('entry/src/main/ets/pages/V2exNativeLoginPage.ets', 'utf8')
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
assert.match(page, /const requestId = \+\+this\.authRequestId[\s\S]*this\.auth\.completeTwoFactor\(twoFactorChallenge, twoFactorCode\)[\s\S]*if \(!this\.isCurrentAuthRequest\(requestId\)\)/)
assert.match(page, /finishLogin\([\s\S]*requestId: number[\s\S]*if \(!this\.isCurrentAuthRequest\(requestId\)\)/)
const button = fs.readFileSync('shared/src/main/ets/components/AppActionButton.ets', 'utf8')
assert.ok(!button.includes('.layoutWeight(1)'), 'AppActionButton must not flex-grow by default')

console.log('sanitized signin parser/source assertions passed')
