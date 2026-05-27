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
  'this.explicitReplyThankContext(item)',
  'private explicitReplyThankContext(item: V2exNotification): boolean',
  'item.reply_content || item.reply_content_rendered',
  'body.indexOf(\'回复\') >= 0',
  "body.toLowerCase().indexOf('reply') >= 0",
  'private isTopicThankDescription(value: string): boolean',
  '感谢了你发布的主题',
  'thanked your topic',
  'body: this.displayBody(kindTag, body, compactTopicThanks)',
  'replyContent: this.displayReplyContent(kindTag, item, compactTopicThanks)',
  'replyRenderedContent: this.displayReplyRenderedContent(kindTag, item, compactTopicThanks)',
  'if (kindTag === KIND_FAVORITE || compactTopicThanks)',
]) {
  assert(vm.includes(token), `NotificationCenterViewModel topic-thank compact contract missing ${token}`)
}

const isTopicThankDescription = (value) => {
  const text = String(value || '')
    .replace(/<script[\s\S]*?<\/script>/gi, ' ')
    .replace(/<style[\s\S]*?<\/style>/gi, ' ')
    .replace(/<img\b[^>]*>/gi, ' [IMG] ')
    .replace(/<br\s*\/?>/gi, ' ')
    .replace(/<\/p>/gi, ' ')
    .replace(/<[^>]+>/g, ' ')
    .replace(/&amp;/g, '&')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&nbsp;/g, ' ')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/\s+/g, ' ')
    .trim()
    .toLowerCase()
  return text.includes('感谢了你发布的主题') ||
    text.includes('感谢了你的主题') ||
    text.includes('thanked your topic') ||
    text.includes('thanked the topic you created')
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
    (!isTopicThankDescription(body) &&
      !isTopicThankDescription(item.reply_content || '') &&
      !isTopicThankDescription(item.reply_content_rendered || '') &&
      !isTopicThankDescription(item.payload || '') &&
      !isTopicThankDescription(item.payload_rendered || '') &&
      ((item.target_floor || 0) > 0 || !!(item.reply_content || item.reply_content_rendered))) ||
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

const topicThankViaContent = compactDecision({
  id: 105,
  title: 'Next2V：原生鸿蒙的 V2EX 客户端开启邀请测试',
  content: '图片 evanxu07 感谢了你发布的主题 › Next2V：原生鸿蒙的 V2EX 客户端开启邀请测试 7 天前 删除',
  topic_id: 122,
  topic_title: 'Next2V：原生鸿蒙的 V2EX 客户端开启邀请测试',
  member: { username: 'evanxu07' },
})
assert(topicThankViaContent.kindTag === 'thanks', 'topic thank content sample must classify as thanks')
assert(topicThankViaContent.body === '', 'topic thank content sample must hide raw web description body')
assert(topicThankViaContent.replyContent === '', 'topic thank content sample must not promote content into reply preview')

const topicThankViaRenderedContent = compactDecision({
  id: 106,
  title: 'Next2V：原生鸿蒙的 V2EX 客户端开启邀请测试',
  content_rendered: '<img src="avatar.png"> evanxu07 感谢了你发布的主题 › Next2V：原生鸿蒙的 V2EX 客户端开启邀请测试 7 天前 删除',
  topic_id: 123,
  topic_title: 'Next2V：原生鸿蒙的 V2EX 客户端开启邀请测试',
  member: { username: 'evanxu07' },
})
assert(topicThankViaRenderedContent.kindTag === 'thanks', 'topic thank rendered-content sample must classify as thanks')
assert(topicThankViaRenderedContent.body === '', 'topic thank rendered-content sample must hide raw web description body')
assert(topicThankViaRenderedContent.replyRenderedContent === '', 'topic thank rendered-content sample must not promote rendered content into reply preview')

const topicThankViaPayload = compactDecision({
  id: 107,
  title: 'Next2V：原生鸿蒙的 V2EX 客户端开启邀请测试',
  text: '图片 evanxu07 感谢了你发布的主题 › Next2V：原生鸿蒙的 V2EX 客户端开启邀请测试 删除',
  reply_content: '图片 evanxu07 感谢了你发布的主题 › Next2V：原生鸿蒙的 V2EX 客户端开启邀请测试 7 天前 删除',
  reply_content_rendered: '<img src="avatar.png"> evanxu07 感谢了你发布的主题 › Next2V：原生鸿蒙的 V2EX 客户端开启邀请测试 7 天前 删除',
  payload: '图片 evanxu07 感谢了你发布的主题 › Next2V：原生鸿蒙的 V2EX 客户端开启邀请测试 7 天前 删除',
  payload_rendered: '<img src="avatar.png"> evanxu07 感谢了你发布的主题 › Next2V：原生鸿蒙的 V2EX 客户端开启邀请测试 7 天前 删除',
  target_floor: 17,
  topic_id: 124,
  topic_title: 'Next2V：原生鸿蒙的 V2EX 客户端开启邀请测试',
  member: { username: 'evanxu07' },
})
assert(topicThankViaPayload.kindTag === 'thanks', 'topic thank payload sample must classify as thanks')
assert(topicThankViaPayload.body === '', 'topic thank payload sample must hide raw web description body')
assert(topicThankViaPayload.replyContent === '', 'topic thank payload sample must not preserve raw web payload as reply preview')
assert(topicThankViaPayload.replyRenderedContent === '', 'topic thank payload sample must not preserve raw rendered payload as reply preview')

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
