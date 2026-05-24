import { AppStrings, HtmlEntityUtils, ReplyDisplaySettings, V2exReply, V2exTopic } from 'shared'

export interface ReplyThreadDisplayOptions {
  displayMode: string
  onlyOp: boolean
  preloadFallbackToFlat: boolean
  topic: V2exTopic | null
  replies: V2exReply[]
}

export class ReplyThreadCoordinator {
  static replyStateKey(reply: V2exReply): string {
    return `thanks-${reply.thanks || 0}-${reply.thanked ? 'me' : 'other'}`
  }

  static visibleReplies(options: ReplyThreadDisplayOptions): V2exReply[] {
    if (options.displayMode === ReplyDisplaySettings.MODE_OP || options.onlyOp) {
      const opId = options.topic ? options.topic.member.id : 0
      if (opId <= 0) {
        return ReplyThreadCoordinator.prepareRepliesForThreading(options.replies, options.displayMode)
      }
      return ReplyThreadCoordinator.prepareRepliesForThreading(options.replies, options.displayMode)
        .filter((reply) => reply.member.id === opId)
    }
    if (options.displayMode === ReplyDisplaySettings.MODE_ORIGIN || options.preloadFallbackToFlat) {
      return ReplyThreadCoordinator.prepareRepliesForThreading(options.replies, options.displayMode)
    }
    if (options.displayMode === ReplyDisplaySettings.MODE_THREAD_REDUNDANT) {
      return ReplyThreadCoordinator.buildThreadedReplies(options.replies, options.displayMode, true, false)
    }
    if (options.displayMode === ReplyDisplaySettings.MODE_THREAD_WITH_MENTION) {
      return ReplyThreadCoordinator.buildThreadedReplies(options.replies, options.displayMode, false, false)
    }
    return ReplyThreadCoordinator.buildThreadedReplies(options.replies, options.displayMode, false, true)
  }

  private static childrenThankKey(children: V2exReply[]): string {
    if (children.length === 0) {
      return ''
    }
    const parts = children.map((c: V2exReply) => {
      const sub = ReplyThreadCoordinator.childrenThankKey(c.threadChildren || [])
      return `${c.id}${c.thanked ? 't' : 'f'}${c.thanks || 0}${sub}`
    })
    return `-ch(${parts.join(',')})`
  }

  private static prepareRepliesForThreading(replies: V2exReply[], displayMode: string): V2exReply[] {
    return replies.map((reply: V2exReply, index: number) => {
      reply.floor = index + 1
      reply.threadLevel = 0
      reply.isWrongReference = false
      reply.isDuplicateThreadItem = false
      reply.threadChildren = []
      reply.replyUsers = ReplyThreadCoordinator.extractReplyUsers(reply.content, reply.content_rendered)
      reply.replyFloor = ReplyThreadCoordinator.extractReplyFloor(reply.content, reply.content_rendered)
      reply.hiddenLeadingMentionContent = ReplyThreadCoordinator.removeLeadingSingleMention(
        reply.content,
        reply.replyUsers || [],
        reply.replyFloor || -1,
      )
      reply.hiddenLeadingMentionRenderedContent = ReplyThreadCoordinator.removeLeadingSingleMentionRendered(
        reply.content_rendered,
        reply.replyUsers || [],
        reply.replyFloor || -1,
      )
      reply.relationLabel = ReplyThreadCoordinator.replyRelationLabel(reply)
      reply.renderKey = `${displayMode}-r-${reply.id}-${ReplyThreadCoordinator.replyStateKey(reply)}`
      return reply
    })
  }

