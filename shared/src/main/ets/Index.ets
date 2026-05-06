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

export interface ImagePreviewParams {
  url: string
}

// 网络层
export { HttpClient } from './network/HttpClient'
export { ApiService } from './network/ApiService'
export { ApiV2Service } from './network/ApiV2Service'
export type { ApiV2RateLimit, ApiV2Response } from './network/ApiV2Service'
export { V2exNativeAuthService } from './network/V2exNativeAuthService'
export type { NativeLoginSnapshot } from './network/V2exNativeAuthService'
export { ApiConstants } from './constants/ApiConstants'
export type { TabItem } from './constants/ApiConstants'
export { StorageKeys } from './constants/StorageKeys'
export { ApiDomainSettings } from './settings/ApiDomainSettings'
export { AuthSettings } from './settings/AuthSettings'
export type { AuthSnapshot } from './settings/AuthSettings'
export { CookieJarSettings } from './settings/CookieJarSettings'
export type { CookieJarSnapshot } from './settings/CookieJarSettings'
export { AuthSessionSettings } from './settings/AuthSessionSettings'
export type { AuthLoginMode, AuthSessionSnapshot } from './settings/AuthSessionSettings'
export { MediaSettings } from './settings/MediaSettings'
export { WriteActionSettings } from './settings/WriteActionSettings'
export { CollectionSettings } from './settings/CollectionSettings'
export type { SavedNode, SavedTopic, ViewedTopic, TopicReadPosition, TopicReadState } from './settings/CollectionSettings'
export { DraftSettings } from './settings/DraftSettings'
export type { ReplyDraft, TopicDraft } from './settings/DraftSettings'
export { CacheSettings }
  from './settings/CacheSettings'
export type { CacheKeyIndex, CacheStats, TopicDetailCache } from './settings/CacheSettings'
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
export { V2exSessionParser } from './parser/V2exSessionParser'
export { V2exSigninParser } from './parser/V2exSigninParser'
export type { V2exSigninForm } from './parser/V2exSigninParser'

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
