import { motion } from '@kit.MultimodalAwarenessKit'
import { BusinessError } from '@ohos.base'
import { StorageKeys } from '../constants/StorageKeys'
import { ReplyActionAlignmentSettings } from '../settings/ReplyActionAlignmentSettings'
import type { ReplyActionAlignmentMode } from '../settings/ReplyActionAlignmentSettings'
import { connectMotionHandEdge } from '../state/MotionHandEdgeState'

export type MotionHandEdge = 'left' | 'right'

type StableMotionHandEdge = 'left' | 'right'

export class MotionHandStateService {
  private static startAttempted: boolean = false
  private static holdingSubscribed: boolean = false
  private static pendingHoldingEdge: StableMotionHandEdge | null = null
  private static debounceTimerId: number = 0
  private static lastFollowUpdateAt: number = 0
  private static readonly EDGE_DEBOUNCE_MS: number = 450
  static readonly FOLLOW_OPERATION_SAFE_ZONE_RATIO: number = 0.28
  private static readonly FOLLOW_OPERATION_THROTTLE_MS: number = 260

  private static readonly holdingChanged = (status: motion.HoldingHandStatus): void => {
    MotionHandStateService.handleHoldingStatus(status)
  }

  static start(): void {
    MotionHandStateService.ensureDefaultEdge()
    if (MotionHandStateService.startAttempted) {
      MotionHandStateService.applyAlignmentMode()
      return
    }
    MotionHandStateService.startAttempted = true

    try {
      motion.on('holdingHandChanged', MotionHandStateService.holdingChanged)
      MotionHandStateService.holdingSubscribed = true
      MotionHandStateService.setHoldingHandSupported(true)
    } catch (error) {
      MotionHandStateService.setHoldingHandSupported(false)
      MotionHandStateService.logError('subscribe holding hand', error)
    }
    MotionHandStateService.applyAlignmentMode()
  }

  static stop(): void {
    if (MotionHandStateService.holdingSubscribed) {
      try {
        motion.off('holdingHandChanged', MotionHandStateService.holdingChanged)
      } catch (error) {
        MotionHandStateService.logError('unsubscribe holding hand', error)
      }
      MotionHandStateService.holdingSubscribed = false
    }

    MotionHandStateService.cancelPendingEdge()
    MotionHandStateService.startAttempted = false
  }

  static applyAlignmentMode(mode?: string): void {
    if (mode !== undefined) {
      AppStorage.setOrCreate<ReplyActionAlignmentMode>(
        StorageKeys.REPLY_ACTION_ALIGNMENT_MODE,
        ReplyActionAlignmentSettings.normalizeMode(mode),
      )
    }
    MotionHandStateService.ensureDefaultEdge()
    const rawMode = AppStorage.get<string>(StorageKeys.REPLY_ACTION_ALIGNMENT_MODE) ??
      ReplyActionAlignmentSettings.MODE_UNSET
    if (ReplyActionAlignmentSettings.normalizeMode(rawMode) === ReplyActionAlignmentSettings.MODE_UNSET) {
      AppStorage.setOrCreate<ReplyActionAlignmentMode>(
        StorageKeys.REPLY_ACTION_ALIGNMENT_MODE,
        ReplyActionAlignmentSettings.defaultMode(MotionHandStateService.isHoldingHandSupported()),
      )
    }
    const effectiveMode = MotionHandStateService.effectiveAlignmentMode()
    if (effectiveMode === ReplyActionAlignmentSettings.MODE_FIXED_LEFT) {
      MotionHandStateService.cancelPendingEdge()
      MotionHandStateService.setEdge('left')
      return
    }
    if (effectiveMode === ReplyActionAlignmentSettings.MODE_FIXED_RIGHT) {
      MotionHandStateService.cancelPendingEdge()
      MotionHandStateService.setEdge('right')
      return
    }
    if (effectiveMode !== ReplyActionAlignmentSettings.MODE_SMART_GRIP) {
      MotionHandStateService.cancelPendingEdge()
    }
  }

  static reportFollowOperationX(x: number, width: number): void {
    if (MotionHandStateService.effectiveAlignmentMode() !== ReplyActionAlignmentSettings.MODE_FOLLOW_OPERATION) {
      return
    }
    const nextEdge = MotionHandStateService.edgeForFollowOperationX(x, width)
    if (nextEdge === null) {
      return
    }
    const now = Date.now()
    if (
      MotionHandStateService.lastFollowUpdateAt > 0 &&
      now - MotionHandStateService.lastFollowUpdateAt < MotionHandStateService.FOLLOW_OPERATION_THROTTLE_MS &&
      AppStorage.get<MotionHandEdge>(StorageKeys.MOTION_HAND_EDGE) !== nextEdge
    ) {
      return
    }
    MotionHandStateService.lastFollowUpdateAt = now
    if (AppStorage.get<MotionHandEdge>(StorageKeys.MOTION_HAND_EDGE) !== nextEdge) {
      MotionHandStateService.setEdge(nextEdge)
    }
  }

