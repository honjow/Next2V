import { AppStrings, ReplyFingerprint, V2exReply } from 'shared'
export interface JumpFloorResult {
  valid: boolean
  floor: number
  message: string
}

export class TopicDetailScrollCoordinator {
  // The reply list is: index 0 = TopicCard, index 1 = ReplyDivider, index 2+i = replyDataSource[i].
  private static readonly REPLY_LIST_OFFSET: number = 2

  static lastReplyListIndex(replyCount: number): number {
    if (replyCount <= 0) {
      return 0
    }
    return TopicDetailScrollCoordinator.REPLY_LIST_OFFSET + replyCount
  }

  static parseJumpFloor(value: string, maxFloor: number): JumpFloorResult {
    const raw = (value || '').trim()
    const floor = parseInt(raw, 10)
    if (!raw || isNaN(floor) || floor <= 0) {
      return {
        valid: false,
        floor: 0,
        message: AppStrings.text(
          $r('app.string.common_invalid_floor'),
          'Enter a valid floor number',
        ),
      }
    }
    return {
      valid: true,
      floor: TopicDetailScrollCoordinator.clampFloor(floor, maxFloor),
      message: '',
    }
  }

  // The displayed-row index whose reply IS this list (center) index — used to remember the read floor.
  static replyIndexFromCenterListIndex(centerIndex: number): number {
    return centerIndex - TopicDetailScrollCoordinator.REPLY_LIST_OFFSET
  }

  // Floor -> list index, resolved against the ACTUAL displayed data (which may be reordered/threaded), so
  // a nested reply jumps to the row that actually contains it (its top-level ancestor) rather than to a
  // chronological 2+floor guess that, under 楼中楼 reordering, lands near the end. Returns -1 when the
  // floor is not present in the loaded/visible data, so the caller can fall back (e.g. scroll to the end).
  static listIndexForFloor(
    floor: number,
    count: number,
    getData: (index: number) => V2exReply,
  ): number {
    const dataIndex = TopicDetailScrollCoordinator.dataIndexForFloor(floor, count, getData)
    if (dataIndex < 0) {
      return -1
    }
    return TopicDetailScrollCoordinator.REPLY_LIST_OFFSET + dataIndex
  }

  // Index of the displayed row whose subtree (the row reply + its nested threadChildren, recursively)
  // contains `floor`. First match wins, so a 楼中楼-redundant duplicate tail clone never shadows the
  // reply's real threaded position. Returns -1 when no displayed row covers the floor.
  static dataIndexForFloor(
    floor: number,
    count: number,
    getData: (index: number) => V2exReply,
  ): number {
    if (floor <= 0 || count <= 0) {
      return -1
    }
    for (let i = 0; i < count; i++) {
      let row: V2exReply | null = null
      try {
        row = getData(i)
      } catch (_e) {
        row = null
      }
      if (row && TopicDetailScrollCoordinator.subtreeContainsFloor(row, floor)) {
        return i
      }
    }
    return -1
  }

  private static subtreeContainsFloor(reply: V2exReply, floor: number): boolean {
    if ((reply.floor || 0) === floor) {
      return true
    }
    const children = reply.threadChildren || []
    for (let i = 0; i < children.length; i++) {
      if (TopicDetailScrollCoordinator.subtreeContainsFloor(children[i], floor)) {
        return true
      }
    }
    return false
  }

  // Verify V2EX's notification anchor (targetFloor) against the reply text it claims to point
  // at, and re-locate by content when they disagree. V2EX occasionally stamps a thanks/mention
  // notification with the wrong #reply{N} floor (two notifications for the SAME reply can carry
  // different anchors), so trusting the anchor blindly scrolls to an unrelated floor.
  //
  // Conservative by design: when the reply sitting at targetFloor already matches the text, the
  // anchor is honored untouched (zero change for the common, correct case). Only a mismatch — or
  // a targetFloor that isn't present in the loaded replies — triggers a content search, and a
  // failed search falls back to the original targetFloor (never worse than today's behavior).
  // `replies` is the flat, chronological loaded list (every reply carries its own floor).
  static verifiedFloor(targetFloor: number, verifyReplyText: string, replies: V2exReply[]): number {
    const verify = (verifyReplyText || '').trim()
    if (!verify || !replies || replies.length === 0) {
      return targetFloor
    }
    if (targetFloor > 0) {
      for (let i = 0; i < replies.length; i++) {
        const row = replies[i]
        if (row && (row.floor || 0) === targetFloor) {
          // Anchor lands on a real, loaded floor: trust it iff the text agrees.
          if (ReplyFingerprint.matches(row.content || row.content_rendered || '', verify)) {
            return targetFloor
          }
          break
        }
      }
    }
    for (let i = 0; i < replies.length; i++) {
      const row = replies[i]
      if (row && ReplyFingerprint.matches(row.content || row.content_rendered || '', verify)) {
        const floor = row.floor || 0
        if (floor > 0) {
          return floor
        }
      }
    }
    return targetFloor
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
