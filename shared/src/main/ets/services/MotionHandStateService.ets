import { motion } from '@kit.MultimodalAwarenessKit'
import { BusinessError } from '@ohos.base'
import { StorageKeys } from '../constants/StorageKeys'

export type MotionHandEdge = 'left' | 'right' | 'center'

export class MotionHandStateService {
  private static startAttempted: boolean = false
  private static operatingSubscribed: boolean = false
  private static holdingSubscribed: boolean = false
  private static operatingStatus: motion.OperatingHandStatus = motion.OperatingHandStatus.UNKNOWN_STATUS
  private static holdingStatus: motion.HoldingHandStatus = motion.HoldingHandStatus.UNKNOWN_STATUS

  private static readonly operatingChanged = (status: motion.OperatingHandStatus): void => {
    MotionHandStateService.operatingStatus = status
    MotionHandStateService.publishEdge()
  }

  private static readonly holdingChanged = (status: motion.HoldingHandStatus): void => {
    MotionHandStateService.holdingStatus = status
    MotionHandStateService.publishEdge()
  }

  static start(): void {
    MotionHandStateService.ensureDefaultEdge()
    if (MotionHandStateService.startAttempted) {
      return
    }
    MotionHandStateService.startAttempted = true

    try {
      MotionHandStateService.operatingStatus = motion.getRecentOperatingHandStatus()
      MotionHandStateService.publishEdge()
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

    if (!MotionHandStateService.operatingSubscribed && !MotionHandStateService.holdingSubscribed) {
      MotionHandStateService.setEdge('center')
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

    MotionHandStateService.startAttempted = false
  }

  private static ensureDefaultEdge(): void {
    const current = AppStorage.get<MotionHandEdge>(StorageKeys.MOTION_HAND_EDGE)
    if (current !== 'left' && current !== 'right' && current !== 'center') {
      MotionHandStateService.setEdge('center')
    }
  }

  private static publishEdge(): void {
    const operatingEdge = MotionHandStateService.edgeFromOperating(MotionHandStateService.operatingStatus)
    if (operatingEdge !== 'center') {
      MotionHandStateService.setEdge(operatingEdge)
      return
    }
    MotionHandStateService.setEdge(MotionHandStateService.edgeFromHolding(MotionHandStateService.holdingStatus))
  }

  private static edgeFromOperating(status: motion.OperatingHandStatus): MotionHandEdge {
    if (status === motion.OperatingHandStatus.LEFT_HAND_OPERATED) {
      return 'left'
    }
    if (status === motion.OperatingHandStatus.RIGHT_HAND_OPERATED) {
      return 'right'
    }
    return 'center'
  }

  private static edgeFromHolding(status: motion.HoldingHandStatus): MotionHandEdge {
    if (status === motion.HoldingHandStatus.LEFT_HAND_HELD) {
      return 'left'
    }
    if (status === motion.HoldingHandStatus.RIGHT_HAND_HELD) {
      return 'right'
    }
    return 'center'
  }

  private static setEdge(edge: MotionHandEdge): void {
    AppStorage.setOrCreate<MotionHandEdge>(StorageKeys.MOTION_HAND_EDGE, edge)
  }

  private static logError(action: string, error: Error): void {
    const businessError = error as BusinessError
    console.info(`[MotionHandStateService] ${action} degraded: ${businessError.code || 0} ${businessError.message || ''}`)
  }
}
