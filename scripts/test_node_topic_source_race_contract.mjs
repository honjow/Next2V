#!/usr/bin/env node
import assert from 'node:assert/strict'
import fs from 'node:fs'
import path from 'node:path'

const repo = process.cwd()
const pageSource = fs.readFileSync(path.join(repo, 'feature/node/src/main/ets/pages/NodeTopicPage.ets'), 'utf8')
const vmSource = fs.readFileSync(path.join(repo, 'feature/node/src/main/ets/viewmodel/NodeViewModel.ets'), 'utf8')

function mustContain(source, pattern, message) {
  assert.match(source, pattern, message)
}

mustContain(vmSource, /activeNodeTopicsRequestId/, 'NodeViewModel must keep an active node-topic request id')
mustContain(vmSource, /activeNodeTopicsNodeName/, 'NodeViewModel must bind page-1 ownership to a node name')
mustContain(vmSource, /activeNodeTopicsSource/, 'NodeViewModel must bind page-1 ownership to a source label')
mustContain(vmSource, /nodeTopicsPageOneSettled/, 'NodeViewModel must expose page-1 settled state before loadMore')
mustContain(vmSource, /nodeTopicsPageOnePublished/, 'NodeViewModel must remember whether page-1 already published')

mustContain(vmSource, /shouldPublishNodeTopicsPageOne[\s\S]*stale_request[\s\S]*losing_source[\s\S]*fallback_after_publish/, 'page-1 publishing must reject stale requests, losing sources, and fallback-after-publish')
mustContain(vmSource, /switchNodeTopicsPageOneSource[\s\S]*nodeTopicsPageOnePublished[\s\S]*fallback_after_publish/, 'fallback source switch must not proceed after a page-1 publish')
mustContain(vmSource, /loadNodeTopicsV2\([^)]*options\?: NodeTopicPageOneLoadOptions\)[\s\S]*shouldPublishNodeTopicsPageOne[\s\S]*publishNodeTopicsPageOne/, 'API v2 page-1 topics must publish only through the source/request gate')
mustContain(vmSource, /loadNodeTopics\([^)]*options\?: NodeTopicPageOneLoadOptions\)[\s\S]*shouldPublishNodeTopicsPageOne[\s\S]*publishNodeTopicsPageOne/, 'web page-1 topics must publish only through the source/request gate')
mustContain(vmSource, /loadMoreNodeTopicsV2[\s\S]*this\.isLoading[\s\S]*!this\.nodeTopicsPageOneSettled/, 'API v2 loadMore must wait until initial page-1 load settles')
mustContain(vmSource, /loadMoreNodeTopics[\s\S]*this\.isLoading[\s\S]*!this\.nodeTopicsPageOneSettled/, 'web loadMore must wait until initial page-1 load settles')

mustContain(pageSource, /nodeTopicsRequestId/, 'NodeTopicPage must create a logical request generation id')
mustContain(pageSource, /beginNodeTopicsPageOneLoad\(nodeName, 'api_v2'/, 'token path must start an API-v2-owned page-1 request')
mustContain(pageSource, /loadNodeDetailV2\(nodeName, this\.token\)[\s\S]*loadNodeTopicsV2\(nodeName, this\.token, \{\s*requestId: requestId,\s*source: 'api_v2',?\s*\}\)/, 'API v2 detail and topics calls must be explicit and source-tagged')
mustContain(pageSource, /if \(!topicsLoaded\)[\s\S]*loadNodeTopicsWebFallback/, 'web fallback must be driven by topic-source failure, not by a broad combined try around detail+topics')
mustContain(pageSource, /loadNodeTopicsWebFallback[\s\S]*switchNodeTopicsPageOneSource\(nodeName, 'web', requestId\)[\s\S]*loadNodeTopics\(nodeName, \{ requestId: requestId, source: 'web', fallback: true \}\)/, 'fallback must switch ownership before publishing web page-1')
mustContain(pageSource, /loadMore\(\): void \{[\s\S]*this\.vm\.isLoading[\s\S]*!this\.vm\.hasNodeTopicsPageOneSettled\(\)/, 'NodeTopicPage loadMore must be gated while page-1 is loading/unsettled')

for (const event of [
  'node_topic_page_load_start',
  'node_topic_source_success',
  'node_topic_source_fail',
  'node_topic_fallback',
  'node_topic_publish_ignored'
]) {
  assert.ok(pageSource.includes(event) || vmSource.includes(event), `DiagnosticLogger event missing: ${event}`)
}

console.log('node topic source race contract passed')
