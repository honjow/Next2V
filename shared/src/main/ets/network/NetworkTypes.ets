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
