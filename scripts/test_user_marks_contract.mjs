#!/usr/bin/env node
import fs from 'node:fs'
import path from 'node:path'

const repo = process.cwd()
const read = (rel) => fs.readFileSync(path.join(repo, rel), 'utf8')
const exists = (rel) => fs.existsSync(path.join(repo, rel))
const assert = (condition, message) => {
  if (!condition) {
    throw new Error(message)
  }
}

const localData = read('shared/src/main/ets/storage/LocalDataStore.ets')
const stateRel = 'shared/src/main/ets/state/UserMarkState.ets'
const settingsRel = 'shared/src/main/ets/settings/UserMarkSettings.ets'
const badgesRel = 'shared/src/main/ets/components/UserMarkBadges.ets'
assert(exists(stateRel), 'UserMarkState must exist')
assert(exists(settingsRel), 'UserMarkSettings must exist')
assert(exists(badgesRel), 'UserMarkBadges must exist')

const state = read(stateRel)
const settings = read(settingsRel)
const badges = read(badgesRel)
const userName = read('shared/src/main/ets/components/UserName.ets')
const conciseListRow = read('shared/src/main/ets/components/ConciseListRow.ets')
const replyHeader = read('shared/src/main/ets/components/reply/ReplyCardHeader.ets')
const replyCard = read('shared/src/main/ets/components/ReplyCard.ets')
const replyLayoutPolicy = read('shared/src/main/ets/components/reply/ReplyCardLayoutPolicy.ets')
const topicDetailComponents = read('feature/detail/src/main/ets/components/TopicDetailComponents.ets')
const profileComponents = read('feature/user/src/main/ets/components/UserProfileComponents.ets')
const profilePage = read('feature/user/src/main/ets/pages/UserProfilePage.ets')
const appbar = read('shared/src/main/ets/state/UserProfileAppbarState.ets')
const index = read('entry/src/main/ets/pages/Index.ets')
const sharedIndex = read('shared/src/main/ets/Index.ets')
const backupTypes = read('shared/src/main/ets/backup/BackupTypes.ets')
const backupAdapter = read('shared/src/main/ets/backup/BackupLocalDataAdapter.ets')
const bootstrap = read('shared/src/main/ets/settings/SettingsBootstrap.ets')
const localDataSettings = read('shared/src/main/ets/settings/LocalDataSettings.ets')
const appStrings = read('shared/src/main/ets/i18n/AppStrings.ets')

for (const snippet of [
  'export const LOCAL_DATA_SCHEMA_VERSION: number = 7',
  'CREATE TABLE IF NOT EXISTS user_mark_labels',
  'label_id TEXT PRIMARY KEY',
  'CREATE INDEX IF NOT EXISTS idx_user_mark_labels_sort',
  'CREATE TABLE IF NOT EXISTS user_mark_assignments',
  'PRIMARY KEY(username_key, label_id)',
  'CREATE INDEX IF NOT EXISTS idx_user_mark_assignments_username',
  'CREATE INDEX IF NOT EXISTS idx_user_mark_assignments_label',
  'await store.execute(SQL_CREATE_USER_MARK_LABELS_TABLE)',
  'await store.execute(SQL_CREATE_USER_MARK_ASSIGNMENTS_TABLE)',
]) {
  assert(localData.includes(snippet), `LocalDataStore missing user mark schema contract: ${snippet}`)
}

for (const snippet of [
  '@ObservedV2',
  '@Trace labelsJson: string =',
  '@Trace assignmentsJson: string =',
  '@Trace displayLimit: number = 2',
  '@Trace combinedBadge: boolean = false',
  'connectUserMarks()',
  'AppStorageV2.connect(UserMarkState',
]) {
  assert(state.includes(snippet), `UserMarkState missing V2 contract: ${snippet}`)
}

for (const snippet of [
  "import { LocalDataStore } from '../storage/LocalDataStore'",
  'export interface UserMarkLabel',
  'export interface UserMarkAssignment',
  'static async createLabelAndAssign',
  'static async assignLabel',
  'static async unassignLabel',
  'static async deleteLabel',
  'static async saveDisplayLimit',
  'static async saveCombinedBadge',
  'static async restoreBackup',
  'static async clearAll',
  'KEY_COMBINED_BADGE',
  'static visibleLabelsForUsername',
  'static overflowCountForUsername',
  'connectUserMarks()',
  'LocalDataPublisher.touchLocalData()',
]) {
  assert(settings.includes(snippet), `UserMarkSettings missing contract: ${snippet}`)
}

