#!/usr/bin/env node
import assert from 'node:assert/strict'
import fs from 'node:fs'
import path from 'node:path'

const repo = process.cwd()
const filterSource = fs.readFileSync(path.join(repo, 'shared/src/main/ets/utils/BlockedTopicFilter.ets'), 'utf8')
const apiSource = fs.readFileSync(path.join(repo, 'shared/src/main/ets/network/ApiService.ets'), 'utf8')
const homeSource = fs.readFileSync(path.join(repo, 'feature/feed/src/main/ets/pages/HomePage.ets'), 'utf8')
const userSource = fs.readFileSync(path.join(repo, 'feature/user/src/main/ets/pages/UserProfilePage.ets'), 'utf8')

assert.match(filterSource, /topic\.member\?\.username|topic\.member\.username/, 'filter must key off the topic author')
assert.doesNotMatch(filterSource, /last_reply_by/, 'filter must not key off the last replier')
assert.match(apiSource, /filterBlockedTopicAuthors\(topics\)/, 'home tab network topics must pass through blocked-author filtering')
assert.match(apiSource, /BlockedMemberSettings\.getCachedUsernames\(\)/, 'network refresh must use only the local blocked-member cache')
assert.doesNotMatch(apiSource, /getBlockedMembersWithCookie|getIgnoredTopicsWithCookie/, 'phantom blocklist read APIs must not exist')
assert.doesNotMatch(apiSource, /getCookieHtml\('\/' \+ 'blocked|getCookieHtml\('\/' \+ 'ignored|getCookieHtml\('\/(blocked|ignored)'\)/, 'phantom blocklist endpoint reads must not exist')
assert.match(homeSource, /CacheSettings\.loadTopicList[\s\S]*BlockedTopicFilter\.filterTopicsByBlockedAuthors/, 'cached home topics must be filtered before display')
assert.match(userSource, /BlockedMemberSettings\.setBlocked/, 'member block action must update the shared blocked-member snapshot')

function normalizeUsername(username) {
  return (username || '').trim().toLowerCase()
}

function filterTopicsByBlockedAuthors(topics, blockedUsernames) {
  const blocked = new Set(blockedUsernames.map(normalizeUsername).filter(Boolean))
  return topics.filter((topic) => {
    const author = normalizeUsername(topic.member?.username || '')
    return !author || !blocked.has(author)
  })
}

const topics = [
  { id: 1, title: 'remove blocked author', member: { username: 'BlockedUser' }, last_reply_by: 'alice' },
  { id: 2, title: 'keep topic where blocked user only replied last', member: { username: 'alice' }, last_reply_by: 'BlockedUser' },
  { id: 3, title: 'keep unrelated topic', member: { username: 'bob' }, last_reply_by: 'carol' }
]

const filtered = filterTopicsByBlockedAuthors(topics, [' blockeduser '])
assert.deepEqual(filtered.map((topic) => topic.id), [2, 3])

function localBlockedUsernames(localUsernames) {
  return Array.from(new Set(localUsernames.map(normalizeUsername).filter(Boolean))).sort()
}

assert.deepEqual(localBlockedUsernames([' llej ']), ['llej'])
assert.deepEqual(localBlockedUsernames(['llej', 'LLEJ']), ['llej'])

console.log('blocked topic filter checks passed')
