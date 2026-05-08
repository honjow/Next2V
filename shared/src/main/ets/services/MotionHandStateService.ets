import { motion } from '@kit.MultimodalAwarenessKit'
import { BusinessError } from '@ohos.base'
import { StorageKeys } from '../constants/StorageKeys'

export type MotionHandEdge = 'left' | 'right' | 'center'

type StableMotionHandEdge = 'left' | 'right'

export class MotionHandStateService {
  private static startAttempted: boolean = false
  private static operatingSubscribed: boolean = false
  private static holdingSubscribed: boolean = false
  private static pendingEdge: StableMotionHandEdge | null = null
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

    MotionHandStateService.cancelPendingEdge()
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
      MotionHandStateService.scheduleEdge('left')
      return
    }
    if (status === motion.OperatingHandStatus.RIGHT_HAND_OPERATED) {
      MotionHandStateService.scheduleEdge('right')
    }
  }

  private static handleHoldingStatus(status: motion.HoldingHandStatus): void {
    if (status === motion.HoldingHandStatus.LEFT_HAND_HELD) {
      MotionHandStateService.scheduleEdge('left')
      return
    }
    if (status === motion.HoldingHandStatus.RIGHT_HAND_HELD) {
      MotionHandStateService.scheduleEdge('right')
    }
  }

  private static scheduleEdge(edge: StableMotionHandEdge): void {
    if (AppStorage.get<MotionHandEdge>(StorageKeys.MOTION_HAND_EDGE) === edge) {
      MotionHandStateService.cancelPendingEdge()
      return
    }
    MotionHandStateService.pendingEdge = edge
    if (MotionHandStateService.debounceTimerId > 0) {
      clearTimeout(MotionHandStateService.debounceTimerId)
    }
    MotionHandStateService.debounceTimerId = setTimeout(() => {
      const nextEdge = MotionHandStateService.pendingEdge
      MotionHandStateService.debounceTimerId = 0
      MotionHandStateService.pendingEdge = null
      if (nextEdge !== null && AppStorage.get<MotionHandEdge>(StorageKeys.MOTION_HAND_EDGE) !== nextEdge) {
        MotionHandStateService.setEdge(nextEdge)
      }
    }, MotionHandStateService.EDGE_DEBOUNCE_MS)
  }

  private static cancelPendingEdge(): void {
    if (MotionHandStateService.debounceTimerId > 0) {
      clearTimeout(MotionHandStateService.debounceTimerId)
      MotionHandStateService.debounceTimerId = 0
    }
    MotionHandStateService.pendingEdge = null
  }

  private static setEdge(edge: MotionHandEdge): void {
    AppStorage.setOrCreate<MotionHandEdge>(StorageKeys.MOTION_HAND_EDGE, edge)
  }

  private static logError(action: string, error: Error): void {
    const businessError = error as BusinessError
    console.info(`[MotionHandStateService] ${action} degraded: ${businessError.code || 0} ${businessError.message || ''}`)
  }
}