for (const snippet of [
  'UserMarkBadgeRow',
  'connectUserMarks',
  'defaultSheetOptions(SheetSize.MEDIUM',
  'UserMarkSettings.visibleLabelsForUsername',
  'UserMarkSettings.allLabelsForUsername',
  'visibleLimit: number = 0',
  'showOverflow: boolean = true',
  'maxBadgeWidth: number = 92',
  'private CombinedBadge()',
  'this.marks.combinedBadge',
  'private SheetBadge(label: UserMarkLabel)',
]) {
  assert(badges.includes(snippet), `UserMarkBadges missing display contract: ${snippet}`)
}

assert(userName.includes('UserMarkBadgeRow({'), 'UserName must display mark badges beside usernames')
assert(userName.includes('markVisibleLimit: number = 0'), 'UserName must pass compact mark limit settings')
assert(replyHeader.includes("import { UserName } from '../UserName'"), 'ReplyCardHeader must reuse UserName for mark-aware reply authors')
assert(replyHeader.includes('markVisibleLimit: this.isCompact ? 1 : 0'), 'ReplyCardHeader must compact user marks in compact replies')
assert(replyHeader.includes('FlexWrap.Wrap'), 'ReplyCardHeader must use natural wrap for compact author marks')
assert(replyHeader.includes('LengthMetrics.vp(ThemeConstants.SPACE_SM)'), 'ReplyCardHeader compact wrap must use project spacing metrics')
assert(!replyHeader.includes('showCompactMarkOverflow'), 'ReplyCardHeader must not gate mark overflow through width tiers')
assert(!replyCard.includes('compactMarkWidth'), 'ReplyCard must not estimate compact mark width')
assert(!replyCard.includes('UserMarkSettings.allLabelsForUsername'), 'ReplyCard layout must not read mark assignments')
assert(!replyLayoutPolicy.includes('compactHeaderMarkWidth'), 'ReplyCardLayoutPolicy must not estimate compact mark width')
assert(!replyCard.includes('this.isHeaderNarrow() || (this.embedded && this.isCompact())'), 'Embedded compact replies must not force narrow layout')
assert(topicDetailComponents.includes('UserName({'), 'TopicDetailHeader must display mark-aware topic authors')
assert(profileComponents.includes('UserMarkBadgeRow'), 'UserProfileCard must display marks beside the profile username')
assert(settings.includes('relativeColorChannel'), 'UserMarkSettings must use relative luminance for badge text color')
assert(settings.includes('if (state.displayLimit !== displayLimit)'), 'UserMarkSettings.apply must not rewrite unchanged display limit trace state')
assert(settings.includes('if (state.combinedBadge !== combinedBadge)'), 'UserMarkSettings.apply must not rewrite unchanged combined badge trace state')
assert(!settings.includes('state.displayLimit = next'), 'saveDisplayLimit must publish through one apply pass only')
assert(!settings.includes('state.combinedBadge = value'), 'saveCombinedBadge must publish through one apply pass only')
assert(conciseListRow.includes('Text(label)'), 'Counter buttons must render visible content instead of relying on Button label styling')
assert(conciseListRow.includes('.padding({ right: ThemeConstants.SPACE_MD })'), 'Counter suffix must reserve right-side spacing')

for (const snippet of [
  '@Local private userMarkSheetVisible',
  '@Local private userMarks: UserMarkState = connectUserMarks()',
  'bindSheet(',
  '$$this.userMarkSheetVisible',
  'AppModalScaffold({',
  'UserMarkSettings.createLabelAndAssign',
  'UserMarkSettings.assignLabel',
  'UserMarkSettings.unassignLabel',
  'UserMarkSettings.deleteLabel',
  'UserMarkSettings.saveDisplayLimit',
  'UserMarkSettings.saveCombinedBadge',
  '@Local private pendingUserMarkLabelId',
  '.swipeAction({ end: this.UserMarkDeleteSwipeEnd(label) })',
  "if (action === 'mark')",
]) {
  assert(profilePage.includes(snippet), `UserProfilePage missing sheet/action contract: ${snippet}`)
}

