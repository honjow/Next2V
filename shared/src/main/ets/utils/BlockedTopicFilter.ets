import type { V2exTopic } from '../network/NetworkTypes'

export class BlockedTopicFilter {
  static normalizeUsername(username: string): string {
    return (username || '').trim().toLowerCase()
  }

  static filterTopicsByBlockedAuthors(topics: V2exTopic[], blockedUsernames: string[]): V2exTopic[] {
    if (!Array.isArray(topics) || topics.length === 0 || !Array.isArray(blockedUsernames) || blockedUsernames.length === 0) {
      return topics || []
    }

    const blocked: Set<string> = new Set()
    for (const username of blockedUsernames) {
      const normalized = BlockedTopicFilter.normalizeUsername(username)
      if (normalized) {
        blocked.add(normalized)
      }
    }
    if (blocked.size === 0) {
      return topics
    }

    return topics.filter((topic: V2exTopic) => {
      const author = BlockedTopicFilter.normalizeUsername(topic.member?.username || '')
      return !author || !blocked.has(author)
    })
  }
}
