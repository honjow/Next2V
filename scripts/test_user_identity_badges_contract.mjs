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

assert(networkTypes.includes('mod?: number'), 'V2exMember must carry MOD state')
assert(userName.includes('@Param isMod: boolean = false'), 'UserName must accept isMod')
assert(userName.includes("Text('MOD')"), 'UserName must render MOD badge')
assert(topicCard.includes('isMod: this.isMemberMod()'), 'TopicCard must pass MOD state')
assert(replyHeader.includes('isMod: (this.reply.member.mod || 0) > 0'), 'ReplyCardHeader must pass MOD state')
assert(topicDetail.includes('isMod: (this.topic.member.mod || 0) > 0'), 'TopicDetailHeader must pass MOD state')

for (const source of [tabParser, apiService, repliesParser]) {
  assert(source.includes("hasMemberRole"), 'HTML parser must extract member roles near the member link')
  assert(source.includes("'PRO'") && source.includes("'MOD'"), 'HTML parser must extract PRO and MOD')
  assert(source.includes('replace(/<[^>]+>/g, '), 'member role extraction must separate HTML tags before text matching')
}

console.log('user identity badges contract OK')
