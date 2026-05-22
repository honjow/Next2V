#!/usr/bin/env node
import assert from 'node:assert/strict'
import fs from 'node:fs'
import path from 'node:path'

const repo = process.cwd()
const apiSource = fs.readFileSync(path.join(repo, 'shared/src/main/ets/network/ApiService.ets'), 'utf8')
const pageSource = fs.readFileSync(path.join(repo, 'entry/src/main/ets/pages/AccountBlacklistPage.ets'), 'utf8')

function methodBody(source, name) {
  const start = source.indexOf(name)
  assert.notEqual(start, -1, `${name} must exist`)
  const open = source.indexOf('{', start)
  assert.notEqual(open, -1, `${name} must have a body`)
  let depth = 0
  for (let i = open; i < source.length; i++) {
    const ch = source[i]
    if (ch === '{') depth += 1
    if (ch === '}') depth -= 1
    if (depth === 0) return source.slice(open, i + 1)
  }
  throw new Error(`${name} body not closed`)
}

const getBlocked = methodBody(apiSource, 'getBlockedMembersWithCookie')
const getIgnored = methodBody(apiSource, 'getIgnoredTopicsWithCookie')
const getCookieListHtml = methodBody(apiSource, 'private async getCookieListHtml')
const assertCookieListPage = methodBody(apiSource, 'private assertCookieListPage')
const refresh = methodBody(pageSource, 'private refresh')

assert.match(getBlocked, /getCookieListHtml\('\/d\/blocked',\s*cookie,\s*'blocked'\)/, 'blocked member list must read /d/blocked')
assert.doesNotMatch(getBlocked, /getCookie(?:List)?Html\('\/blocked'/, 'blocked member list must not read legacy /blocked')
assert.match(getIgnored, /getCookieListHtml\('\/d\/ignored',\s*cookie,\s*'ignored'\)/, 'ignored topic list must read /d/ignored')
assert.doesNotMatch(getIgnored, /getCookie(?:List)?Html\('\/ignored'/, 'ignored topic list must not read legacy /ignored')

assert.match(getCookieListHtml, /statusCode\s*>=\s*300[\s\S]*statusCode\s*<\s*400[\s\S]*throw new Error/, 'account list fetch must reject redirects instead of parsing their empty bodies')
assert.match(assertCookieListPage, /\/signin[\s\S]*!V2exSessionParser\.extractUsername/, 'account list fetch must reject login pages')
assert.match(assertCookieListPage, /V2EX › \$\{slug\}/, 'account list fetch must verify the target list page title')
assert.match(assertCookieListPage, /解析列表失败/, 'non-target or parse-failure pages must be surfaced as failures')

assert.match(refresh, /\.then\(\(result\)[\s\S]*BlockedMemberSettings\.saveUsernames/, 'blocked cache may be refreshed after successful list fetch')
const catchStart = refresh.indexOf('.catch(')
assert.notEqual(catchStart, -1, 'refresh must handle fetch failures')
const catchBody = refresh.slice(catchStart)
assert.doesNotMatch(catchBody, /BlockedMemberSettings\.saveUsernames|saveUsernames\([^)]*\[\]/, 'fetch/parse failures must not overwrite blocked cache with an empty list')

console.log('account blacklist endpoint contract checks passed')
