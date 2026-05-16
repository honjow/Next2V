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
const settingsPage = read('feature/settings/src/main/ets/pages/SettingsPage.ets')
const topic = read('feature/detail/src/main/ets/pages/TopicDetailPage.ets')
const index = read('shared/src/main/ets/Index.ets')
const entry = read('entry/src/main/ets/entryability/EntryAbility.ets')
const all = [storage, settings, motion, settingsPage, topic, index, entry].join('\n')
const followTouchBlock = sliceBetween(
  topic,
  'private trackReplyActionFollowOperation(event: TouchEvent): void',
  'private onMotionHandEdgeChanged',
)
const verticalScrollBlock = sliceBetween(
  topic,
  'private reportFollowOperationWhenVerticalScroll(): void',
  'private clearFollowOperationTouchState',
)
const downBlock = sliceBetween(
  followTouchBlock,
  'if (event.type === TouchType.Down)',
  'if (event.type === TouchType.Move)',
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
expect(/if \(smartGripSupported\)[\s\S]*智感握姿[\s\S]*跟随操作[\s\S]*固定左侧[\s\S]*固定右侧/.test(settings), 'support-aware option labels/order missing')
expect(!all.includes('操作手'), 'forbidden UI copy 操作手 present')

expect(settingsPage.includes("title: '回复按钮对齐方式'"), 'settings row title missing')
expect(settingsPage.includes("'智感握姿'"), 'smart grip label missing in settings UI')
expect(settingsPage.includes("'跟随操作'"), 'follow operation label missing in settings UI')
expect(settingsPage.includes('if (this.motionHoldingHandSupported)'), 'settings menu must hide smart grip when unsupported')

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

expect(topic.includes('@StorageLink(StorageKeys.MOTION_HAND_EDGE)') && topic.includes("motionHandEdge: string = 'right'"), 'TopicDetailPage motion edge initial value must be right')
expect(topic.includes("visualMotionHandEdge: string = 'right'"), 'TopicDetailPage visual edge initial value must be right')
expect(topic.includes('.hitTestBehavior(HitTestMode.Transparent)'), 'HDS no-click transparent hit-test structure missing')
expect(topic.includes('left: ThemeConstants.SPACE_LG') && topic.includes('right: ThemeConstants.SPACE_LG'), 'HDS ActionBar horizontal padding changed/missing')
expect(topic.includes('MotionHandStateService.reportFollowOperationX'), 'TopicDetailPage does not report follow operation touches')
expect(!/FlexAlign\.Center/.test(topic.slice(topic.indexOf('private topicDetailReplyActionBarAlign'), topic.indexOf('private onMotionHandEdgeChanged'))), 'ActionBar align should not use center fallback')

expect(topic.includes('FOLLOW_OPERATION_VERTICAL_SCROLL_THRESHOLD: number = 24'), 'vertical scroll threshold missing')
expect(topic.includes('FOLLOW_OPERATION_VERTICAL_DOMINANCE_RATIO: number = 1.2'), 'vertical dominance ratio missing')
expect(topic.includes('followOperationStartX') && topic.includes('followOperationStartY'), 'follow operation start touch state missing')
expect(topic.includes('followOperationLatestX') && topic.includes('followOperationLatestY'), 'follow operation latest touch state missing')
expect(followTouchBlock.includes('event.type === TouchType.Down'), 'Down touch sequence handling missing')
expect(followTouchBlock.includes('event.type === TouchType.Move'), 'Move touch sequence handling missing')
expect(followTouchBlock.includes('event.type === TouchType.Up || event.type === TouchType.Cancel'), 'Up/Cancel cleanup handling missing')
expect(!downBlock.includes('MotionHandStateService.reportFollowOperationX'), 'Down must not report/switch follow operation')
expect(verticalScrollBlock.includes('absDy < this.FOLLOW_OPERATION_VERTICAL_SCROLL_THRESHOLD'), 'follow operation must require vertical threshold')
expect(verticalScrollBlock.includes('absDy < absDx * this.FOLLOW_OPERATION_VERTICAL_DOMINANCE_RATIO'), 'follow operation must require vertical dominance')
expect(verticalScrollBlock.includes('MotionHandStateService.reportFollowOperationX(this.followOperationStartX, this.detailRootWidth)'), 'follow operation should use startX for edge selection')
expect(!/MotionHandStateService\.reportFollowOperationX\(touch\.x/.test(topic), 'raw touch x must not be reported directly')
expect(!/event\.type\s*!==\s*TouchType\.Down[\s\S]*event\.type\s*!==\s*TouchType\.Move[\s\S]*event\.type\s*!==\s*TouchType\.Up[\s\S]*MotionHandStateService\.reportFollowOperationX/.test(followTouchBlock), 'old Down/Move/Up direct-report behavior remains')

expect(index.includes("ReplyActionAlignmentSettings } from './settings/ReplyActionAlignmentSettings'"), 'ReplyActionAlignmentSettings export missing')
expect(entry.includes('ReplyActionAlignmentSettings.load(this.context)'), 'startup load missing')

if (process.exitCode) {
  process.exit(process.exitCode)
}
console.log('PASS reply action alignment static checks')
