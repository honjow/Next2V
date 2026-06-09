import {
  ApiService,
  AppStrings,
  V2exReply,
} from 'shared'
import type {
  V2exReplyThankAction,
  V2exTopicThankAction,
  V2exToggleAction,
} from 'shared'

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

export interface ModerationPreflight {
  cookie: string
  guard: ActionGuardResult
}

export interface ModerationConfirmDialog {
  title: string
  message: string
  cancelLabel: string
  confirmLabel: string
}

export interface ReplyThankLockState {
  lockedReplyId: number
  pendingReplyThankId: number
}

export interface ReplyThankedIdsSnapshot {
  replyId: number
  previousJson: string
  nextJson: string
  addedReplyId: boolean
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

  static markReplyThankedWithSnapshot(
    replyId: number,
    thankedReplyIdsJson: string,
  ): ReplyThankedIdsSnapshot {
    const ids = TopicDetailActionCoordinator.readThankedReplyIds(thankedReplyIdsJson)
    const addedReplyId = replyId > 0 && ids.indexOf(replyId) < 0
    const nextJson = TopicDetailActionCoordinator.markReplyThanked(replyId, thankedReplyIdsJson)
    return {
      replyId,
      previousJson: thankedReplyIdsJson,
      nextJson,
      addedReplyId,
    }
  }

  static unmarkReplyThanked(replyId: number, thankedReplyIdsJson: string): string {
    if (replyId <= 0) {
      return thankedReplyIdsJson
    }
    const ids = TopicDetailActionCoordinator.readThankedReplyIds(thankedReplyIdsJson)
      .filter((id: number) => id !== replyId)
    return JSON.stringify(ids)
  }

  static rollbackReplyThankedIds(
    snapshot: ReplyThankedIdsSnapshot | null,
    currentJson: string = '',
  ): string {
    if (!snapshot) {
      return currentJson
    }
    if (!snapshot.addedReplyId) {
      return snapshot.nextJson
    }
    const removedJson =
      TopicDetailActionCoordinator.unmarkReplyThanked(snapshot.replyId, snapshot.nextJson)
    return removedJson === snapshot.previousJson ? removedJson : snapshot.previousJson
  }

  static topicFavoriteMessage(title: string, verb: string): string {
    const cleanTitle = (title || '').trim()
    return cleanTitle ? AppStrings.format(AppStrings.text($r('app.string.confirm_topic_favorite_format'), '{0}《{1}》?'), [verb, cleanTitle]) : AppStrings.format(AppStrings.text($r('app.string.confirm_topic_favorite_nameless_format'), '{0} this topic?'), [verb])
  }

  static topicThankMessage(title: string): string {
    const cleanTitle = (title || '').trim()
    return cleanTitle ? AppStrings.format(AppStrings.text($r('app.string.confirm_topic_thank_format'), 'Thank《{0}》?'), [cleanTitle]) : AppStrings.text($r('app.string.confirm_topic_thank_nameless'), 'Thank this topic?')
  }

  static replyThankMessage(username: string): string {
    return AppStrings.format(AppStrings.text($r('app.string.confirm_reply_thank_format'), 'Thank reply by {0}?\n\nThis costs 10 copper coins.'), [username || AppStrings.text($r('app.string.this_user'), 'this user')])
  }

  static replyActionMessage(verb: string, username: string): string {
    return AppStrings.format(AppStrings.text($r('app.string.confirm_reply_action_format'), 'Confirm {0} reply by {1}?'), [verb, username || AppStrings.text($r('app.string.this_user'), 'this user')])
  }

  static parseActionFailureMessage(verb: string): string {
    return AppStrings.format(AppStrings.text($r('app.string.parse_action_failed_format'), 'Failed to parse {0} action'), [verb])
  }

