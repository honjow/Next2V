// V2EX API response type definitions

export interface V2exMember {
  id: number
  username: string
  tagline: string
  pro?: number
  avatar_mini: string
  avatar_normal: string
  avatar_large: string
  avatar_xlarge?: string
  avatar_xxlarge?: string
  avatar_xxxlarge?: string
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
  topicSupplementMarkdown?: string
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
  thanked?: boolean
  content: string
  content_rendered: string
  member: V2exMember
  created: number
  last_modified: number
  floor?: number
  replyUsers?: string[]
  replyFloor?: number
  threadLevel?: number
  isWrongReference?: boolean
  isDuplicateThreadItem?: boolean
  hiddenLeadingMentionContent?: string
  hiddenLeadingMentionRenderedContent?: string
  relationLabel?: string
  renderKey?: string
  threadChildren?: V2exReply[]
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
  reply_content?: string
  reply_content_rendered?: string
  payload?: string
  payload_rendered?: string
  title?: string
  content?: string
  content_rendered?: string
  topic_id?: number
  topic_title?: string
  target_floor?: number
  delete_id?: number
  delete_once?: string
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

export interface V2exDailyRedeemResult {
  // The re-fetched mission state after redeeming (canRedeem now false).
  mission: V2exDailyMission
  // 铜币 reward parsed from /balance (0 when it couldn't be read; the toast then omits the amount).
  rewardCoins: number
}

export interface V2exUserReply {
  reply_key?: string
  topic_id: number
  topic_title: string
  target_floor: number
  node_name: string
  node_title: string
  topic_author: string
  content: string
  content_rendered?: string
  created: number
  created_text?: string
}

export interface V2exMemberActionState {
  following: boolean
  followPath: string
  blocked: boolean
  blockPath: string
}

export interface V2exMemberPageSnapshot {
  topicIds: number[]
  topicsHidden: boolean
  replies: V2exUserReply[]
  actions: V2exMemberActionState | null
}

export interface V2exMemberTopicsPageSnapshot {
  topicIds: number[]
  topicsHidden: boolean
  hasMore: boolean
}

export interface V2exMemberRepliesPageSnapshot {
  replies: V2exUserReply[]
  hasMore: boolean
}

export interface V2exNodeTopicsPageSnapshot {
  topicIds: number[]
  hasMore: boolean
}

export interface V2exNodeTopicsPageResult {
  topics: V2exTopic[]
  hasMore: boolean
}

// A page of topics plus whether a next page exists (read from the V2EX pagination footer, not a
// per-page item count). Used by the web-paginated account lists, e.g. favorites (/my/topics).
export interface V2exPagedTopicsResult {
  topics: V2exTopic[]
  hasMore: boolean
}

export type Sov2exSortMode = 'sumup' | 'created'
export type Sov2exOrderMode = '0' | '1'

export interface Sov2exSearchOptions {
  q: string
  from?: number
  size?: number
  sort?: Sov2exSortMode
  order?: Sov2exOrderMode
  username?: string
  node?: string
  gte?: number
  lte?: number
}

export interface Sov2exTopicSource {
  node?: number
  replies?: number
  created?: string
  member?: string
  id?: number
  title?: string
  content?: string
}

export interface Sov2exHighlight {
  title?: string[]
  content?: string[]
  replyListContent?: string[]
  postscript_list?: string[]
}

export interface Sov2exHit {
  _score?: number | null
  _index?: string
  _type?: string
  _id?: string
  sort?: number[]
  highlight?: Sov2exHighlight
  _source?: Sov2exTopicSource
}

export interface Sov2exSearchResponse {
  took?: number
  timed_out?: boolean
  total?: number
  hits?: Sov2exHit[]
}
