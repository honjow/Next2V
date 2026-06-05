#!/usr/bin/env node
import assert from 'node:assert/strict'
import { existsSync, readFileSync } from 'node:fs'

const read = (path) => readFileSync(path, 'utf8')
const exists = (path) => existsSync(path)

const owner = 'shared/src/main/ets/cache/CacheOwnerResolver.ets'
const overlay = 'shared/src/main/ets/cache/TopicDetailActionOverlaySettings.ets'
const merge = 'shared/src/main/ets/cache/CacheMergeCoordinator.ets'
const localData = read('shared/src/main/ets/storage/LocalDataStore.ets')
const localClear = read('shared/src/main/ets/settings/LocalDataSettings.ets')
const accountStore = read('shared/src/main/ets/settings/AccountStore.ets')
const index = read('shared/src/main/ets/Index.ets')
const feedVm = read('feature/feed/src/main/ets/viewmodel/FeedViewModel.ets')
const home = read('feature/feed/src/main/ets/pages/HomePage.ets')
const detailVm = read('feature/detail/src/main/ets/viewmodel/DetailViewModel.ets')
const detailPage = read('feature/detail/src/main/ets/pages/TopicDetailPage.ets')

assert.ok(exists(owner), 'CacheOwnerResolver must exist as a reusable Phase 1 primitive')
assert.ok(exists(overlay), 'TopicDetailActionOverlaySettings must exist as shared durable overlay storage')
assert.ok(exists(merge), 'CacheMergeCoordinator must exist as pure merge helper')

const ownerText = read(owner)
assert.match(ownerText, /export interface CacheScope/)
assert.match(ownerText, /resolvePublicScope\(/)
assert.match(ownerText, /resolveActivePrivateScope\(/)
assert.match(ownerText, /ownerKey\(/)
assert.match(ownerText, /baseUrl[\s\S]*accountId[\s\S]*loginMode|accountId[\s\S]*baseUrl[\s\S]*loginMode/)
assert.match(ownerText, /cross-account|v2ex\.com\/v2ex\.co|domain/i, 'owner resolver needs why-comment for account/domain scoping')
assert.doesNotMatch(ownerText, /username\s*\+|\+\s*username/, 'private owner keys must not be username-only or username-concatenated')

const overlayText = read(overlay)
assert.match(localData, /LOCAL_DATA_SCHEMA_VERSION:\s*number\s*=\s*7/)
assert.match(localData, /topic_action_overlays/)
assert.match(localData, /PRIMARY KEY\(owner_key, topic_id\)/)
assert.match(localData, /idx_topic_action_overlays_account/)
assert.match(overlayText, /loadTopicOverlay\(/)
assert.match(overlayText, /commitTopicFavorite\(/)
assert.match(overlayText, /commitTopicThank\(/)
assert.match(overlayText, /commitReplyThank\(/)
assert.match(overlayText, /clearByOwner\(/)
assert.match(overlayText, /clearAll\(/)
assert.match(localClear, /TopicDetailActionOverlaySettings\.clearAll\(context\)/, 'LocalDataSettings.clearAll must clear overlays')
assert.match(accountStore, /TopicDetailActionOverlaySettings\.clearByOwner\(context,\s*removed\.baseUrl,\s*removed\.id/, 'account removal must clear exact owner overlay before losing id')

const mergeText = read(merge)
assert.match(mergeText, /mergeTopicListWithReadStates\(/)
assert.match(mergeText, /mergeTopicDetail\(/)
assert.match(mergeText, /public\/API defaults|public defaults|same-owner/i, 'merge precedence why-comment missing')
assert.match(mergeText, /one-way|non-idempotent|thank/i, 'thank sticky why-comment missing')
assert.match(feedVm, /CacheMergeCoordinator\.mergeTopicListWithReadStates/)
assert.match(home, /CollectionSettings\.syncTopicReadStates\(context\)/, 'feed cache loader must hydrate read-state overlay before cached publication')
assert.match(detailVm, /setTopicActionOverlay\(/)
assert.match(detailVm, /CacheMergeCoordinator\.mergeTopicDetail/)
assert.match(detailPage, /CacheOwnerResolver\.resolveActivePrivateScope\(context\)/)
assert.match(detailPage, /TopicDetailActionOverlaySettings\.loadTopicOverlay/)
assert.match(detailPage, /TopicDetailActionOverlaySettings\.commitTopicFavorite/)
assert.match(detailPage, /TopicDetailActionOverlaySettings\.commitTopicThank/)
assert.match(detailPage, /TopicDetailActionOverlaySettings\.commitReplyThank/)
assert.match(detailPage, /rollback[\s\S]*leave durable overlay unchanged|leave durable overlay unchanged[\s\S]*rollback/i, 'failed destructive action rollback why-comment missing')

assert.match(index, /CacheOwnerResolver/)
assert.match(index, /CacheMergeCoordinator/)
assert.match(index, /TopicDetailActionOverlaySettings/)

console.log('PASS app-wide cache phase1 static contract')
