import { V2exReply, V2exTopic } from '../network/NetworkTypes'
import type { TopicReadState } from '../settings/CollectionTypes'
import type { TopicDetailActionOverlay } from './TopicDetailActionOverlaySettings'

export interface TopicDetailMergeResult {
  topic: V2exTopic | null
  replies: V2exReply[]
}

export class CacheMergeCoordinator {
  static mergeTopicListWithReadStates(topics: V2exTopic[], readStates: TopicReadState[]): V2exTopic[] {
    const _readStateById: Record<string, TopicReadState> = {}
    ;(readStates || []).forEach((state: TopicReadState) => {
      if (state && state.id > 0) {
        _readStateById[state.id.toString()] = state
      }
    })
    // The visible unread marker is derived by FeedListPage from AppStorage; still forcing this merge point
    // makes every feed publication wait for the same local read-state snapshot instead of flashing defaults.
    return (topics || []).slice()
  }

  static mergeTopicDetail(
    topic: V2exTopic | null,
    replies: V2exReply[],
    overlay: TopicDetailActionOverlay | null,
  ): TopicDetailMergeResult {
    if (!overlay) {
      return { topic, replies }
    }
    const thankedIds: Set<number> = new Set<number>()
    ;(overlay.replyThankedIds || []).forEach((id: number) => {
      if (id > 0) {
        thankedIds.add(id)
      }
    })
    const counts = overlay.replyThankCounts || {}
    const mergedReplies = (replies || []).map((reply: V2exReply) => {
      if (!reply || reply.id <= 0) {
        return reply
      }
      if (!thankedIds.has(reply.id) && counts[reply.id.toString()] === undefined) {
        return reply
      }
      const next: V2exReply = {
        id: reply.id,
        thanks: reply.thanks,
        thanked: reply.thanked,
        content: reply.content,
        content_rendered: reply.content_rendered,
        member: reply.member,
        created: reply.created,
        last_modified: reply.last_modified,
        floor: reply.floor,
        replyUsers: reply.replyUsers,
        replyFloor: reply.replyFloor,
        threadLevel: reply.threadLevel,
        isWrongReference: reply.isWrongReference,
        isDuplicateThreadItem: reply.isDuplicateThreadItem,
        hiddenLeadingMentionContent: reply.hiddenLeadingMentionContent,
        hiddenLeadingMentionRenderedContent: reply.hiddenLeadingMentionRenderedContent,
        relationLabel: reply.relationLabel,
        renderKey: reply.renderKey,
        threadChildren: reply.threadChildren,
      }
      const overlayCount = counts[next.id.toString()]
      // Public/API defaults often lack viewer-specific action state, so confirmed same-owner overlays win
      // until an authenticated same-owner parser later supplies a real contradiction.
      if (thankedIds.has(next.id)) {
        next.thanked = true
      }
      // Thank is one-way/non-idempotent on V2EX; never decrement from a public/default payload just because
      // the currently loaded source does not know about the user's already-confirmed thank.
      if (overlayCount !== undefined && overlayCount > Math.max(0, next.thanks || 0)) {
        next.thanks = overlayCount
      }
      next.renderKey = `${next.renderKey || next.id.toString()}-overlay-${next.thanked ? 'thanked' : 'plain'}-${next.thanks || 0}`
      return next
    })
    return { topic, replies: mergedReplies }
  }
}