  static topicThankGuard(options: TopicThankGuardOptions): ActionGuardResult {
    if (options.locked || options.loading) {
      return { allowed: false, message: '' }
    }
    if (options.thanked || options.storageThanked) {
      return { allowed: false, message: AppStrings.text($r('app.string.already_thanked'), 'Already thanked') }
    }
    if (!options.cookie) {
      return { allowed: false, message: AppStrings.text($r('app.string.api_error_auth_required'), 'Login required') }
    }
    return { allowed: true, message: '' }
  }

  static replyThankGuard(options: ReplyThankGuardOptions): ActionGuardResult {
    if (options.loading || options.lockedReplyId > 0) {
      return { allowed: false, message: '' }
    }
    if (!TopicDetailActionCoordinator.hasValidReply(options.reply)) {
      return { allowed: false, message: AppStrings.text($r('app.string.reply_info_missing'), 'Reply info missing') }
    }
    if (options.thanked) {
      return { allowed: false, message: AppStrings.text($r('app.string.already_thanked'), 'Already thanked') }
    }
    if (!options.cookie) {
      return { allowed: false, message: AppStrings.text($r('app.string.api_error_auth_required'), 'Login required') }
    }
    return { allowed: true, message: '' }
  }

  static moderationGuard(options: ModerationGuardOptions): ActionGuardResult {
    if (options.loading) {
      return { allowed: false, message: '' }
    }
    if (!options.cookie) {
      return { allowed: false, message: AppStrings.text($r('app.string.api_error_auth_required'), 'Login required') }
    }
    if (options.reply !== undefined && !TopicDetailActionCoordinator.hasValidReply(options.reply)) {
      return { allowed: false, message: AppStrings.text($r('app.string.reply_info_missing'), 'Reply info missing') }
    }
    return { allowed: true, message: '' }
  }

  static moderationPreflight(options: ModerationGuardOptions): ModerationPreflight {
    return {
      cookie: options.cookie,
      guard: TopicDetailActionCoordinator.moderationGuard(options),
    }
  }

  static topicModerationConfirmDialog(title: string, verb: string, topicTitle: string): ModerationConfirmDialog {
    return {
      title,
      message: TopicDetailActionCoordinator.topicFavoriteMessage(topicTitle, verb),
      cancelLabel: AppStrings.text($r('app.string.common_cancel'), 'Cancel'),
      confirmLabel: verb,
    }
  }

  static replyModerationConfirmDialog(title: string, verb: string, reply: V2exReply): ModerationConfirmDialog {
    return {
      title,
      message: TopicDetailActionCoordinator.replyActionMessage(verb, reply.member.username),
      cancelLabel: AppStrings.text($r('app.string.common_cancel'), 'Cancel'),
      confirmLabel: verb,
    }
  }

  static thankedFromTopicThankLoadError(error: Error): boolean {
    const message = error.message || ''
    return message.indexOf(AppStrings.text($r('app.string.already_thanked'), 'Already thanked')) >= 0
  }

  static replyThankLockState(reply: V2exReply): ReplyThankLockState {
    return {
      lockedReplyId: reply.id,
      pendingReplyThankId: reply.id,
    }
  }

  static clearReplyThankLockState(): ReplyThankLockState {
    return {
      lockedReplyId: 0,
      pendingReplyThankId: 0,
    }
  }

  static executeReplyThank(
    api: ApiService,
    cookie: string,
    topicId: number,
    replyId: number,
  ): Promise<void> {
    return api
      .getReplyThankActionWithCookie(cookie, topicId, replyId)
      .then((action: V2exReplyThankAction) =>
        api.executeReplyThankWithCookie(cookie, topicId, action),
      )
  }

  static executeTopicThank(api: ApiService, cookie: string, topicId: number): Promise<void> {
    return api
      .getTopicThankActionWithCookie(cookie, topicId)
      .then((action: V2exTopicThankAction) => api.executeTopicThankWithCookie(cookie, action))
  }

  static executeSiteFavoriteToggle(
    api: ApiService,
    cookie: string,
    topicId: number,
    toggle: V2exToggleAction,
  ): Promise<boolean> {
    return api.executeTopicFavoriteToggleWithCookie(cookie, topicId, toggle)
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
