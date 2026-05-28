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

const accountPagePath = 'entry/src/main/ets/pages/AccountPage.ets'
assert(fs.existsSync(path.join(repo, accountPagePath)), 'AccountPage.ets must exist')
const accountPage = read(accountPagePath)

const aboutStart = accountPage.indexOf('aboutToAppear(): void {')
const aboutEnd = accountPage.indexOf('onLocalDataUpdated', aboutStart)
assert(aboutStart >= 0 && aboutEnd > aboutStart, 'AccountPage lifecycle boundaries missing')
const lifecycleBlock = accountPage.slice(aboutStart, aboutEnd)
assert(lifecycleBlock.includes("this.requestDashboardRefresh('appear')"), 'aboutToAppear must schedule the dashboard refresh')
assert(lifecycleBlock.includes('aboutToDisappear(): void {') && lifecycleBlock.includes('this.clearDashboardRefreshTimer()'), 'AccountPage must clear pending dashboard refresh timer on disappear')
assert(!lifecycleBlock.includes('this.loadAccounts()'), 'aboutToAppear must not synchronously load accounts')
assert(!lifecycleBlock.includes('this.refreshLocalData()'), 'aboutToAppear must not synchronously refresh local data')

for (const token of [
  'private dashboardRefreshTimerId: number = -1',
  'private requestDashboardRefresh(reason: string): void',
  "DiagnosticLogger.info('account', 'account_dashboard_refresh_coalesced'",
  'this.dashboardRefreshTimerId = setTimeout((): void => {',
  'private refreshDashboardSnapshot(reason: string): void',
  'private localStatsInFlight: boolean = false',
  'private accountListInFlight: boolean = false',
  "DiagnosticLogger.info('account', 'account_local_stats_load_skip'",
  "DiagnosticLogger.info('account', 'account_list_load_skip'",
]) {
  assert(accountPage.includes(token), `AccountPage dashboard refresh contract missing ${token}`)
}

const refreshStart = accountPage.indexOf('private refreshDashboardSnapshot(reason: string): void {')
const statsStart = accountPage.indexOf('private loadLocalContentStats(): void {', refreshStart)
assert(refreshStart >= 0 && statsStart > refreshStart, 'AccountPage refreshDashboardSnapshot boundaries missing')
const refreshBody = accountPage.slice(refreshStart, statsStart)
assert(refreshBody.includes('this.loadLocalContentStats()'), 'dashboard refresh must load count-only local stats')
assert(refreshBody.includes('this.loadAccounts()'), 'dashboard refresh must load account summary')
for (const forbidden of [
  'loadSavedTopics',
  'loadSavedNodes',
  'loadViewedTopics',
  'loadTopicReadStates',
  'syncTopicReadStates',
]) {
  assert(!refreshBody.includes(forbidden), `dashboard refresh must not perform full local-list work: ${forbidden}`)
}

for (const forbidden of [
  '@State private savedTopics',
  '@State private savedNodes',
  '@State private viewedTopics',
  'this.savedTopics = result.items',
  'this.savedNodes = result.items',
  'this.viewedTopics = result.items',
]) {
  assert(!accountPage.includes(forbidden), `Account dashboard must not retain unused full local list state: ${forbidden}`)
}

console.log('account dashboard refresh contract ok')