for (const snippet of [
  '@Trace markLabel: string =',
  'publishUserProfileMarkLabel',
]) {
  assert(appbar.includes(snippet), `UserProfileAppbarState missing mark appbar contract: ${snippet}`)
}
assert(profilePage.includes('publishUserProfileMarkLabel(state.markLabel)'), 'UserProfilePage must publish mark label')
assert(!profilePage.includes('counterDecreaseEnabled: !this.userMarkBusy()'), 'Display limit controls must not flash disabled while assigning a label')
assert(!profilePage.includes('counterIncreaseEnabled: !this.userMarkBusy()'), 'Display limit controls must not flash disabled while assigning a label')
assert(!profilePage.includes('isEnabled: !this.userMarkBusy(),'), 'Combined badge switch must not flash disabled while assigning a label')
assert(index.includes('this.userProfileAppbar.markLabel'), 'Index menu must read mark label')
assert(index.includes('AppStrings.R_USER_ACTION_MARK'), 'Index menu must use localized mark label')
assert(index.includes("this.sendUserProfileAction('mark')"), 'Index menu must send mark command')

for (const snippet of [
  'userMarkLabels?: Object[]',
  'userMarkAssignments?: Object[]',
  'userMarkDisplayLimit?: number',
  'userMarkCombinedBadge?: boolean',
]) {
  assert(backupTypes.includes(snippet), `BackupCollectionsSection missing mark field: ${snippet}`)
}
for (const snippet of [
  'userMarkLabels: userMarks.labels',
  'userMarkAssignments: userMarks.assignments',
  'userMarkCombinedBadge: userMarks.combinedBadge',
  'UserMarkSettings.restoreBackup(context, section)',
]) {
  assert(backupAdapter.includes(snippet), `BackupLocalDataAdapter missing mark backup contract: ${snippet}`)
}
assert(bootstrap.includes('restoreUserMarks(context)'), 'SettingsBootstrap must restore user mark state on startup/reapply')
assert(localDataSettings.includes('UserMarkSettings.clearAll(context)'), 'LocalDataSettings.clearAll must clear local user marks')

for (const snippet of [
  'R_USER_ACTION_MARK',
  'R_USER_MARK_SHEET_TITLE',
  'R_USER_MARK_CREATE_SECTION',
  'R_USER_MARK_EXISTING_SECTION',
  'R_USER_MARK_DISPLAY_LIMIT',
  'R_USER_MARK_COMBINED_BADGE',
]) {
  assert(appStrings.includes(snippet), `AppStrings missing user mark resource: ${snippet}`)
}
assert(sharedIndex.includes("export { UserMarkState, connectUserMarks } from './state/UserMarkState'"), 'shared Index must export UserMarkState')
assert(sharedIndex.includes("export { UserMarkSettings } from './settings/UserMarkSettings'"), 'shared Index must export UserMarkSettings')
assert(sharedIndex.includes("export { UserMarkBadgeRow } from './components/UserMarkBadges'"), 'shared Index must export UserMarkBadgeRow')

for (const locale of ['base', 'en_US', 'zh_CN', 'zh_HK', 'zh_TW', 'ja_JP', 'ko_KR']) {
  const json = JSON.parse(read(`entry/src/main/resources/${locale}/element/string.json`))
  const names = new Set(json.string.map((item) => item.name))
  for (const name of [
    'user_action_mark',
    'user_mark_sheet_title',
    'user_mark_create_section',
    'user_mark_existing_section',
    'user_mark_display_section',
    'user_mark_name_placeholder',
    'user_mark_add',
    'user_mark_empty',
    'user_mark_name_required',
    'user_mark_display_limit',
    'user_mark_display_limit_hint',
    'user_mark_combined_badge',
    'user_mark_combined_badge_hint',
  ]) {
    assert(names.has(name), `${locale} missing string ${name}`)
  }
}

console.log('user marks contract OK')
