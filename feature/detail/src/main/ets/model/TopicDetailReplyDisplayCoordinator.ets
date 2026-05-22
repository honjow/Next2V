import {
  ReplyDisplaySettings,
  V2exReply,
  V2exTopic,
} from 'shared'

export interface ReplyDisplayModeOption {
  label: string
  mode: string
}

export interface TopicDetailReplyCardDisplayState {
  floor: number
  isOp: boolean
  threadLevel: number
  displayContent: string
  childReplies: V2exReply[]
  opMemberId: number
  hideLeadingMention: boolean
  isWrongReference: boolean
  isDuplicateThreadItem: boolean
}

export class TopicDetailReplyDisplayCoordinator {
  static modeOptions(): ReplyDisplayModeOption[] {
    return [
      { label: ReplyDisplaySettings.modeText(ReplyDisplaySettings.MODE_THREAD), mode: ReplyDisplaySettings.MODE_THREAD },
      { label: ReplyDisplaySettings.modeText(ReplyDisplaySettings.MODE_THREAD_WITH_MENTION), mode: ReplyDisplaySettings.MODE_THREAD_WITH_MENTION },
      { label: ReplyDisplaySettings.modeText(ReplyDisplaySettings.MODE_THREAD_REDUNDANT), mode: ReplyDisplaySettings.MODE_THREAD_REDUNDANT },
      { label: ReplyDisplaySettings.modeText(ReplyDisplaySettings.MODE_OP), mode: ReplyDisplaySettings.MODE_OP },
      { label: ReplyDisplaySettings.modeText(ReplyDisplaySettings.MODE_ORIGIN), mode: ReplyDisplaySettings.MODE_ORIGIN },
    ]
  }

  static replyCountText(total: number, loaded: number): string {
    if (total > 0 && loaded < total) {
      return `已加载 ${loaded} / ${total}`
    }
    if (total > 0) {
      return `共 ${total} 条回复`
    }
    return `共 ${loaded} 条回复`
  }

  static modeText(mode: string): string {
    return ReplyDisplaySettings.modeText(mode)
  }

  static isThreadMode(mode: string): boolean {
    return mode === ReplyDisplaySettings.MODE_THREAD ||
      mode === ReplyDisplaySettings.MODE_THREAD_WITH_MENTION ||
      mode === ReplyDisplaySettings.MODE_THREAD_REDUNDANT
  }

  static shouldPreloadForMode(
    mode: string,
    allRepliesLoaded: boolean,
    repliesHasMore: boolean,
  ): boolean {
    return TopicDetailReplyDisplayCoordinator.isThreadMode(mode) &&
      !allRepliesLoaded &&
      repliesHasMore
  }

  static replyCardDisplayState(
    reply: V2exReply,
    topic: V2exTopic | null,
    resolvedFloor: number,
    fallbackIndex: number,
    mode: string,
  ): TopicDetailReplyCardDisplayState {
    const floor = TopicDetailReplyDisplayCoordinator.floorForReply(resolvedFloor, fallbackIndex)
    const opMemberId = topic !== null ? topic.member.id : 0
    return {
      floor: floor,
      isOp: topic !== null && reply.member.id === topic.member.id,
      threadLevel: reply.threadLevel || 0,
      displayContent: TopicDetailReplyDisplayCoordinator.displayContent(reply, mode),
      childReplies: reply.threadChildren || [],
      opMemberId: opMemberId,
      hideLeadingMention: mode === ReplyDisplaySettings.MODE_THREAD,
      isWrongReference: !!reply.isWrongReference,
      isDuplicateThreadItem: !!reply.isDuplicateThreadItem,
    }
  }

  static displayContent(reply: V2exReply, mode: string): string {
    if (
      mode === ReplyDisplaySettings.MODE_THREAD &&
      (reply.hiddenLeadingMentionContent || '').trim() &&
      (reply.threadLevel || 0) > 0 &&
      (reply.replyUsers || []).length === 1
    ) {
      if ((reply.hiddenLeadingMentionRenderedContent || '').trim()) {
        return reply.hiddenLeadingMentionRenderedContent || ''
      }
      return reply.hiddenLeadingMentionContent || ''
    }
    return ''
  }

  static floorForReply(resolvedFloor: number, fallbackIndex: number): number {
    return resolvedFloor > 0 ? resolvedFloor : fallbackIndex + 1
  }

  static mentionText(username: string, floor: number = 0): string {
    const clean = (username || '').trim()
    if (!clean) {
      return ''
    }
    const cleanFloor = Math.floor(floor)
    return cleanFloor > 0 ? `@${clean} #${cleanFloor} ` : `@${clean} `
  }
}
