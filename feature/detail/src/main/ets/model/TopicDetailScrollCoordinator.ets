export interface JumpFloorResult {
  valid: boolean
  floor: number
  message: string
}

export class TopicDetailScrollCoordinator {
  static lastReplyListIndex(replyCount: number): number {
    if (replyCount <= 0) {
      return 0
    }
    return 2 + replyCount
  }

  static parseJumpFloor(value: string, maxFloor: number): JumpFloorResult {
    const raw = (value || '').trim()
    const floor = parseInt(raw, 10)
    if (!raw || isNaN(floor) || floor <= 0) {
      return {
        valid: false,
        floor: 0,
        message: '请输入有效楼层号',
      }
    }
    return {
      valid: true,
      floor: TopicDetailScrollCoordinator.clampFloor(floor, maxFloor),
      message: '',
    }
  }

  static replyIndexFromCenterListIndex(centerIndex: number): number {
    return centerIndex - 3
  }

  static loadedFloor(requestedFloor: number, loadedCount: number): number {
    if (loadedCount <= 0) {
      return 0
    }
    return requestedFloor <= loadedCount ? requestedFloor : loadedCount
  }

  static listIndexForFloor(floor: number): number {
    return 2 + floor
  }

  static async ensureRepliesLoaded(
    targetFloor: number,
    repliesUseV2: boolean,
    totalCount: () => number,
    hasMore: () => boolean,
    loadMore: () => Promise<void>,
  ): Promise<void> {
    if (targetFloor <= 0 || !repliesUseV2) {
      return
    }
    let guard = 0
    while (totalCount() < targetFloor && hasMore() && guard < 20) {
      guard++
      await loadMore()
    }
  }

  private static clampFloor(floor: number, maxFloor: number): number {
    if (maxFloor > 0 && floor > maxFloor) {
      return maxFloor
    }
    return floor
  }
}
