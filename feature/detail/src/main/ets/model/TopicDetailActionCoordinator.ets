import { V2exReply } from 'shared'

export interface ParsedTopicDetailAction {
  topicId: number
  action: string
}

export class TopicDetailActionCoordinator {
  static parseCommand(rawCommand: string): ParsedTopicDetailAction | null {
    const raw = (rawCommand || '').trim()
    if (!raw) {
      return null
    }
    // Payload format: `${ts}:${topicId}:${action}`.
    const parts = raw.split(':')
    if (parts.length < 3) {
      return null
    }
    const topicId = Number(parts[1])
    if (!Number.isFinite(topicId) || topicId <= 0) {
      return null
    }
    return {
      topicId,
      action: parts.slice(2).join(':'),
    }
  }

  static isReplyThanked(replyId: number, replies: V2exReply[], thankedReplyIdsJson: string): boolean {
    if (replyId <= 0) {
      return false
    }
    for (let i = 0; i < replies.length; i++) {
      if (replies[i] && replies[i].id === replyId && replies[i].thanked) {
        return true
      }
    }
    return TopicDetailActionCoordinator.readThankedReplyIds(thankedReplyIdsJson).indexOf(replyId) >= 0
  }

  static markReplyThanked(replyId: number, thankedReplyIdsJson: string): string {
    if (replyId <= 0) {
      return thankedReplyIdsJson
    }
    const ids = TopicDetailActionCoordinator.readThankedReplyIds(thankedReplyIdsJson)
    if (ids.indexOf(replyId) < 0) {
      ids.push(replyId)
    }
    return JSON.stringify(ids)
  }

  static topicFavoriteMessage(title: string, verb: string): string {
    const cleanTitle = (title || '').trim()
    return cleanTitle ? `确定${verb}《${cleanTitle}》吗？` : `确定${verb}该主题吗？`
  }

  static topicThankMessage(title: string): string {
    const cleanTitle = (title || '').trim()
    return cleanTitle ? `确定感谢《${cleanTitle}》吗？` : '确定感谢该主题吗？'
  }

  static replyActionMessage(verb: string, username: string): string {
    return `确定${verb} ${username || '该用户'} 的回复吗？`
  }

  static parseActionFailureMessage(verb: string): string {
    return `解析${verb}操作失败`
  }

  private static readThankedReplyIds(thankedReplyIdsJson: string): number[] {
    try {
      const parsed = JSON.parse(thankedReplyIdsJson || '[]') as number[]
      return Array.isArray(parsed) ? parsed : []
    } catch (_error) {
      return []
    }
  }
}
