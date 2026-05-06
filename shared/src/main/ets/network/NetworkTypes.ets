// V2EX API 响应类型定义

export interface V2exMember {
  id: number
  username: string
  tagline: string
  avatar_mini: string
  avatar_normal: string
  avatar_large: string
}

export interface V2exNode {
  id: number
  name: string
  title: string
  title_alternative: string
  url: string
  topics: number
  avatar_mini: string
  avatar_normal: string
  avatar_large: string
  header?: string
  footer?: string
  stars?: number
  created?: number
}

export interface V2exTopic {
  id: number
  title: string
  url: string
  content: string
  content_rendered: string
  replies: number
  member: V2exMember
  node: V2exNode
  created: number
  last_modified: number
  last_touched: number
  last_reply_by?: string
}

export interface V2exReply {
  id: number
  thanks: number
  content: string
  content_rendered: string
  member: V2exMember
  created: number
  last_modified: number
}

export interface V2exMemberProfile {
  status: string
  id: number
  url: string
  username: string
  website: string
  twitter: string
  psn: string
  github: string
  btc: string
  location: string
  tagline: string
  bio: string
  avatar_mini: string
  avatar_normal: string
  avatar_large: string
  created: number
}

export interface V2exSiteInfo {
  title: string
  slogan: string
  description: string
  domain: string
}

export interface V2exAuthenticatedMember {
  id?: number
  username?: string
  url?: string
  website?: string
  twitter?: string
  github?: string
  location?: string
  tagline?: string
  bio?: string
  avatar_mini?: string
  avatar_normal?: string
  avatar_large?: string
  created?: number
}

export interface V2exTokenInfo {
  id?: number
  token?: string
  scope?: string
  expiration?: number
  created?: number
  last_used?: number
  success?: boolean
  message?: string
}

export interface V2exNotification {
  id: number
  member?: V2exMember
  for_member_id?: number
  text?: string
  payload?: string
  payload_rendered?: string
  title?: string
  content?: string
  content_rendered?: string
  topic_id?: number
  topic_title?: string
  created?: number
  last_modified?: number
  unread?: boolean
}

export interface V2exBalance {
  gold: number
  silver: number
  bronze: number
  summary: string
}

export interface V2exDailyMission {
  canRedeem: boolean
  redeemPath: string
  message: string
}
