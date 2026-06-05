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

const networkTypes = read('shared/src/main/ets/network/NetworkTypes.ets')
const userName = read('shared/src/main/ets/components/UserName.ets')
const topicCard = read('shared/src/main/ets/components/TopicCard.ets')
const replyHeader = read('shared/src/main/ets/components/reply/ReplyCardHeader.ets')
const topicDetail = read('feature/detail/src/main/ets/components/TopicDetailComponents.ets')
const tabParser = read('shared/src/main/ets/parser/V2exTabParser.ets')
const apiService = read('shared/src/main/ets/network/ApiService.ets')
const repliesParser = read('shared/src/main/ets/parser/V2exTopicRepliesParser.ets')

function hasMemberRoleLikeProduction(html, username, role) {
  const cleanUsername = String(username || '').trim()
  const cleanRole = String(role || '').trim()
  if (!cleanUsername || !cleanRole) {
    return false
  }
  const escapedUsername = cleanUsername.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
  const memberLink = new RegExp(`<a\\b[^>]*href=["'][^"']*\\/member\\/${escapedUsername}(?:[?#][^"']*)?["'][^>]*>[\\s\\S]*?<\\/a>`, 'gi')
  const escapedRole = cleanRole.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
  const rolePattern = new RegExp(`(?:^|\\s)${escapedRole}(?:\\s|$)`, 'i')
  const roleClassPattern = new RegExp(`class=["'][^"']*(?:\\bbadge\\b[^"']*\\b${escapedRole}\\b|\\b${escapedRole}\\b[^"']*\\bbadge\\b)[^"']*["']`, 'i')
  let match = memberLink.exec(html || '')
  while (match !== null) {
    const linkHtml = match[0] || ''
    if (!/<img\b/i.test(linkHtml)) {
      const start = match.index + linkHtml.length
      const nearby = String(html || '').slice(start, Math.min(String(html || '').length, start + 220))
      const text = nearby.replace(/<[^>]+>/g, ' ').replace(/&nbsp;/g, ' ').replace(/\s+/g, ' ')
      if (roleClassPattern.test(nearby) || rolePattern.test(text)) {
        return true
      }
    }
    match = memberLink.exec(html || '')
  }
  return false
}

assert(networkTypes.includes('mod?: number'), 'V2exMember must carry MOD state')
assert(userName.includes('@Param isMod: boolean = false'), 'UserName must accept isMod')
assert(userName.includes("Text('MOD')"), 'UserName must render MOD badge')
assert(topicCard.includes('isMod: this.isMemberMod()'), 'TopicCard must pass MOD state')
assert(replyHeader.includes('isMod: (this.reply.member.mod || 0) > 0'), 'ReplyCardHeader must pass MOD state')
assert(topicDetail.includes('isMod: (this.topic.member.mod || 0) > 0'), 'TopicDetailHeader must pass MOD state')

for (const source of [tabParser, apiService, repliesParser]) {
  assert(source.includes("hasMemberRole"), 'HTML parser must extract member roles near the member link')
  assert(source.includes("'PRO'") && source.includes("'MOD'"), 'HTML parser must extract PRO and MOD')
  assert(source.includes("while (match !== null)"), 'member role extraction must scan past avatar links')
  assert(source.includes("!/<img\\b/i.test(linkHtml)"), 'member role extraction must ignore avatar-only member links')
  assert(source.includes('replace(/<[^>]+>/g, '), 'member role extraction must separate HTML tags before text matching')
}

const liveLikeProTopic = `
<div class="cell item">
  <a href="/member/Livid"><img class="avatar" alt="Livid" /></a>
  <span class="item_title"><a href="/t/1218270" class="topic-link" id="topic-link-1218270">winget install Microsoft.Coreutils</a></span>
  <span class="topic_info"><a class="node" href="/go/windows">Windows</a> &nbsp;•&nbsp; <strong><a href="/member/Livid">Livid</a></strong> &nbsp;<div class="badges"><div class="badge pro">PRO</div></div> &nbsp;•&nbsp; <span>10 mins ago</span></span>
</div>`
assert(hasMemberRoleLikeProduction(liveLikeProTopic, 'Livid', 'PRO'), 'topic-list PRO badge after author link must be detected')

const liveLikeTitleOnlyProTopic = `
<div class="cell item">
  <a href="/member/miusmile"><img class="avatar" alt="miusmile" /></a>
  <span class="item_title"><a href="/t/1218226" class="topic-link" id="topic-link-1218226">Claude 尼日利亚地区，想开 Max 了，一直使用的 Pro</a></span>
  <span class="topic_info"><a class="node" href="/go/claudecode">Claude Code</a> &nbsp;•&nbsp; <strong><a href="/member/miusmile">miusmile</a></strong> &nbsp;•&nbsp; <span>20 mins ago</span></span>
</div>`
assert(!hasMemberRoleLikeProduction(liveLikeTitleOnlyProTopic, 'miusmile', 'PRO'), 'topic title text must not be mistaken for a member PRO badge')

const liveLikeModReply = `
<div id="r_1" class="cell">
  <a href="/member/Livid"><img class="avatar" alt="Livid" /></a>
  <strong><a href="/member/Livid">Livid</a></strong> <div class="badges"><div class="badge mod">MOD</div><div class="badge op">OP</div><div class="badge pro">PRO</div></div>
</div>`
assert(hasMemberRoleLikeProduction(liveLikeModReply, 'Livid', 'MOD'), 'reply MOD badge after author link must be detected')

console.log('user identity badges contract OK')
