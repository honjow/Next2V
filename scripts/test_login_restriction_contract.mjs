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
assert(apiError.includes('R_API_ERROR_LOGIN_RESTRICTED_WITH_IP'), 'loginRestricted must use IP-aware string')

const auth = read('shared/src/main/ets/network/V2exNativeAuthService.ets')
assert(auth.includes("isLocationPath(getRes.location, '/signin/cooldown')"), 'prepareLogin must detect V2EX cooldown redirects')
assert(auth.includes('extractLoginRestriction(getRes.text)'), 'prepareLogin must detect restriction before generic parse failure')
assert(auth.includes('throw ApiErrors.loginRestricted(restriction.restrictedIp)'), 'prepareLogin must throw loginRestricted')
assert(auth.includes('extractLoginRestriction(postRes.text)'), 'login post response must detect restriction')
assert(auth.includes('extractLoginRestriction(settingsRes.text)'), 'settings proof response must detect restriction')

const appStrings = read('shared/src/main/ets/i18n/AppStrings.ets')
assert(appStrings.includes('R_API_ERROR_LOGIN_RESTRICTED'), 'AppStrings missing login restricted key')
assert(appStrings.includes('R_API_ERROR_LOGIN_RESTRICTED_WITH_IP'), 'AppStrings missing login restricted with IP key')

for (const loc of ['base', 'en_US', 'zh_CN', 'zh_HK', 'zh_TW']) {
  const json = read(`entry/src/main/resources/${loc}/element/string.json`)
  assert(json.includes('api_error_login_restricted'), `${loc} missing api_error_login_restricted`)
  assert(json.includes('api_error_login_restricted_with_ip'), `${loc} missing api_error_login_restricted_with_ip`)
}

console.log('login restriction contract PASS')
