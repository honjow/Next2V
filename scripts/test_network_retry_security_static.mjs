#!/usr/bin/env node

import { readFileSync } from 'node:fs'

function source(path) {
  return readFileSync(new URL(`../${path}`, import.meta.url), 'utf8')
}

function assertIncludes(file, text, needle) {
  if (!text.includes(needle)) {
    console.error(`FAIL: missing static contract in ${file}: ${needle}`)
    process.exit(1)
  }
}

const retryPath = 'shared/src/main/ets/network/HttpRetryPolicy.ets'
const httpPath = 'shared/src/main/ets/network/HttpClient.ets'
const apiV2Path = 'shared/src/main/ets/network/ApiV2Service.ets'
const apiPath = 'shared/src/main/ets/network/ApiService.ets'
const cookiePath = 'shared/src/main/ets/settings/CookieJarSettings.ets'
const accountPath = 'entry/src/main/ets/pages/AccountPage.ets'
const notificationPath = 'entry/src/main/ets/pages/NotificationPage.ets'

const retry = source(retryPath)
const http = source(httpPath)
const apiV2 = source(apiV2Path)
const api = source(apiPath)
const cookie = source(cookiePath)
const account = source(accountPath)
const notification = source(notificationPath)

assertIncludes(retryPath, retry, 'export class HttpStatusError extends Error')
assertIncludes(retryPath, retry, 'export class HttpJsonParseError extends Error')
assertIncludes(retryPath, retry, 'if (method !== http.RequestMethod.GET)')
assertIncludes(retryPath, retry, 'statusCode === 408 || (statusCode >= 500 && statusCode < 600)')

assertIncludes(httpPath, http, 'HttpRetryPolicy.shouldRetry(reqMethod, e)')
assertIncludes(httpPath, http, 'throw new HttpJsonParseError')
assertIncludes(apiV2Path, apiV2, 'HttpRetryPolicy.shouldRetry(method, e)')
assertIncludes(apiV2Path, apiV2, 'throw new HttpStatusError(statusCode, url')

assertIncludes(apiPath, api, 'resolveCookieRequestUrls')
assertIncludes(apiPath, api, 'resolveSameOriginUrl')
assertIncludes(apiPath, api, 'targetOrigin !== baseOrigin')
assertIncludes(apiPath, api, 'ApiErrors.fieldExternalLinkForbidden(label)')
assertIncludes(apiPath, api, 'private static queryParam(name: string, value: string): string')
assertIncludes(apiPath, api, "ApiService.queryParam('username', clean)")
assertIncludes(apiPath, api, "ApiService.queryParam('name', name)")

assertIncludes(cookiePath, cookie, 'static async clearForBaseUrl')
assertIncludes(cookiePath, cookie, 'expireWebCookiesForBaseUrl')
assertIncludes(cookiePath, cookie, 'Expires=Thu, 01 Jan 1970 00:00:00 GMT')
assertIncludes(accountPath, account, 'CookieJarSettings.clearForBaseUrl(context, HttpClient.getInstance().getBaseUrl())')
assertIncludes(notificationPath, notification, 'CookieJarSettings.clearForBaseUrl(context, HttpClient.getInstance().getBaseUrl())')

const forbiddenRawQueryParams = [
  '?username=${username}',
  '?node_name=${nodeName}',
  '?name=${name}',
]
for (const needle of forbiddenRawQueryParams) {
  if (api.includes(needle)) {
    console.error(`FAIL: raw query parameter interpolation remains in ${apiPath}: ${needle}`)
    process.exit(1)
  }
}

console.log('PASS: network retry and cookie security static contracts')
