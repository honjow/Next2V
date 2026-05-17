import { V2exReply } from 'shared'

export interface ParsedTopicDetailAction {
  topicId: number
  action: string
}

export interface TopicThankGuardOptions {
  locked: boolean
  loading: boolean
  thanked: boolean
  storageThanked: boolean
  cookie: string
}

export interface ReplyThankGuardOptions {
  loading: boolean
  lockedReplyId: number
  reply: V2exReply | null
  thanked: boolean
  cookie: string
}

export interface ModerationGuardOptions {
  loading: boolean
  cookie: string
  reply?: V2exReply | null
}

export interface ActionGuardResult {
  allowed: boolean
  message: string
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

  static isReplyThankedForGuard(
    reply: V2exReply | null,
    replies: V2exReply[],
    thankedReplyIdsJson: string,
  ): boolean {
    if (!TopicDetailActionCoordinator.hasValidReply(reply)) {
      return false
    }
    const safeReply = reply as V2exReply
    return TopicDetailActionCoordinator.isReplyThanked(safeReply.id, replies, thankedReplyIdsJson)
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

  static topicThankGuard(options: TopicThankGuardOptions): ActionGuardResult {
    if (options.locked || options.loading) {
      return { allowed: false, message: '' }
    }
    if (options.thanked || options.storageThanked) {
      return { allowed: false, message: '已经感谢过' }
    }
    if (!options.cookie) {
      return { allowed: false, message: '请先登录' }
    }
    return { allowed: true, message: '' }
  }

  static replyThankGuard(options: ReplyThankGuardOptions): ActionGuardResult {
    if (options.loading || options.lockedReplyId > 0) {
      return { allowed: false, message: '' }
    }
    if (!TopicDetailActionCoordinator.hasValidReply(options.reply)) {
      return { allowed: false, message: '回复信息缺失' }
    }
    if (options.thanked) {
      return { allowed: false, message: '已经感谢过' }
    }
    if (!options.cookie) {
      return { allowed: false, message: '请先登录' }
    }
    return { allowed: true, message: '' }
  }

  static moderationGuard(options: ModerationGuardOptions): ActionGuardResult {
    if (options.loading) {
      return { allowed: false, message: '' }
    }
    if (!options.cookie) {
      return { allowed: false, message: '请先登录' }
    }
    if (options.reply !== undefined && !TopicDetailActionCoordinator.hasValidReply(options.reply)) {
      return { allowed: false, message: '回复信息缺失' }
    }
    return { allowed: true, message: '' }
  }

  static thankedFromTopicThankLoadError(error: Error): boolean {
    const message = error.message || ''
    return message.indexOf('已经感谢过') >= 0
  }

  private static hasValidReply(reply: V2exReply | null): boolean {
    return !!reply && reply.id > 0
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
