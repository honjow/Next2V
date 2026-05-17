import { ReplyDisplaySettings } from 'shared'

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
}
