// 路由参数类型
export interface TopicDetailParams {
  topicId: number
}

export interface NodeTopicListParams {
  nodeName: string
  nodeTitle: string
}

export interface UserProfileParams {
  username: string
}

// 网络层
export { HttpClient } from './network/HttpClient'
export { ApiService } from './network/ApiService'
export { ApiConstants } from './constants/ApiConstants'
export type { TabItem } from './constants/ApiConstants'
export { StorageKeys } from './constants/StorageKeys'
export { ApiDomainSettings } from './settings/ApiDomainSettings'
export { AuthSettings } from './settings/AuthSettings'
export type { AuthSnapshot } from './settings/AuthSettings'
export { CollectionSettings } from './settings/CollectionSettings'
export type { SavedTopic } from './settings/CollectionSettings'
export type {
  V2exTopic,
  V2exReply,
  V2exNode,
  V2exMember,
  V2exMemberProfile,
  V2exSiteInfo,
  V2exAuthenticatedMember,
  V2exNotification,
  V2exTokenInfo
} from './network/NetworkTypes'

// 解析
export { V2exTabParser } from './parser/V2exTabParser'

// 工具
export { DateUtils } from './utils/DateUtils'
export { ImageUtils } from './utils/ImageUtils'

// 自适应工具
export { BreakpointSystem } from './utils/BreakpointSystem'
export { BreakPointType } from './utils/BreakPointType'
export type { Breakpoint } from './utils/BreakpointSystem'

// 主题
export { ThemeConstants } from './theme/ThemeConstants'

// 公共组件
export { Avatar } from './components/Avatar'
export { UserName } from './components/UserName'
export { TimeAgo } from './components/TimeAgo'
export { NodeTag } from './components/NodeTag'
export { TopicCard } from './components/TopicCard'
export { ReplyCard } from './components/ReplyCard'
export { PullRefresh } from './components/PullRefresh'
export { HtmlContent } from './components/HtmlContent'
export { MarkdownContent } from './components/MarkdownContent'
export { LoadingFooter } from './components/LoadingFooter'
