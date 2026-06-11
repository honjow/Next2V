import { V2exReply } from 'shared'

export class HotReplyChildRepliesExpandCache {
  private static readonly MAX_TOPICS: number = 40
  private static panelExpandedByTopic: Record<string, boolean> = {}
  private static statesByTopic: Record<string, Record<string, boolean>> = {}
  private static topicOrder: string[] = []

  static replyKey(reply: V2exReply): string {
    if (reply.id > 0) {
      return reply.id.toString()
    }
    return reply.renderKey || ''
  }

  static loadPanelExpanded(topicId: number): boolean {
    if (topicId <= 0) {
      return true
    }
    const key = topicId.toString()
    const cached = HotReplyChildRepliesExpandCache.panelExpandedByTopic[key]
    if (cached === true || cached === false) {
      HotReplyChildRepliesExpandCache.touchTopic(key)
      return cached
    }
    return true
  }

  static setPanelExpanded(topicId: number, expanded: boolean): boolean {
    if (topicId <= 0) {
      return expanded
    }
    const topicKey = topicId.toString()
    HotReplyChildRepliesExpandCache.panelExpandedByTopic[topicKey] = expanded
    HotReplyChildRepliesExpandCache.touchTopic(topicKey)
    HotReplyChildRepliesExpandCache.prune()
    return expanded
  }

  static load(topicId: number): Record<string, boolean> {
    if (topicId <= 0) {
      return {}
    }
    const key = topicId.toString()
    const cached = HotReplyChildRepliesExpandCache.statesByTopic[key]
    if (!cached) {
      return {}
    }
    HotReplyChildRepliesExpandCache.touchTopic(key)
    return HotReplyChildRepliesExpandCache.cloneState(cached)
  }

  static setReplyExpanded(
    topicId: number,
    current: Record<string, boolean>,
    reply: V2exReply,
    expanded: boolean,
  ): Record<string, boolean> {
    const replyKey = HotReplyChildRepliesExpandCache.replyKey(reply)
    if (topicId <= 0 || replyKey.length === 0) {
      return HotReplyChildRepliesExpandCache.cloneState(current)
    }
    const next = HotReplyChildRepliesExpandCache.cloneState(current)
    next[replyKey] = expanded
    const topicKey = topicId.toString()
    HotReplyChildRepliesExpandCache.statesByTopic[topicKey] =
      HotReplyChildRepliesExpandCache.cloneState(next)
    HotReplyChildRepliesExpandCache.touchTopic(topicKey)
    HotReplyChildRepliesExpandCache.prune()
    return next
  }

  private static cloneState(source: Record<string, boolean>): Record<string, boolean> {
    const next: Record<string, boolean> = {}
    const keys: string[] = Object.keys(source)
    for (const key of keys) {
      next[key] = source[key]
    }
    return next
  }

  private static touchTopic(topicKey: string): void {
    const nextOrder: string[] = []
    for (const key of HotReplyChildRepliesExpandCache.topicOrder) {
      if (key !== topicKey) {
        nextOrder.push(key)
      }
    }
    nextOrder.push(topicKey)
    HotReplyChildRepliesExpandCache.topicOrder = nextOrder
  }

  private static prune(): void {
    while (HotReplyChildRepliesExpandCache.topicOrder.length >
      HotReplyChildRepliesExpandCache.MAX_TOPICS) {
      const removed = HotReplyChildRepliesExpandCache.topicOrder.shift()
      if (removed) {
        const nextPanelStates: Record<string, boolean> = {}
        const panelKeys: string[] = Object.keys(HotReplyChildRepliesExpandCache.panelExpandedByTopic)
        for (const key of panelKeys) {
          if (key !== removed) {
            nextPanelStates[key] = HotReplyChildRepliesExpandCache.panelExpandedByTopic[key]
          }
        }
        const nextStates: Record<string, Record<string, boolean>> = {}
        const keys: string[] = Object.keys(HotReplyChildRepliesExpandCache.statesByTopic)
        for (const key of keys) {
          if (key !== removed) {
            nextStates[key] = HotReplyChildRepliesExpandCache.statesByTopic[key]
          }
        }
        HotReplyChildRepliesExpandCache.panelExpandedByTopic = nextPanelStates
        HotReplyChildRepliesExpandCache.statesByTopic = nextStates
      }
    }
  }
}
