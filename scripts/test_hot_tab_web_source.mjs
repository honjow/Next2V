#!/usr/bin/env node
import assert from 'node:assert/strict'
import fs from 'node:fs'
import path from 'node:path'

const repo = process.cwd()
const apiSource = fs.readFileSync(path.join(repo, 'shared/src/main/ets/network/ApiService.ets'), 'utf8')
const constantsSource = fs.readFileSync(path.join(repo, 'shared/src/main/ets/constants/ApiConstants.ets'), 'utf8')
const parserSource = fs.readFileSync(path.join(repo, 'shared/src/main/ets/parser/V2exTabParser.ets'), 'utf8')
const fixtureHtml = fs.readFileSync(path.join(repo, 'scripts/fixtures/hot_tab_main_list_sample.html'), 'utf8')

assert.match(apiSource, /async\s+getHotTopics\(\):\s+Promise<V2exTopic\[\]>\s*{[\s\S]*ApiConstants\.API_HOT[\s\S]*?}/, 'legacy getHotTopics() API method must remain available')
assert.match(apiSource, /async\s+getHotTabTopics\(\):\s+Promise<V2exTopic\[\]>\s*{[\s\S]*getText\('\/\?tab=hot'\)[\s\S]*V2exTabParser\.extractTopicIds[\s\S]*getBatchTopics\(ids\)[\s\S]*?}/, 'getHotTabTopics() must fetch and parse /?tab=hot HTML')
assert.match(constantsSource, /'hot':\s*'\/\?tab=hot'/, 'TAB_URLS.hot must continue to point at /?tab=hot')

const getTabStart = apiSource.indexOf('async getTabTopics(tab: string)')
assert.notEqual(getTabStart, -1, 'getTabTopics() must exist')
const getTopicsByIdsStart = apiSource.indexOf('async getTopicsByIds', getTabStart)
assert.notEqual(getTopicsByIdsStart, -1, 'getTabTopics() boundary must be discoverable')
const getTabBody = apiSource.slice(getTabStart, getTopicsByIdsStart)
const hotBranch = getTabBody.match(/else\s+if\s*\(tab\s*===\s*'hot'\)\s*{([\s\S]*?)}/)
assert.ok(hotBranch, 'getTabTopics() must have an explicit hot branch')
assert.match(hotBranch[1], /this\.getHotTabTopics\(\)/, 'getTabTopics("hot") must route through getHotTabTopics()')
assert.doesNotMatch(hotBranch[1], /this\.getHotTopics\(\)/, 'getTabTopics("hot") must not route through legacy getHotTopics()')
assert.doesNotMatch(getTabBody, /latest\/hot\s+直接走\s+JSON\s+API/, 'misleading latest/hot JSON API comment must not return')

assert.match(parserSource, /topicLinkRegex\s*=\s*\/id=\["'\]topic-link-\(\\d\+\)\["'\]\/g/, 'V2exTabParser must prioritize topic-link ids')
assert.match(parserSource, /if\s*\(ids\.size\s*>\s*0\)\s*{[\s\S]*return\s+Array\.from\(ids\)/, 'V2exTabParser must return topic-link ids before fallback /t/ links')

function extractTopicIdsLikeV2exTabParser(html) {
  const ids = new Set()
  const topicLinkRegex = /id=["']topic-link-(\d+)["']/g
  let match
  while ((match = topicLinkRegex.exec(html)) !== null) {
    ids.add(Number.parseInt(match[1], 10))
  }
  if (ids.size > 0) {
    return Array.from(ids)
  }

  const regex = /\/t\/(\d+)/g
  while ((match = regex.exec(html)) !== null) {
    ids.add(Number.parseInt(match[1], 10))
  }
  return Array.from(ids)
}

const ids = extractTopicIdsLikeV2exTabParser(fixtureHtml)
assert.ok(ids.length > 10, `fixture should extract more than 10 main-list topic ids, got ${ids.length}`)
assert.deepEqual(ids.slice(0, 3), [1001, 1002, 1003])
assert.ok(!ids.includes(9001) && !ids.includes(9002), 'sidebar /t/ links must not pollute topic-link main-list extraction')

console.log('hot tab source checks passed')
