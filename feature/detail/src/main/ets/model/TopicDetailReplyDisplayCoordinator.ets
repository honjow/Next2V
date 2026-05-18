import {
  ReplyDisplaySettings,
  V2exReply,
} from 'shared'

export interface ReplyDisplayModeOption {
  label: string
  mode: string
}

export class TopicDetailReplyDisplayCoordinator {
  static modeOptions(): ReplyDisplayModeOption[] {
    return [
      { label: '楼中楼', mode: ReplyDisplaySettings.MODE_THREAD },
      { label: '楼中楼(@)', mode: ReplyDisplaySettings.MODE_THREAD_WITH_MENTION },
      { label: '冗余楼中楼', mode: ReplyDisplaySettings.MODE_THREAD_REDUNDANT },
      { label: '只看楼主', mode: ReplyDisplaySettings.MODE_OP },
      { label: '原版', mode: ReplyDisplaySettings.MODE_ORIGIN },
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