  static edgeForFollowOperationX(x: number, width: number): MotionHandEdge | null {
    if (!Number.isFinite(x) || !Number.isFinite(width) || width <= 0) {
      return null
    }
    const safeHalf = MotionHandStateService.FOLLOW_OPERATION_SAFE_ZONE_RATIO / 2
    const leftBoundary = width * (0.5 - safeHalf)
    const rightBoundary = width * (0.5 + safeHalf)
    if (x < leftBoundary) {
      return 'left'
    }
    if (x > rightBoundary) {
      return 'right'
    }
    return null
  }

  private static effectiveAlignmentMode(): ReplyActionAlignmentMode {
    const rawMode = AppStorage.get<string>(StorageKeys.REPLY_ACTION_ALIGNMENT_MODE) ??
      ReplyActionAlignmentSettings.MODE_UNSET
    return ReplyActionAlignmentSettings.effectiveMode(rawMode, MotionHandStateService.isHoldingHandSupported())
  }

  private static isHoldingHandSupported(): boolean {
    return AppStorage.get<boolean>(StorageKeys.MOTION_HOLDING_HAND_SUPPORTED) ?? false
  }

  private static setHoldingHandSupported(supported: boolean): void {
    AppStorage.setOrCreate<boolean>(StorageKeys.MOTION_HOLDING_HAND_SUPPORTED, supported)
  }

  private static ensureDefaultEdge(): void {
    const current = AppStorage.get<MotionHandEdge>(StorageKeys.MOTION_HAND_EDGE)
    if (current !== 'left' && current !== 'right') {
      MotionHandStateService.setEdge('right')
    }
  }

  private static handleHoldingStatus(status: motion.HoldingHandStatus): void {
    if (MotionHandStateService.effectiveAlignmentMode() !== ReplyActionAlignmentSettings.MODE_SMART_GRIP) {
      return
    }
    if (status === motion.HoldingHandStatus.LEFT_HAND_HELD) {
      MotionHandStateService.scheduleHoldingEdge('left')
      return
    }
    if (status === motion.HoldingHandStatus.RIGHT_HAND_HELD) {
      MotionHandStateService.scheduleHoldingEdge('right')
    }
  }

  private static scheduleHoldingEdge(edge: StableMotionHandEdge): void {
    MotionHandStateService.pendingHoldingEdge = edge
    MotionHandStateService.ensureDebounceTimer()
  }

  private static ensureDebounceTimer(): void {
    if (MotionHandStateService.debounceTimerId > 0) {
      return
    }
    MotionHandStateService.debounceTimerId = setTimeout(() => {
      MotionHandStateService.flushPendingEdge()
    }, MotionHandStateService.EDGE_DEBOUNCE_MS)
  }

  private static flushPendingEdge(): void {
    const nextEdge = MotionHandStateService.pendingHoldingEdge
    MotionHandStateService.debounceTimerId = 0
    MotionHandStateService.pendingHoldingEdge = null

    if (
      nextEdge !== null &&
      MotionHandStateService.effectiveAlignmentMode() === ReplyActionAlignmentSettings.MODE_SMART_GRIP &&
      AppStorage.get<MotionHandEdge>(StorageKeys.MOTION_HAND_EDGE) !== nextEdge
    ) {
      MotionHandStateService.setEdge(nextEdge)
    }
  }

  private static cancelPendingEdge(): void {
    if (MotionHandStateService.debounceTimerId > 0) {
      clearTimeout(MotionHandStateService.debounceTimerId)
      MotionHandStateService.debounceTimerId = 0
    }
    MotionHandStateService.pendingHoldingEdge = null
  }

  private static setEdge(edge: MotionHandEdge): void {
    // Single dual-write chokepoint: V1 AppStorage (legacy @StorageLink readers) + V2 mirror
    // (read by @ComponentV2 TopicDetailPage via @Monitor). Keeps the two stores in lockstep.
    AppStorage.setOrCreate<MotionHandEdge>(StorageKeys.MOTION_HAND_EDGE, edge)
    connectMotionHandEdge().edge = edge
  }

  private static logError(action: string, error: Error): void {
    const businessError = error as BusinessError
    console.info(`[MotionHandStateService] ${action} degraded: ${businessError.code || 0} ${businessError.message || ''}`)
  }
}
