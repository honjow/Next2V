#!/usr/bin/env node
// Static contract for the unignore-topic / unblock-member network methods.
//
// V2EX web bug: the topic page no longer renders the "unignore" link for an already-ignored
// topic, and the member page can mis-report block state. So these methods do NOT scrape the
// reverse link directly — they derive the /unignore/ (resp. /unblock/) path from the still-
// rendered /ignore/ (resp. /block/) link, which carries the same per-session once-token.
//
// Run: node scripts/test_unignore_unblock_network_contract.mjs

import { readFileSync } from 'node:fs'

function source(path) {
  return readFileSync(new URL(`../${path}`, import.meta.url), 'utf8')
}
function fail(message) {
  console.error(`FAIL: ${message}`)
  process.exit(1)
}
function assertIncludes(file, text, needle) {
  if (!text.includes(needle)) {
    fail(`missing in ${file}: ${needle}`)
  }
}

const apiPath = 'shared/src/main/ets/network/ApiService.ets'
const api = source(apiPath)

// Topic unignore: two-stage (load action, then execute) so it slots into the existing
// prepareTopicModeration framework; the unignore path is derived from the ignore path.
assertIncludes(apiPath, api, 'async getTopicUnignoreActionWithCookie(')
assertIncludes(apiPath, api, 'async executeTopicUnignoreWithCookie(')
// Multi-strategy once derivation: an already-ignored topic drops its /ignore/ link, so the
// unignore token must be resolved defensively — explicit unignore link, else ignore-link replace,
// else any once token on the page (favorite/thank/reply all carry the same session once).
assertIncludes(apiPath, api, "extractCookieActionPath(html, 'unignore', 'topic'")
assertIncludes(apiPath, api, "ignorePath.replace('/ignore/', '/unignore/')")
assertIncludes(apiPath, api, 'ApiService.extractOnceToken(html)')

// Member unblock: single-shot. Prefers the rendered unblock link, falls back to deriving
// /unblock/ from the /block/ once-token (and the follow link's once as a last resort).
assertIncludes(apiPath, api, 'async unblockMemberWithCookie(')
assertIncludes(apiPath, api, 'private static resolveUnblockPath(')
assertIncludes(apiPath, api, "blockPath.indexOf('/unblock/')")
assertIncludes(apiPath, api, "blockPath.replace('/block/', '/unblock/')")

// Both execute via the shared cookie-action helper with their own failure prefixes.
assertIncludes(apiPath, api, "'Unignore failed'")
assertIncludes(apiPath, api, "'Unblock failed'")

console.log('PASS: unignore/unblock network contract')
