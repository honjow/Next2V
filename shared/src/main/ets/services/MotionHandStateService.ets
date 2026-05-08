import { motion } from '@kit.MultimodalAwarenessKit'
import { BusinessError } from '@ohos.base'
import { StorageKeys } from '../constants/StorageKeys'

export type MotionHandEdge = 'left' | 'right' | 'center'

type StableMotionHandEdge = 'left' | 'right'

export class MotionHandStateService {
  private static startAttempted: boolean = false
  private static operatingSubscribed: boolean = false
  private static holdingSubscribed: boolean = false
  private static pendingOperatingEdge: StableMotionHandEdge | null = null
  private static pendingHoldingEdge: StableMotionHandEdge | null = null
  private static debounceTimerId: number = 0
  private static readonly EDGE_DEBOUNCE_MS: number = 450

  private static readonly operatingChanged = (status: motion.OperatingHandStatus): void => {
    MotionHandStateService.handleOperatingStatus(status)
  }

  private static readonly holdingChanged = (status: motion.HoldingHandStatus): void => {
    MotionHandStateService.handleHoldingStatus(status)
  }

  static start(): void {
    MotionHandStateService.ensureDefaultEdge()
    if (MotionHandStateService.startAttempted) {
      return
    }
    MotionHandStateService.startAttempted = true

    try {
      MotionHandStateService.handleOperatingStatus(motion.getRecentOperatingHandStatus())
    } catch (error) {
      MotionHandStateService.logError('get recent operating hand', error)
    }

    try {
      motion.on('operatingHandChanged', MotionHandStateService.operatingChanged)
      MotionHandStateService.operatingSubscribed = true
    } catch (error) {
      MotionHandStateService.logError('subscribe operating hand', error)
    }

    try {
      motion.on('holdingHandChanged', MotionHandStateService.holdingChanged)
      MotionHandStateService.holdingSubscribed = true
    } catch (error) {
      MotionHandStateService.logError('subscribe holding hand', error)
    }
  }

  static stop(): void {
    if (MotionHandStateService.operatingSubscribed) {
      try {
        motion.off('operatingHandChanged', MotionHandStateService.operatingChanged)
      } catch (error) {
        MotionHandStateService.logError('unsubscribe operating hand', error)
      }
      MotionHandStateService.operatingSubscribed = false
    }

    if (MotionHandStateService.holdingSubscribed) {
      try {
        motion.off('holdingHandChanged', MotionHandStateService.holdingChanged)
      } catch (error) {
        MotionHandStateService.logError('unsubscribe holding hand', error)
      }
      MotionHandStateService.holdingSubscribed = false
    }

    MotionHandStateService.cancelPendingEdges()
    MotionHandStateService.startAttempted = false
  }

  private static ensureDefaultEdge(): void {
    const current = AppStorage.get<MotionHandEdge>(StorageKeys.MOTION_HAND_EDGE)
    if (current !== 'left' && current !== 'right' && current !== 'center') {
      MotionHandStateService.setEdge('center')
    }
  }

  private static handleOperatingStatus(status: motion.OperatingHandStatus): void {
    if (status === motion.OperatingHandStatus.LEFT_HAND_OPERATED) {
      MotionHandStateService.scheduleOperatingEdge('left')
      return
    }
    if (status === motion.OperatingHandStatus.RIGHT_HAND_OPERATED) {
      MotionHandStateService.scheduleOperatingEdge('right')
    }
  }

  private static handleHoldingStatus(status: motion.HoldingHandStatus): void {
    if (status === motion.HoldingHandStatus.LEFT_HAND_HELD) {
      MotionHandStateService.scheduleHoldingEdge('left')
      return
    }
    if (status === motion.HoldingHandStatus.RIGHT_HAND_HELD) {
      MotionHandStateService.scheduleHoldingEdge('right')
    }
  }

  private static scheduleOperatingEdge(edge: StableMotionHandEdge): void {
    MotionHandStateService.pendingOperatingEdge = edge
    MotionHandStateService.ensureDebounceTimer()
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
      MotionHandStateService.flushPendingEdges()
    }, MotionHandStateService.EDGE_DEBOUNCE_MS)
  }

  private static flushPendingEdges(): void {
    const operatingEdge = MotionHandStateService.pendingOperatingEdge
    const holdingEdge = MotionHandStateService.pendingHoldingEdge
    MotionHandStateService.debounceTimerId = 0
    MotionHandStateService.pendingOperatingEdge = null
    MotionHandStateService.pendingHoldingEdge = null

    // 操作手只在同一融合窗口内与握持手同时上报时优先；否则单独上报的握持手也能切边。
    const nextEdge = operatingEdge !== null ? operatingEdge : holdingEdge
    if (nextEdge !== null && AppStorage.get<MotionHandEdge>(StorageKeys.MOTION_HAND_EDGE) !== nextEdge) {
      MotionHandStateService.setEdge(nextEdge)
    }
  }

  private static cancelPendingEdges(): void {
    if (MotionHandStateService.debounceTimerId > 0) {
      clearTimeout(MotionHandStateService.debounceTimerId)
      MotionHandStateService.debounceTimerId = 0
    }
    MotionHandStateService.pendingOperatingEdge = null
    MotionHandStateService.pendingHoldingEdge = null
  }

  private static setEdge(edge: MotionHandEdge): void {
    AppStorage.setOrCreate<MotionHandEdge>(StorageKeys.MOTION_HAND_EDGE, edge)
  }

  private static logError(action: string, error: Error): void {
    const businessError = error as BusinessError
    console.info(`[MotionHandStateService] ${action} degraded: ${businessError.code || 0} ${businessError.message || ''}`)
  }
}
