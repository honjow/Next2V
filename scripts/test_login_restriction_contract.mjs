#!/usr/bin/env node
import fs from 'node:fs'
import path from 'node:path'

const repo = process.cwd()
const read = (rel) => fs.readFileSync(path.join(repo, rel), 'utf8')
const assert = (condition, message) => { if (!condition) throw new Error(message) }

const parser = read('shared/src/main/ets/parser/V2exSigninParser.ets')
assert(parser.includes('V2exLoginRestriction'), 'parser must expose V2exLoginRestriction')
assert(parser.includes('extractLoginRestriction'), 'parser must extract V2EX login restriction pages')
assert(parser.includes('登录受限'), 'parser must detect V2EX 登录受限 text')
assert(parser.includes('受限的 IP 地址'), 'parser must extract restricted IP label')

const apiError = read('shared/src/main/ets/network/ApiError.ets')
assert(apiError.includes("LOGIN_RESTRICTED = 'LOGIN_RESTRICTED'"), 'ApiErrorCode must include LOGIN_RESTRICTED')
assert(apiError.includes('static loginRestricted(ip: string)'), 'ApiErrors must expose loginRestricted(ip)')
// i18n migration: AppStrings.R_API_ERROR_* constants became $r('app.string.*') resources.
// The IP-aware intent survives: loginRestricted(ip) must pick the *_with_ip resource (which
// carries the {0} IP placeholder) when an IP is present, and inject the IP via context['0'].
assert(apiError.includes("$r('app.string.api_error_login_restricted_with_ip')"), 'loginRestricted must use IP-aware resource')
assert(apiError.includes("$r('app.string.api_error_login_restricted')"), 'loginRestricted must have a no-IP fallback resource')
assert(/cleanIp\s*\?\s*\$r\('app\.string\.api_error_login_restricted_with_ip'\)\s*:\s*\$r\('app\.string\.api_error_login_restricted'\)/.test(apiError), 'loginRestricted must select the IP-aware resource only when an IP is known')
assert(/const context: Record<string, string> = \{ '0': cleanIp \}/.test(apiError), 'loginRestricted must inject the IP through context[0] for {0} substitution')

const auth = read('shared/src/main/ets/network/V2exNativeAuthService.ets')
assert(auth.includes("isLocationPath(getRes.location, '/signin/cooldown')"), 'prepareLogin must detect V2EX cooldown redirects')
assert(auth.includes('extractLoginRestriction(getRes.text)'), 'prepareLogin must detect restriction before generic parse failure')
assert(auth.includes('throw ApiErrors.loginRestricted(restriction.restrictedIp)'), 'prepareLogin must throw loginRestricted')
assert(auth.includes('extractLoginRestriction(postRes.text)'), 'login post response must detect restriction')
assert(auth.includes('extractLoginRestriction(settingsRes.text)'), 'settings proof response must detect restriction')

// Strings now live in the resource jsons (the AppStrings.R_* constant layer was retired by
// the ResourceManager migration). Verify both keys exist in every locale and that the
// IP-aware variant keeps its {0} placeholder so context['0'] actually substitutes.
for (const loc of ['base', 'en_US', 'zh_CN', 'zh_HK', 'zh_TW']) {
  const json = JSON.parse(read(`entry/src/main/resources/${loc}/element/string.json`))
  const map = new Map(json.string.map((e) => [e.name, e.value]))
  assert(map.has('api_error_login_restricted'), `${loc} missing api_error_login_restricted`)
  assert(map.has('api_error_login_restricted_with_ip'), `${loc} missing api_error_login_restricted_with_ip`)
  assert(map.get('api_error_login_restricted_with_ip').includes('{0}'), `${loc} api_error_login_restricted_with_ip must keep the {0} IP placeholder`)
}

console.log('login restriction contract PASS')
