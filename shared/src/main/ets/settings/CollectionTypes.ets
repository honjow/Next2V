export interface SavedTopic {
  id: number
  title: string
  nodeName: string
  nodeTitle: string
  username: string
  avatar?: string
  memberPro?: number
  created: number
  replies?: number
  savedAt: number
}

export interface SavedNode {
  name: string
  title: string
  topics: number
  avatarMini?: string
  avatarNormal?: string
  avatarLarge?: string
  savedAt: number
}

export interface ViewedTopic {
  id: number
  title: string
  nodeName: string
  nodeTitle: string
  username: string
  avatar?: string
  memberPro?: number
  replies?: number
  viewedAt: number
}

export interface TopicReadPosition {
  id: number
  floor: number
  updatedAt: number
}

export interface TopicReadState {
  id: number
  touchedAt: number
  updatedAt: number
}

export interface LocalContentStats {
  savedTopicCount: number
  savedNodeCount: number
  viewedTopicCount: number
}
