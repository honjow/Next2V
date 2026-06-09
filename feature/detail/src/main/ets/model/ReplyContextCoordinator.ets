import {
  AppStrings,
  HtmlEntityUtils,
  V2exReply,
} from 'shared'

export interface ReplyContextItem {
  reply: V2exReply
  floor: number
  label: string
  selected: boolean
}

export interface ReplyContextBuildInput {
  selected: V2exReply
  selectedFloor: number
  replies: V2exReply[]
  getReplyFloor: (replyId: number) => number
}

export class ReplyContextCoordinator {
  static title(reply: V2exReply | null, getReplyFloor: (replyId: number) => number): string {
    if (reply === null) {
      return AppStrings.text($r('app.string.reply_context_title'), 'Reply context')
    }
    const floor = getReplyFloor(reply.id)
    return floor > 0 ? AppStrings.format(AppStrings.text($r('app.string.reply_context_with_floor_format'), '#{0} Reply context'), [`${floor}`]) : AppStrings.text($r('app.string.reply_context_title'), 'Reply context')
  }

  static snippet(content: string): string {
    const text = (content || '')
      .replace(/\r/g, '\n')
      .replace(/\n+/g, ' ')
      .replace(/\s+/g, ' ')
      .trim()
    return text || AppStrings.text($r('app.string.reply_context_empty_snippet'), '(No content)')
  }

  static build(input: ReplyContextBuildInput): ReplyContextItem[] {
    const items: ReplyContextItem[] = []
    const seen = new Set<number>()
    const addReply = (
      reply: V2exReply | null,
      label: string,
      selectedItem: boolean,
    ): void => {
      if (reply === null || reply.id <= 0 || seen.has(reply.id)) {
        return
      }
      const floor = input.getReplyFloor(reply.id)
      if (floor <= 0) {
        return
      }
      seen.add(reply.id)
      items.push({ reply: reply, floor: floor, label: label, selected: selectedItem })
    }

    ReplyContextCoordinator.addContextReplyByFloor(input.replies, input.selectedFloor - 2, AppStrings.text($r('app.string.reply_context_label_above'), 'Above'), addReply)
    ReplyContextCoordinator.addContextReplyByFloor(input.replies, input.selectedFloor - 1, AppStrings.text($r('app.string.reply_context_label_above'), 'Above'), addReply)
    ReplyContextCoordinator.addMentionTargetsBeforeSelection(
      input.replies,
      input.selectedFloor,
      input.selected.content,
      input.selected.content_rendered,
      addReply,
    )
    addReply(input.selected, AppStrings.text($r('app.string.reply_context_label_current'), 'Current reply'), true)
    ReplyContextCoordinator.addRepliesMentioningSelectedAuthor(
      input.replies,
      input.selectedFloor,
      input.selected.member.username,
      addReply,
    )
    ReplyContextCoordinator.addContextReplyByFloor(input.replies, input.selectedFloor + 1, AppStrings.text($r('app.string.reply_context_label_below'), 'Below'), addReply)
    ReplyContextCoordinator.addContextReplyByFloor(input.replies, input.selectedFloor + 2, AppStrings.text($r('app.string.reply_context_label_below'), 'Below'), addReply)

    return items.sort((left: ReplyContextItem, right: ReplyContextItem) => left.floor - right.floor)
  }

  private static addContextReplyByFloor(
    replies: V2exReply[],
    floor: number,
    label: string,
    addReply: (reply: V2exReply | null, label: string, selectedItem: boolean) => void,
  ): void {
    if (floor <= 0 || floor > replies.length) {
      return
    }
    addReply(replies[floor - 1], label, false)
  }

  private static addMentionTargetsBeforeSelection(
    replies: V2exReply[],
    selectedFloor: number,
    content: string,
    renderedContent: string,
    addReply: (reply: V2exReply | null, label: string, selectedItem: boolean) => void,
  ): void {
    const names = ReplyContextCoordinator.extractMentionedUsernames(content, renderedContent)
    names.forEach((name: string) => {
      const target = ReplyContextCoordinator.findPreviousReplyByUsername(replies, selectedFloor, name)
      addReply(target, `@${name}`, false)
    })
  }

