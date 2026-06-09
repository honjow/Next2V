#!/usr/bin/env node
import fs from 'node:fs'
import path from 'node:path'

const root = process.cwd()
const read = (p) => fs.readFileSync(path.join(root, p), 'utf8')
const fail = (message) => {
  console.error(`FAIL: ${message}`)
  process.exitCode = 1
}
const expect = (condition, message) => {
  if (!condition) fail(message)
}
const sliceBetween = (source, startNeedle, endNeedle) => {
  const start = source.indexOf(startNeedle)
  const end = source.indexOf(endNeedle, start + startNeedle.length)
  if (start < 0 || end < 0) return ''
  return source.slice(start, end)
}

const storage = read('shared/src/main/ets/constants/StorageKeys.ets')
const settings = read('shared/src/main/ets/settings/ReplyActionAlignmentSettings.ets')
const motion = read('shared/src/main/ets/services/MotionHandStateService.ets')
const motionEdgeState = read('shared/src/main/ets/state/MotionHandEdgeState.ets')
const settingsPage = read('feature/settings/src/main/ets/pages/SettingsPage.ets')
const settingsCoordinator = read('feature/settings/src/main/ets/model/SettingsPageCoordinator.ets')
const topic = read('feature/detail/src/main/ets/pages/TopicDetailPage.ets')
const index = read('shared/src/main/ets/Index.ets')
const entry = read('entry/src/main/ets/entryability/EntryAbility.ets')
const settingsBootstrap = read('shared/src/main/ets/settings/SettingsBootstrap.ets')
// The follow-operation touch sequence was extracted from TopicDetailPage into a pure, separately
// tested coordinator (TopicDetailFloatingActionCoordinator.updateTouch); the page now delegates the
// raw TouchEvent to it. Assert the sequence invariants where they actually live now.
const detailCoordinator = read('feature/detail/src/main/ets/model/TopicDetailFloatingActionCoordinator.ets')
const all = [storage, settings, motion, settingsPage, topic, index, entry, settingsBootstrap].join('\n')
const followTouchBlock = sliceBetween(
  detailCoordinator,
  'static updateTouch(',
  '}\n}',
)
const verticalScrollBlock = followTouchBlock
const downBlock = sliceBetween(
  followTouchBlock,
  'if (type === TouchType.Down)',
  'if (!state.active)',
)
const serviceFollowBlock = sliceBetween(
  motion,
  'static reportFollowOperationX',
  'static edgeForFollowOperationX',
)
const officialStatusBlock = sliceBetween(
  motion,
  'private static handleHoldingStatus',
  'private static scheduleHoldingEdge',
)

expect(storage.includes("REPLY_ACTION_ALIGNMENT_MODE: string = 'replyActionAlignmentMode'"), 'storage key replyActionAlignmentMode missing')
expect(storage.includes("MOTION_HOLDING_HAND_SUPPORTED: string = 'motionHoldingHandSupported'"), 'holding support storage key missing')
expect(settings.includes("MODE_SMART_GRIP: ReplyActionAlignmentMode = 'smartGrip'"), 'smartGrip mode missing')
expect(settings.includes("MODE_FOLLOW_OPERATION: ReplyActionAlignmentMode = 'followOperation'"), 'followOperation mode missing')
expect(settings.includes("MODE_FIXED_LEFT: ReplyActionAlignmentMode = 'fixedLeft'"), 'fixedLeft mode missing')
expect(settings.includes("MODE_FIXED_RIGHT: ReplyActionAlignmentMode = 'fixedRight'"), 'fixedRight mode missing')
expect(/defaultMode\(smartGripSupported: boolean\)[\s\S]*smartGripSupported[\s\S]*MODE_SMART_GRIP[\s\S]*MODE_FOLLOW_OPERATION/.test(settings), 'support-aware defaults missing')
expect(/if \(smartGripSupported\)[\s\S]*app\.string\.smart_grip[\s\S]*app\.string\.follow_operation[\s\S]*app\.string\.fixed_left[\s\S]*app\.string\.fixed_right/.test(settings), 'support-aware option labels/order missing')
expect(!all.includes('操作手'), 'forbidden UI copy 操作手 present')

expect(settingsPage.includes("title: $r('app.string.reply_action_alignment')"), 'settings row title missing')
expect(settingsCoordinator.includes("label: $r('app.string.smart_grip')"), 'smart grip label missing in settings UI')
expect(settingsCoordinator.includes("label: $r('app.string.follow_operation')"), 'follow operation label missing in settings UI')
expect(/replyActionAlignmentOptions\(motionHoldingHandSupported: boolean\)[\s\S]*if \(motionHoldingHandSupported\)[\s\S]*MODE_SMART_GRIP/.test(settingsCoordinator), 'settings menu must hide smart grip when unsupported')

