#!/usr/bin/env node
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

const read = (path) => readFileSync(path, 'utf8')

const profilePage = read('feature/user/src/main/ets/pages/UserProfilePage.ets')
const repliesPage = read('feature/user/src/main/ets/pages/UserRepliesPage.ets')
const routeCoordinator = read('entry/src/main/ets/model/IndexRouteCoordinator.ets')
const detailPage = read('feature/detail/src/main/ets/pages/TopicDetailPage.ets')
const memberParser = read('shared/src/main/ets/parser/V2exMemberPageParser.ets')
const replyCard = read('shared/src/main/ets/components/ReplyCard.ets')

const userReplyRoutePattern =
  /private openReplyTopic\(reply: V2exUserReply\): void[\s\S]*const verifyReplyText = \(reply\.content_rendered \|\| reply\.content \|\| ''\)\.trim\(\)[\s\S]*targetFloor: reply\.target_floor, verifyReplyText: verifyReplyText[\s\S]*\{ topicId: reply\.topic_id, verifyReplyText: verifyReplyText \}/

assert.match(
  profilePage,
  userReplyRoutePattern,
  'profile recent replies must carry reply text so TopicDetail can locate the clicked reply floor',
)
assert.match(
  repliesPage,
  userReplyRoutePattern,
  'all-replies page must carry reply text so TopicDetail can locate the clicked reply floor',
)
assert.match(
  routeCoordinator,
  /const verifyReplyText = IndexRouteCoordinator\.stringParam\(param, 'verifyReplyText'\)[\s\S]*if \(verifyReplyText\.trim\(\)\.length > 0\) \{\s*return \{ topicId, verifyReplyText \}\s*\}/,
  'route descriptor rebuild must preserve text-only reply targets',
)
assert.match(
  detailPage,
  /private restoreInitialPosition\(\): void[\s\S]*this\.jumpToTargetFloor\(target\)[\s\S]*this\.jumpToTargetReplyText\(\)[\s\S]*this\.restoreReadPosition\(\)/,
  'TopicDetail must prefer explicit user-reply target text over saved reading-position restore',
)
assert.match(
  detailPage,
  /private jumpToTargetReplyText\(\): void[\s\S]*this\.v\.loadUntilReplyContent\(verify\)[\s\S]*TopicDetailScrollCoordinator\.verifiedFloor\(\s*0,\s*verify,[\s\S]*this\.jumpToLoadedReplyFloor\(resolved,\s*true\)/,
  'TopicDetail must load by reply text and jump to the resolved floor when no targetFloor is available',
)
assert.match(
  detailPage,
  /this\.jumpToLoadedReplyFloor\(resolved,\s*\(this\.verifyReplyText \|\| ''\)\.trim\(\)\.length > 0\)/,
  'targetFloor plus verifyReplyText must request target-card refinement after content repair',
)
assert.match(
  detailPage,
  /@Local private scrollTargetReplyFloor: number = 0/,
  'TopicDetail must keep the target floor reactive so ReplyCard can report its area',
)
assert.match(
  detailPage,
  /scrollTargetFloor: this\.scrollTargetReplyFloor[\s\S]*onTargetFloorAreaChange: \(floor: number, top: number, height: number\) => \{\s*this\.handleTargetFloorAreaChange\(floor, top, height\)/,
  'TopicDetail must pass target-floor area reporting into reply cards',
)
assert.match(
  detailPage,
  /private handleTargetFloorAreaChange\(floor: number, top: number, height: number\): void[\s\S]*this\.scroller\.scrollBy\(0, delta\)/,
  'TopicDetail must refine nested reply landing with scrollBy instead of changing display mode',
)
assert.doesNotMatch(
  detailPage,
  /setReplyDisplayMode\(ReplyDisplaySettings\.MODE_ORIGIN\)/,
  'user-reply jump must not switch threaded replies into origin mode',
)
assert.match(
  memberParser,
  /private static extractTargetFloor\(fragment: string\): number[\s\S]*match\(\/\^#\(\\d\+\)\$\/\)/,
  'member parser must not treat user-reply #reply anchors as the clicked reply floor',
)
assert.match(
  replyCard,
  /@Param scrollTargetFloor: number = 0[\s\S]*@Event onTargetFloorAreaChange\?: \(floor: number, top: number, height: number\) => void/,
  'ReplyCard must expose target-floor area reporting',
)
assert.match(
  replyCard,
  /private reportTargetFloorArea\(area: Area\): void[\s\S]*this\.floor !== this\.scrollTargetFloor[\s\S]*this\.onTargetFloorAreaChange\(/,
  'ReplyCard must report the rendered area for the matching target floor only',
)
assert.match(
  replyCard,
  /scrollTargetFloor: this\.scrollTargetFloor[\s\S]*onTargetFloorAreaChange: this\.onTargetFloorAreaChange/,
  'ReplyCard must propagate target-floor area reporting through nested child replies',
)

console.log('PASS user reply jump floor contract')
