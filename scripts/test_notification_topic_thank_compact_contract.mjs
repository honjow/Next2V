#!/usr/bin/env node
import fs from 'node:fs'
import path from 'node:path'

const repo = process.cwd()
const read = (rel) => fs.readFileSync(path.join(repo, rel), 'utf8')
const assert = (condition, message) => {
  if (!condition) {
    throw new Error(message)
  }
}

const vm = read('entry/src/main/ets/viewmodel/NotificationCenterViewModel.ets')

for (const token of [
  'private shouldCompactTopicThanks(kindTag: string, item: V2exNotification, body: string): boolean',
  'if (kindTag !== KIND_THANKS)',
  'return !this.hasReplyThankContext(item, body)',
  'private hasReplyThankContext(item: V2exNotification, body: string): boolean',
  'this.targetFloor(item) > 0',
  'this.replyContent(item)',
  'this.replyRenderedContent(item)',
  'body.indexOf(\'回复\') >= 0',
  "body.toLowerCase().indexOf('reply') >= 0",
  'body: this.displayBody(kindTag, body, compactTopicThanks)',
  'replyContent: this.displayReplyContent(kindTag, item, compactTopicThanks)',
  'replyRenderedContent: this.displayReplyRenderedContent(kindTag, item, compactTopicThanks)',
  'if (kindTag === KIND_FAVORITE || compactTopicThanks)',
]) {
  assert(vm.includes(token), `NotificationCenterViewModel topic-thank compact contract missing ${token}`)
}

const compactDecision = (item) => {
  const body = item.text || item.content || item.content_rendered || ''
  const text = `${item.title || ''} ${body} ${item.reply_content || item.payload || item.content || item.reply_content_rendered || item.payload_rendered || item.content_rendered || ''} ${item.payload || ''} ${item.payload_rendered || ''}`.toLowerCase()
  let kindTag = 'notification'
  if (text.includes('感谢了你') || text.includes('thanks') || text.includes('thanked')) {
    kindTag = 'thanks'
  } else if (text.includes('收藏了你') || text.includes('favorite') || text.includes('favorited') || text.includes('收藏')) {
    kindTag = 'favorite'
  }
  const replyContext =
    (item.target_floor || 0) > 0 ||
    !!(item.reply_content || item.payload || item.reply_content_rendered || item.payload_rendered) ||
    body.indexOf('回复') >= 0 ||
    body.toLowerCase().indexOf('reply') >= 0
  const compactTopicThanks = kindTag === 'thanks' && !replyContext
  const compactFavorite = kindTag === 'favorite'
  return {
    kindTag,
    body: compactTopicThanks || compactFavorite ? '' : body,
    replyContent: compactTopicThanks || compactFavorite ? '' : (item.reply_content || item.payload || ''),
    replyRenderedContent: compactTopicThanks || compactFavorite ? '' : (item.reply_content_rendered || item.payload_rendered || ''),
  }
}

const topicThank = compactDecision({
  id: 101,
  title: 'Some topic title',
  text: '图片 evanxu07 感谢了你发布的主题 › Some topic title 删除',
  topic_id: 121,
  topic_title: 'Some topic title',
  member: { username: 'evanxu07' },
})
assert(topicThank.kindTag === 'thanks', 'topic thank sample must classify as thanks')
assert(topicThank.body === '', 'topic thank sample must render compact with no redundant body')
assert(topicThank.replyContent === '', 'topic thank sample must not synthesize a reply preview')
assert(topicThank.replyRenderedContent === '', 'topic thank sample must not render a reply preview')

const replyThankWithPayload = compactDecision({
  id: 102,
  title: 'Some topic title',
  text: 'evanxu07 感谢了你在主题中的回复 › Some topic title 删除',
  reply_content: '真实回复上下文',
  reply_content_rendered: '<p>真实回复上下文</p>',
  target_floor: 8,
})
assert(replyThankWithPayload.kindTag === 'thanks', 'reply thank payload sample must classify as thanks')
assert(replyThankWithPayload.body.includes('回复'), 'reply thank body context must be preserved')
assert(replyThankWithPayload.replyContent === '真实回复上下文', 'reply thank payload content must be preserved')
assert(replyThankWithPayload.replyRenderedContent.includes('真实回复上下文'), 'reply thank rendered content must be preserved')

const replyThankWithFloorOnly = compactDecision({
  id: 103,
  title: 'Some topic title',
  text: 'evanxu07 感谢了你在主题中的回复 › Some topic title 删除',
  target_floor: 9,
})
assert(replyThankWithFloorOnly.body.includes('回复'), 'reply thank target-floor-only body must be preserved')

const favorite = compactDecision({
  id: 104,
  title: 'Favorite topic',
  text: 'evanxu07 收藏了你的主题 › Favorite topic 删除',
})
assert(favorite.kindTag === 'favorite', 'favorite fixture must still classify as favorite')
assert(favorite.body === '', 'favorite fixture must remain compact with no body')

console.log('notification topic-thank compact contract ok')