  private static buildThreadedReplies(
    replies: V2exReply[],
    displayMode: string,
    includeDuplicateOriginal: boolean,
    hideSingleMention: boolean,
  ): V2exReply[] {
    const base = ReplyThreadCoordinator.prepareRepliesForThreading(replies, displayMode)
    const byFloor = new Map<number, V2exReply>()
    const childMap = new Map<number, V2exReply[]>()
    const parentFloorById = new Map<number, number>()
    base.forEach((reply: V2exReply) => {
      byFloor.set(reply.floor || 0, reply)
      childMap.set(reply.floor || 0, [])
    })

    base.forEach((reply: V2exReply) => {
      const parentFloor = ReplyThreadCoordinator.findThreadParentFloor(reply, byFloor)
      if (parentFloor > 0 && parentFloor < (reply.floor || 0)) {
        const children = childMap.get(parentFloor) || []
        children.push(reply)
        childMap.set(parentFloor, children)
        parentFloorById.set(reply.id, parentFloor)
      }
    })

    const result: V2exReply[] = []
    const prepareNode = (reply: V2exReply, level: number): V2exReply => {
      reply.threadLevel = level
      reply.isDuplicateThreadItem = false
      reply.threadChildren = []
      const children = (childMap.get(reply.floor || 0) || []).sort(
        (a: V2exReply, b: V2exReply) => (a.floor || 0) - (b.floor || 0),
      )
      reply.threadChildren = children.map((child: V2exReply) => prepareNode(child, level + 1))
      const childSummary = ReplyThreadCoordinator.childrenThankKey(reply.threadChildren)
      const compactTag =
        hideSingleMention &&
        level > 0 &&
        (reply.replyUsers || []).length === 1 &&
        (reply.hiddenLeadingMentionContent || '').trim()
          ? '-compact'
          : ''
      reply.renderKey = `${displayMode}-r-${reply.id}-t-${level}${compactTag}-${ReplyThreadCoordinator.replyStateKey(reply)}${childSummary}`
      return reply
    }

    base.forEach((reply: V2exReply) => {
      if (!parentFloorById.has(reply.id)) {
        result.push(prepareNode(reply, 0))
      }
    })

    if (includeDuplicateOriginal) {
      const duplicateList: V2exReply[] = []
      base.forEach((reply: V2exReply) => {
        if (parentFloorById.has(reply.id)) {
          const dup = ReplyThreadCoordinator.cloneReplyForDisplay(reply)
          dup.threadLevel = 0
          dup.threadChildren = []
          dup.isDuplicateThreadItem = true
          dup.renderKey = `${displayMode}-r-${reply.id}-dup-${ReplyThreadCoordinator.replyStateKey(reply)}`
          duplicateList.push(dup)
        }
      })
      return result.concat(
        duplicateList.sort((a: V2exReply, b: V2exReply) => (a.floor || 0) - (b.floor || 0)),
      )
    }
    return result
  }

  private static cloneReplyForDisplay(reply: V2exReply): V2exReply {
    return JSON.parse(JSON.stringify(reply)) as V2exReply
  }

  private static findThreadParentFloor(reply: V2exReply, byFloor: Map<number, V2exReply>): number {
    const floor = reply.floor || 0
    const users = reply.replyUsers || []
    const replyFloor = reply.replyFloor || -1
    if (floor <= 1 || users.length === 0) {
      return 0
    }
    if (replyFloor > 0 && replyFloor < floor) {
      const target = byFloor.get(replyFloor)
      if (!target || !target.member) {
        reply.isWrongReference = true
        return 0
      }
      const targetName = (target.member.username || '').toLowerCase()
      const mentioned = users.some((name: string) => name.toLowerCase() === targetName)
      if (mentioned) {
        return replyFloor
      }
      reply.isWrongReference = true
      return 0
    }
    if (users.length !== 1) {
      return 0
    }
    const targetUser = users[0].toLowerCase()
    for (let i = floor - 1; i >= 1; i--) {
      const candidate = byFloor.get(i)
      if (
        candidate &&
        candidate.member &&
        (candidate.member.username || '').toLowerCase() === targetUser
      ) {
        return i
      }
    }
    return 0
  }

