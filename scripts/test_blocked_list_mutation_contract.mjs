#!/usr/bin/env node

import { readFileSync, existsSync } from 'node:fs'

function source(path) {
  return readFileSync(new URL(`../${path}`, import.meta.url), 'utf8')
}

function fail(message) {
  console.error(`FAIL: ${message}`)
  process.exit(1)
}

function assertIncludes(file, text, needle) {
  if (!text.includes(needle)) {
    fail(`missing mutation contract in ${file}: ${needle}`)
  }
}

function assertNotIncludes(file, text, needle) {
  if (text.includes(needle)) {
    fail(`forbidden mutation contract in ${file}: ${needle}`)
  }
}

function methodBody(text, methodName) {
  const marker = methodName.includes('(') ? methodName : `${methodName}(`
  const start = text.indexOf(marker)
  if (start < 0) {
    fail(`missing method marker: ${marker}`)
  }
  const braceStart = text.indexOf('{', start)
  if (braceStart < 0) {
    fail(`missing method body for: ${marker}`)
  }
  let depth = 0
  for (let i = braceStart; i < text.length; i++) {
    const ch = text[i]
    if (ch === '{') depth += 1
    if (ch === '}') {
      depth -= 1
      if (depth === 0) {
        return text.slice(braceStart + 1, i)
      }
    }
  }
  fail(`unterminated method body for: ${marker}`)
}

function assertCallAfterThenBeforeCatch(file, body, callNeedle) {
  const thenIndex = body.indexOf('.then(() => {')
  const callIndex = body.indexOf(callNeedle)
  const catchIndex = body.indexOf('.catch((error: Error) => {')
  if (thenIndex < 0 || callIndex < 0 || catchIndex < 0 || !(thenIndex < callIndex && callIndex < catchIndex)) {
    fail(`${file} must call ${callNeedle} only inside the success .then block`)
  }
}

const settingsPath = 'shared/src/main/ets/settings/BlockedListSettings.ets'
const topicPagePath = 'feature/detail/src/main/ets/pages/TopicDetailPage.ets'
const userPagePath = 'feature/user/src/main/ets/pages/UserProfilePage.ets'
const userVmPath = 'feature/user/src/main/ets/viewmodel/UserViewModel.ets'
const blockedListsPagePath = 'entry/src/main/ets/pages/BlockedListsPage.ets'

const settings = source(settingsPath)
const topicPage = source(topicPagePath)
const userPage = source(userPagePath)
const userVm = source(userVmPath)
const blockedListsPage = source(blockedListsPagePath)

assertIncludes(settingsPath, settings, 'static async applyIgnoredTopicDelta(topicId: number, ignored: boolean, context?: common.UIAbilityContext, source: BlockedListCaptureSource = {}): Promise<void>')
assertIncludes(settingsPath, settings, 'static async applyBlockedMemberDelta(memberId: number, blocked: boolean, context?: common.UIAbilityContext, source: BlockedListCaptureSource = {}): Promise<void>')
assertIncludes(settingsPath, settings, 'private static async applyIdDelta(')
assertIncludes(settingsPath, settings, "blocked_list_delta_start")
assertIncludes(settingsPath, settings, "blocked_list_delta_success")
assertIncludes(settingsPath, settings, "blocked_list_delta_skip_no_owner")
assertIncludes(settingsPath, settings, "blocked_list_delta_no_context_runtime_only")
assertIncludes(settingsPath, settings, "blocked_list_delta_save_exception")
assertIncludes(settingsPath, settings, 'BlockedListSettings.runtimeSnapshot()')
assertIncludes(settingsPath, settings, 'BlockedListSettings.loadActive(ctx)')
assertIncludes(settingsPath, settings, 'BlockedListSettings.apply(normalized)')
assertIncludes(settingsPath, settings, 'store.putSync(KEY_PREFIX + ownerKey, JSON.stringify(normalized))')
assertIncludes(settingsPath, settings, 'ignoredTopicIds')
assertIncludes(settingsPath, settings, 'blockedMemberIds')

assertIncludes(topicPagePath, topicPage, 'BlockedListSettings')
assertIncludes(topicPagePath, topicPage, 'DiagnosticLogger')
assertIncludes(topicPagePath, topicPage, 'private topicIgnoreDeltaValue(action: V2exTopicModerationAction): boolean | null')
assertIncludes(topicPagePath, topicPage, 'this.topicIgnoreDeltaValue(action)')
assertIncludes(topicPagePath, topicPage, 'BlockedListSettings.applyIgnoredTopicDelta(')
assertIncludes(topicPagePath, topicPage, "source: 'topic_detail_mutation'")
assertIncludes(topicPagePath, topicPage, "trigger: 'topic_ignore_success'")
assertIncludes(topicPagePath, topicPage, "blocked_list_topic_delta_skip_unknown_action")
assertCallAfterThenBeforeCatch(topicPagePath, methodBody(topicPage, 'executeTopicModeration'), 'this.applyTopicIgnoreDeltaAfterSuccess(action)')

assertIncludes(userPagePath, userPage, 'BlockedListSettings')
assertIncludes(userPagePath, userPage, 'DiagnosticLogger')
assertIncludes(userPagePath, userPage, 'private applyBlockedMemberDeltaAfterSuccess(blocked: boolean): void')
assertIncludes(userPagePath, userPage, 'BlockedListSettings.applyBlockedMemberDelta(')
assertIncludes(userPagePath, userPage, "source: 'user_profile_mutation'")
assertIncludes(userPagePath, userPage, "trigger: 'member_block_success'")
assertIncludes(userPagePath, userPage, "blocked_list_member_delta_skip_missing_id")
assertIncludes(userPagePath, userPage, 'this.vm.profile?.id')
assertCallAfterThenBeforeCatch(userPagePath, methodBody(userPage, 'private toggleBlock'), 'this.applyBlockedMemberDeltaAfterSuccess(nextBlocked)')

const toggleBlockBody = methodBody(userPage, 'private toggleBlock')
const firstDelta = toggleBlockBody.indexOf('this.applyBlockedMemberDeltaAfterSuccess(nextBlocked)')
const firstVmToggle = toggleBlockBody.indexOf('.toggleBlock()')
if (firstDelta >= 0 && firstVmToggle >= 0 && firstDelta < firstVmToggle) {
  fail('UserProfilePage must not apply blocked member delta before vm.toggleBlock() succeeds')
}

assertNotIncludes(userVmPath, userVm, 'BlockedListSettings.applyBlockedMemberDelta')
assertNotIncludes(userVmPath, userVm, 'usernameHash')
assertNotIncludes(userVmPath, userVm, 'hashCode')

assertNotIncludes(blockedListsPagePath, blockedListsPage, 'applyIgnoredTopicDelta')
assertNotIncludes(blockedListsPagePath, blockedListsPage, 'applyBlockedMemberDelta')
assertNotIncludes(blockedListsPagePath, blockedListsPage, "topic_ignore_success")
assertNotIncludes(blockedListsPagePath, blockedListsPage, "member_block_success")

for (const name of ['Repository', 'EventBus', 'Interceptor']) {
  const forbiddenPaths = [
    `shared/src/main/ets/settings/BlockedList${name}.ets`,
    `shared/src/main/ets/settings/${name}.ets`,
    `shared/src/main/ets/network/BlockedList${name}.ets`,
  ]
  for (const path of forbiddenPaths) {
    if (existsSync(new URL(`../${path}`, import.meta.url))) {
      fail(`must not introduce blocked-list ${name} framework file: ${path}`)
    }
  }
}

console.log('PASS: blocked list mutation contract')
