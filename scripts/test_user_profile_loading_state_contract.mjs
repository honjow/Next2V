#!/usr/bin/env node
import assert from 'node:assert/strict'
import fs from 'node:fs'
import path from 'node:path'

const repo = process.cwd()
const page = fs.readFileSync(
  path.join(repo, 'feature/user/src/main/ets/pages/UserProfilePage.ets'),
  'utf8'
)
const vm = fs.readFileSync(
  path.join(repo, 'feature/user/src/main/ets/viewmodel/UserViewModel.ets'),
  'utf8'
)

function indexOfRequired(source, needle, label) {
  const index = source.indexOf(needle)
  assert.notEqual(index, -1, `${label} missing ${needle}`)
  return index
}

function sliceBetween(source, startNeedle, endNeedle, label) {
  const start = indexOfRequired(source, startNeedle, label)
  const end = source.indexOf(endNeedle, start + startNeedle.length)
  assert.notEqual(end, -1, `${label} missing end marker ${endNeedle}`)
  return source.slice(start, end)
}

const loadMethod = sliceBetween(vm, 'async load(): Promise<void> {', '  async toggleFollow()', 'UserViewModel.load')
const profileAssign = indexOfRequired(loadMethod, 'this.profile = await this.api.getMember(this.username)', 'UserViewModel.load')
const snapshotFetch = indexOfRequired(loadMethod, 'const snapshot = await this.api.getMemberPageSnapshot', 'UserViewModel.load')
const topicDetailsFetch = indexOfRequired(loadMethod, 'const topics = await this.api.getTopicsByIds(snapshot.topicIds)', 'UserViewModel.load')
const topicCountAssign = indexOfRequired(loadMethod, 'this.recentTopicCount = topics.length', 'UserViewModel.load')
const finallyClearsLoading = indexOfRequired(loadMethod, 'this.isLoading = false', 'UserViewModel.load')

assert(
  profileAssign < snapshotFetch &&
    snapshotFetch < topicDetailsFetch &&
    topicDetailsFetch < topicCountAssign &&
    topicCountAssign < finallyClearsLoading,
  'UserViewModel.load contract should expose profile before activity counts settle'
)

const activityBlock = sliceBetween(page, 'if (this.activityTab === 0) {', '        }\n      } else {', 'UserProfilePage activity block')
const topicHidden = indexOfRequired(activityBlock, 'if (this.vm.topicsHidden)', 'topic activity branch')
const topicLoading = indexOfRequired(activityBlock, '} else if (this.vm.recentTopicCount === 0 && this.vm.isLoading) {', 'topic activity branch')
const topicLoadingComponent = indexOfRequired(activityBlock, 'UserProfileLoadingState()', 'topic activity branch')
const topicEmptyCheck = indexOfRequired(activityBlock, '} else if (this.vm.recentTopicCount === 0) {', 'topic activity branch')
const topicEmptyMessage = indexOfRequired(activityBlock, "UserProfileEmptyCard({ message: '暂无主题' })", 'topic activity branch')

assert(
  topicHidden < topicLoading &&
    topicLoading < topicLoadingComponent &&
    topicLoadingComponent < topicEmptyCheck &&
    topicEmptyCheck < topicEmptyMessage,
  'topic activity branch must preserve hidden precedence, then loading, then real empty state'
)

const replyBranchStart = indexOfRequired(activityBlock, '} else {\n            if (this.vm.recentReplyCount === 0 && this.vm.isLoading) {', 'reply activity branch')
const replyLoading = indexOfRequired(activityBlock.slice(replyBranchStart), 'UserProfileLoadingState()', 'reply activity branch')
const replyEmptyCheck = indexOfRequired(activityBlock.slice(replyBranchStart), '} else if (this.vm.recentReplyCount === 0) {', 'reply activity branch')
const replyEmptyMessage = indexOfRequired(activityBlock.slice(replyBranchStart), "UserProfileEmptyCard({ message: '暂无回复' })", 'reply activity branch')

assert(
  replyLoading < replyEmptyCheck && replyEmptyCheck < replyEmptyMessage,
  'reply activity branch must render loading before the real empty state'
)

assert.match(
  activityBlock,
  /if \(this\.vm\.topicsHidden\)[\s\S]*?UserProfileEmptyCard\(\{ message: '主题列表已隐藏' \}\)[\s\S]*?\} else if \(this\.vm\.recentTopicCount === 0 && this\.vm\.isLoading\) \{/,
  'hidden topics state must stay ahead of the topic loading branch'
)

console.log('user profile loading state contract OK')