expect(motion.includes('FOLLOW_OPERATION_SAFE_ZONE_RATIO: number = 0.28'), '28% safe zone constant missing')
expect(/leftBoundary = width \* \(0\.5 - safeHalf\)/.test(motion), 'left safe-zone boundary missing')
expect(/rightBoundary = width \* \(0\.5 \+ safeHalf\)/.test(motion), 'right safe-zone boundary missing')
expect(motion.includes('FOLLOW_OPERATION_THROTTLE_MS'), 'follow operation throttle missing')
expect(motion.includes("MotionHandStateService.setEdge('right')"), 'default edge must be right')
expect(!motion.includes("setEdge('center')"), 'center edge default must not remain')
expect(motion.includes("motion.on('holdingHandChanged'"), 'official holdingHandChanged subscription missing')
expect(motion.includes('setHoldingHandSupported(true)'), 'support success state missing')
expect(motion.includes('setHoldingHandSupported(false)'), 'support failure state missing')
expect(motion.includes('effectiveAlignmentMode() !== ReplyActionAlignmentSettings.MODE_SMART_GRIP'), 'official updates must be gated by smart grip mode')
expect(motion.includes('effectiveAlignmentMode() !== ReplyActionAlignmentSettings.MODE_FOLLOW_OPERATION'), 'follow updates must be gated by follow operation mode')
expect(!/holdingHandChanged|HoldingHandStatus|handleHoldingStatus|motion\./.test(serviceFollowBlock), 'follow operation must not use official holding-hand API')
expect(/MODE_SMART_GRIP[\s\S]*scheduleHoldingEdge/.test(officialStatusBlock), 'official API updates should remain smartGrip-only')

expect(topic.includes('connectMotionHandEdge()') && motionEdgeState.includes("@Trace edge: string = 'right'"), 'TopicDetailPage motion edge initial value must be right')
expect(topic.includes("visualMotionHandEdge: string = 'right'"), 'TopicDetailPage visual edge initial value must be right')
expect(topic.includes('.hitTestBehavior(HitTestMode.Transparent)'), 'HDS no-click transparent hit-test structure missing')
expect(topic.includes('TOPIC_DETAIL_REPLY_BUTTON_ACTIVITY_PADDING: number = ThemeConstants.SPACE_LG'), 'HDS ActionBar horizontal padding changed/missing')
expect(topic.includes('MotionHandStateService.reportFollowOperationX'), 'TopicDetailPage does not report follow operation touches')
expect(detailCoordinator.includes('static actionBarAlign(edge: string): FlexAlign') && !/actionBarAlign[\s\S]*FlexAlign\.Center/.test(detailCoordinator), 'ActionBar align should not use center fallback')

expect(topic.includes('FOLLOW_OPERATION_VERTICAL_SCROLL_THRESHOLD: number = 24'), 'vertical scroll threshold missing')
expect(topic.includes('FOLLOW_OPERATION_VERTICAL_DOMINANCE_RATIO: number = 1.2'), 'vertical dominance ratio missing')
expect(detailCoordinator.includes('startX: number') && detailCoordinator.includes('startY: number'), 'follow operation start touch state missing')
expect(detailCoordinator.includes('latestX: number') && detailCoordinator.includes('latestY: number'), 'follow operation latest touch state missing')
expect(followTouchBlock.includes('type === TouchType.Down'), 'Down touch sequence handling missing')
expect(followTouchBlock.includes('type !== TouchType.Move'), 'Move touch sequence handling missing')
expect(followTouchBlock.includes('type === TouchType.Up || type === TouchType.Cancel'), 'Up/Cancel cleanup handling missing')
expect(!downBlock.includes('shouldReport: true'), 'Down must not report/switch follow operation')
expect(verticalScrollBlock.includes('absDy < verticalThreshold'), 'follow operation must require vertical threshold')
expect(verticalScrollBlock.includes('absDy < absDx * verticalDominanceRatio'), 'follow operation must require vertical dominance')
expect(verticalScrollBlock.includes('reportX: state.startX'), 'follow operation should use startX for edge selection')
expect(topic.includes('MotionHandStateService.reportFollowOperationX(update.reportX, this.detailRootWidth)'), 'page must report the coordinator-derived startX edge, not raw touch x')
expect(!/MotionHandStateService\.reportFollowOperationX\(touch\.x/.test(topic), 'raw touch x must not be reported directly')

expect(index.includes("ReplyActionAlignmentSettings } from './settings/ReplyActionAlignmentSettings'"), 'ReplyActionAlignmentSettings export missing')
expect(entry.includes('SettingsBootstrap.loadAll(this.context)'), 'startup settings bootstrap load missing')
expect(settingsBootstrap.includes("ReplyActionAlignmentSettings } from './ReplyActionAlignmentSettings'"), 'startup bootstrap reply action settings import missing')
expect(settingsBootstrap.includes('restoreReplyActionAlignment'), 'startup bootstrap reply action restore missing')
expect(
  /ReplyActionAlignmentSettings\.loadFromStore\([\s\S]*ReplyActionAlignmentSettings\.load\(context\)/.test(settingsBootstrap),
  'startup bootstrap reply action load missing',
)

if (process.exitCode) {
  process.exit(process.exitCode)
}
console.log('PASS reply action alignment static checks')