  private static extractReplyUsers(content: string, renderedContent: string): string[] {
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
    const rendered = renderedContent || content || ''
    const linkRe =
      /@?\s*<a\b[^>]*href=["'](?:https?:\/\/(?:www\.)?v2ex\.(?:com|co))?\/member\/([^"'?#\/]+)[^"']*["'][^>]*>/gi
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
    let m: RegExpExecArray | null = re.exec(raw)
    while (m) {
      addName(m[1] || '')
      m = re.exec(raw)
    }
    return names
  }

  private static extractReplyFloor(content: string, renderedContent: string): number {
    const source = `${renderedContent || ''} ${content || ''}`
    const m = source.match(/(?:^|\s)#(\d{1,5})(?:\s|<|$)/)
    if (!m || !m[1]) {
      return -1
    }
    const floor = Number.parseInt(m[1])
    return Number.isNaN(floor) ? -1 : floor
  }

  private static removeLeadingSingleMention(content: string, users: string[], replyFloor: number): string {
    if (users.length !== 1) {
      return content
    }
    const name = users[0]
    const escaped = name.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
    const floorPart = replyFloor > 0 ? `\\s*#${replyFloor}` : '(?:\\s*#\\d+)?'
    const re = new RegExp(`^\\s*@${escaped}${floorPart}\\s*`, 'i')
    const markdownLinkRe = new RegExp(
      `^\\s*\\[@?${escaped}\\]\\((?:https?:\\/\\/(?:www\\.)?v2ex\\.(?:com|co))?\\/member\\/${escaped}(?:[?#][^)]*)?\\)${floorPart}\\s*`,
      'i',
    )
    return (content || '').replace(markdownLinkRe, '').replace(re, '').trim()
  }

  private static removeLeadingSingleMentionRendered(contentRendered: string, users: string[], replyFloor: number): string {
    if (users.length !== 1) {
      return ''
    }
    const source = (contentRendered || '').trim()
    if (!source) {
      return ''
    }
    const direct = ReplyThreadCoordinator.stripLeadingSingleMentionRenderedBody(source, users[0], replyFloor)
    if (direct !== source) {
      return direct.trim()
    }

    const paragraphMatch = source.match(/^(\s*<p\b[^>]*>)([\s\S]*)(<\/p>\s*)$/i)
    if (paragraphMatch) {
      const opening = paragraphMatch[1] || ''
      const body = paragraphMatch[2] || ''
      const closing = paragraphMatch[3] || ''
      const strippedBody = ReplyThreadCoordinator.stripLeadingSingleMentionRenderedBody(body, users[0], replyFloor)
      if (strippedBody !== body) {
        return `${opening}${strippedBody.trimStart()}${closing}`.trim()
      }
    }

    return ''
  }

  private static stripLeadingSingleMentionRenderedBody(contentRendered: string, username: string, replyFloor: number): string {
    const escaped = username.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
    const htmlSpace = '(?:\\s|&nbsp;|&#160;|&#xa0;)*'
    const floorPart = replyFloor > 0 ? `${htmlSpace}#${replyFloor}` : `(?:${htmlSpace}#\\d+)?`
    const memberHref = `(?:https?:\\/\\/(?:www\\.)?v2ex\\.(?:com|co))?\\/member\\/${escaped}(?:[?#][^"']*)?`
    const renderedMentionRe = new RegExp(
      `^${htmlSpace}@?${htmlSpace}<a\\b(?=[^>]*href=["']${memberHref}["'])[^>]*>${htmlSpace}@?${escaped}${htmlSpace}<\\/a>${floorPart}${htmlSpace}`,
      'i',
    )
    return (contentRendered || '').replace(renderedMentionRe, '')
  }

  private static replyRelationLabel(reply: V2exReply): string {
    const users = reply.replyUsers || []
    const floor = reply.replyFloor || -1
    if (users.length === 0 && floor <= 0) {
      return ''
    }
    const mention = users.length > 0 ? users.map((name: string) => `@${name}`).join(' ') : ''
    const floorText = floor > 0 ? `#${floor}` : ''
    const mentionAndFloor = [mention, floorText].filter(s => s).join(' · ')
    return AppStrings.format(AppStrings.text(AppStrings.R_REPLY_THREAD_RELATION_LABEL_FORMAT, 'Reply {0}'), [mentionAndFloor]).trim()
  }
}
