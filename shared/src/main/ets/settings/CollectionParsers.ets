import type {
  SavedNode,
  SavedTopic,
  TopicReadPosition,
  TopicReadState,
  ViewedTopic,
} from './CollectionTypes'

export function parseSavedTopics(raw: string): SavedTopic[] {
  try {
    const parsed = JSON.parse(raw) as SavedTopic[]
    if (!Array.isArray(parsed)) {
      return []
    }
    return parsed.filter((item: SavedTopic) => item.id > 0 && item.title.length > 0)
  } catch (error) {
    return []
  }
}

export function parseSavedNodes(raw: string): SavedNode[] {
  try {
    const parsed = JSON.parse(raw) as SavedNode[]
    if (!Array.isArray(parsed)) {
      return []
    }
    const nodes: SavedNode[] = []
    parsed.forEach((item: SavedNode) => {
      const node = normalizeSavedNode(item)
      if (node) {
        nodes.push(node)
      }
    })
    return nodes
  } catch (error) {
    return []
  }
}

export function normalizeSavedNode(item: SavedNode): SavedNode | null {
  const name = ((item?.name || '') as string).trim()
  const topics = Math.max(0, item?.topics || 0)
  const title = cleanNodeTitle(((item?.title || name) as string).trim(), topics)
  if (!name || !title) {
    return null
  }
  return {
    name: name,
    title: title,
    topics: topics,
    avatarMini: ((item?.avatarMini || '') as string).trim() || undefined,
    avatarNormal: ((item?.avatarNormal || '') as string).trim() || undefined,
    avatarLarge: ((item?.avatarLarge || '') as string).trim() || undefined,
    savedAt: item?.savedAt || 0
  }
}

export function cleanNodeTitle(title: string, topics: number = 0): string {
  let clean = (title || '')
    .replace(/\s*[·｜|]\s*\d+\s*个主题\s*$/g, '')
    .replace(/\s+\d+\s*个主题\s*$/g, '')
    .trim()
  if (topics > 0) {
    const topicSuffix = `${topics}`
    if (clean.endsWith(` ${topicSuffix}`)) {
      clean = clean.substring(0, clean.length - topicSuffix.length).trim()
    }
  }
  return clean.replace(/\s+\d{2,}\s*$/g, '').trim()
}

export function parseViewedTopics(raw: string): ViewedTopic[] {
  try {
    const parsed = JSON.parse(raw) as ViewedTopic[]
    if (!Array.isArray(parsed)) {
      return []
    }
    return parsed.filter((item: ViewedTopic) => item.id > 0 && item.title.length > 0)
  } catch (error) {
    return []
  }
}

export function parseTopicReadPositions(raw: string): TopicReadPosition[] {
  try {
    const parsed = JSON.parse(raw) as TopicReadPosition[]
    if (!Array.isArray(parsed)) {
      return []
    }
    return parsed.filter((item: TopicReadPosition) => item.id > 0 && item.floor > 0)
  } catch (error) {
    return []
  }
}

export function parseTopicReadStates(raw: string): TopicReadState[] {
  try {
    const parsed = JSON.parse(raw) as TopicReadState[]
    if (!Array.isArray(parsed)) {
      return []
    }
    return parsed.filter((item: TopicReadState) => item.id > 0 && item.touchedAt > 0)
  } catch (error) {
    return []
  }
}
