import { ReplyDisplaySettings, V2exReply, V2exTopic } from 'shared'
import { HotReplySettings } from 'shared'
import { ReplyThreadCoordinator } from './ReplyThreadCoordinator'

export class HotReplyCoordinator {
  static select(
    replies: V2exReply[],
    topic: V2exTopic | null,
    enabled: boolean,
    maxCount: number,
    minThanks: number,
  ): V2exReply[] {
    if (!enabled || !replies || replies.length === 0) {
      return []
    }
    const normalizedMaxCount = HotReplySettings.normalizeMaxCount(maxCount)
    const normalizedMinThanks = HotReplySettings.normalizeMinThanks(minThanks)
    const threaded = ReplyThreadCoordinator.visibleReplies({
      displayMode: ReplyDisplaySettings.MODE_THREAD,
      onlyOp: false,
      preloadFallbackToFlat: false,
      topic: topic,
      replies: HotReplyCoordinator.cloneReplies(replies),
    })
    const candidates: V2exReply[] = []
    HotReplyCoordinator.collectCandidates(threaded, normalizedMinThanks, candidates)
    candidates.sort((left: V2exReply, right: V2exReply) => {
      const thankDelta = Math.max(0, right.thanks || 0) - Math.max(0, left.thanks || 0)
      if (thankDelta !== 0) {
        return thankDelta
      }
      return (left.floor || 0) - (right.floor || 0)
    })
    const result: V2exReply[] = []
    for (let i = 0; i < candidates.length && result.length < normalizedMaxCount; i++) {
      const reply = candidates[i]
      reply.threadLevel = 0
      reply.isDuplicateThreadItem = false
      reply.renderKey = `hot-${reply.renderKey || reply.id.toString()}-${reply.thanks || 0}`
      result.push(reply)
    }
    return result
  }

  static filterCandidates(
    candidates: V2exReply[],
    maxCount: number,
    minThanks: number,
  ): V2exReply[] {
    const normalizedMaxCount = HotReplySettings.normalizeMaxCount(maxCount)
    const normalizedMinThanks = HotReplySettings.normalizeMinThanks(minThanks)
    const result: V2exReply[] = []
    for (let i = 0; i < candidates.length && result.length < normalizedMaxCount; i++) {
      const reply = candidates[i]
      if (reply && Math.max(0, reply.thanks || 0) >= normalizedMinThanks) {
        result.push(reply)
      }
    }
    return result
  }

  private static collectCandidates(
    replies: V2exReply[],
    minThanks: number,
    output: V2exReply[],
  ): void {
    for (let i = 0; i < replies.length; i++) {
      const reply = replies[i]
      if (reply && Math.max(0, reply.thanks || 0) >= minThanks) {
        output.push(reply)
      }
      HotReplyCoordinator.collectCandidates(reply.threadChildren || [], minThanks, output)
    }
  }

  private static cloneReplies(replies: V2exReply[]): V2exReply[] {
    const result: V2exReply[] = []
    for (let i = 0; i < replies.length; i++) {
      result.push(JSON.parse(JSON.stringify(replies[i])) as V2exReply)
    }
    return result
  }
}