  private static addRepliesMentioningSelectedAuthor(
    replies: V2exReply[],
    selectedFloor: number,
    username: string,
    addReply: (reply: V2exReply | null, label: string, selectedItem: boolean) => void,
  ): void {
    const clean = (username || '').trim()
    if (!clean) {
      return
    }
    let added = 0
    for (let i = selectedFloor; i < replies.length && added < 2; i++) {
      const reply = replies[i]
      if (
        reply &&
        ReplyContextCoordinator.contentMentionsUsername(reply.content, reply.content_rendered, clean)
      ) {
        addReply(reply, AppStrings.format(AppStrings.text($r('app.string.reply_context_label_mention_format'), 'Mentioned @{0}'), [clean]), false)
        added++
      }
    }
  }

  private static findPreviousReplyByUsername(
    replies: V2exReply[],
    selectedFloor: number,
    username: string,
  ): V2exReply | null {
    const clean = (username || '').trim().toLowerCase()
    if (!clean) {
      return null
    }
    for (let i = selectedFloor - 2; i >= 0; i--) {
      const reply = replies[i]
      if (reply && (reply.member.username || '').trim().toLowerCase() === clean) {
        return reply
      }
    }
    return null
  }

  private static contentMentionsUsername(
    content: string,
    renderedContent: string,
    username: string,
  ): boolean {
    const clean = (username || '').trim().toLowerCase()
    if (!clean) {
      return false
    }
    return ReplyContextCoordinator.extractMentionedUsernames(content, renderedContent).some(
      (name: string) => name.toLowerCase() === clean,
    )
  }

  private static extractMentionedUsernames(content: string, renderedContent: string = ''): string[] {
    const names: string[] = []
    const seen = new Set<string>()
    const addName = (name: string): void => {
      const clean = (name || '').trim()
      const key = clean.toLowerCase()
      if (clean && !seen.has(key)) {
        seen.add(key)
        names.push(clean)
      }
    }

    const rendered = renderedContent || ''
    const linkRe =
      /@\s*<a\b[^>]*href=["'](?:https?:\/\/(?:www\.)?v2ex\.(?:com|co))?\/member\/([^"'?#\/]+)[^"']*["'][^>]*>/gi
    let linkMatch: RegExpExecArray | null = linkRe.exec(rendered)
    while (linkMatch) {
      addName(HtmlEntityUtils.decode(linkMatch[1] || ''))
      linkMatch = linkRe.exec(rendered)
    }
    if (names.length > 0) {
      return names
    }

    const raw = content || ''
    const re = /@([0-9A-Za-z_]{2,32})/g
    let match: RegExpExecArray | null = re.exec(raw)
    while (match) {
      if (ReplyContextCoordinator.isValidMentionMatch(raw, match.index, match[0])) {
        addName(match[1] || '')
      }
      match = re.exec(raw)
    }
    return names
  }

  private static isValidMentionMatch(raw: string, atIndex: number, matchText: string): boolean {
    const before = atIndex > 0 ? raw.charAt(atIndex - 1) : ''
    const afterIndex = atIndex + matchText.length
    const after = afterIndex < raw.length ? raw.charAt(afterIndex) : ''
    return ReplyContextCoordinator.isMentionBoundaryChar(before) &&
      ReplyContextCoordinator.isMentionBoundaryChar(after)
  }

  private static isMentionBoundaryChar(ch: string): boolean {
    if (!ch) {
      return true
    }
    return !ReplyContextCoordinator.isMentionNameChar(ch) && ch !== '-' && ch !== '.'
  }

  private static isMentionNameChar(ch: string): boolean {
    return (
      (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') || (ch >= '0' && ch <= '9') || ch === '_'
    )
  }
}
