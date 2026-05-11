// 路由参数类型
export interface TopicDetailParams {
  topicId: number
  targetFloor?: number
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
export { ApiService, V2exCookieTwoFactorRequiredError } from './network/ApiService'
export type {
  V2exReplyModerationAction,
  V2exReplyThankAction,
  V2exTopicModerationAction,
  V2exTopicThankAction,
  V2exTopicWebRepliesPage
} from './network/ApiService'
export { ApiV2Service } from './network/ApiV2Service'
export { Sov2exService } from './network/Sov2exService'
export type { ApiV2RateLimit, ApiV2Response } from './network/ApiV2Service'
export { V2exNativeAuthService, NativeTwoFactorRequiredError } from './network/V2exNativeAuthService'
export type { NativeLoginChallenge, NativeLoginSnapshot, NativeTwoFactorChallenge } from './network/V2exNativeAuthService'
export { ApiConstants } from './constants/ApiConstants'
export type { TabItem } from './constants/ApiConstants'
export { StorageKeys } from './constants/StorageKeys'
export { ApiDomainSettings } from './settings/ApiDomainSettings'
export { FeedTabSettings } from './settings/FeedTabSettings'
export { ThemeSettings }
  from './settings/ThemeSettings'
export { AuthSettings } from './settings/AuthSettings'
export type { AuthSnapshot } from './settings/AuthSettings'
export { CookieJarSettings } from './settings/CookieJarSettings'
export type { CookieJarSnapshot } from './settings/CookieJarSettings'
export { AuthSessionSettings } from './settings/AuthSessionSettings'
export type { AuthLoginMode, AuthSessionSnapshot } from './settings/AuthSessionSettings'
export { MediaSettings } from './settings/MediaSettings'
export type { MediaSettingsSnapshot } from './settings/MediaSettings'
export { ReadingSettings } from './settings/ReadingSettings'
export type { ReadingSettingsSnapshot } from './settings/ReadingSettings'
export { WriteActionSettings } from './settings/WriteActionSettings'
export { CollectionSettings } from './settings/CollectionSettings'
export type { SavedNode, SavedTopic, ViewedTopic, TopicReadPosition, TopicReadState, LocalContentStats } from './settings/CollectionSettings'
export { DraftSettings } from './settings/DraftSettings'
export type { ReplyDraft, TopicDraft } from './settings/DraftSettings'
export { SearchSettings } from './settings/SearchSettings'
export type { SearchSourceMode } from './settings/SearchSettings'
export { NotificationSettings } from './settings/NotificationSettings'
export type { NotificationCacheSnapshot } from './settings/NotificationSettings'
export { LocalDataSettings } from './settings/LocalDataSettings'
export { BlockedMemberSettings } from './settings/BlockedMemberSettings'
export type { BlockedMemberSnapshot } from './settings/BlockedMemberSettings'
export { MotionHandStateService } from './services/MotionHandStateService'
export type { MotionHandEdge } from './services/MotionHandStateService'
export { CacheSettings }
  from './settings/CacheSettings'
export type { CacheKeyIndex, CacheStats, TopicDetailCache } from './settings/CacheSettings'
export { BlockedTopicFilter } from './utils/BlockedTopicFilter'
export type {
  V2exTopic,
  V2exReply,
  V2exNode,
  V2exMember,
  V2exMemberProfile,
  V2exSiteInfo,
  V2exAuthenticatedMember,
  V2exNotification,
  V2exTokenInfo,
  V2exBalance,
  V2exDailyMission,
  V2exUserReply,
  V2exMemberActionState,
  V2exMemberPageSnapshot,
  V2exMemberRepliesPageSnapshot,
  V2exMemberTopicsPageSnapshot,
  V2exNodeTopicsPageSnapshot,
  V2exNodeTopicsPageResult,
  Sov2exSortMode,
  Sov2exOrderMode,
  Sov2exSearchOptions,
  Sov2exTopicSource,
  Sov2exHighlight,
  Sov2exHit,
  Sov2exSearchResponse
} from './network/NetworkTypes'

// 解析
export { V2exTabParser } from './parser/V2exTabParser'
export { V2exAccountParser } from './parser/V2exAccountParser'
export { V2exNotificationParser } from './parser/V2exNotificationParser'
export { V2exSessionParser } from './parser/V2exSessionParser'
export { V2exSigninParser } from './parser/V2exSigninParser'
export type { V2exSigninForm } from './parser/V2exSigninParser'
export { V2exNodeParser } from './parser/V2exNodeParser'
export type { V2exFavoriteNode } from './parser/V2exNodeParser'
export { V2exCollectionActionParser } from './parser/V2exCollectionActionParser'
export type { V2exToggleAction } from './parser/V2exCollectionActionParser'
export { V2exMemberPageParser } from './parser/V2exMemberPageParser'
export { V2exTopicRepliesParser } from './parser/V2exTopicRepliesParser'
export { V2exAccountListParser } from './parser/V2exAccountListParser'
export type { V2exAccountMemberListItem } from './parser/V2exAccountListParser'

// 工具
export { DateUtils } from './utils/DateUtils'
export { ImageUtils } from './utils/ImageUtils'
export { MediaUrlUtils } from './utils/MediaUrlUtils'
export type { MediaUrlKind, MediaUrlResult } from './utils/MediaUrlUtils'
export { NodeSearchUtils } from './utils/NodeSearchUtils'
export type { NodeSearchMatch } from './utils/NodeSearchUtils'
export { V2exUrlRouter }
  from './utils/V2exUrlRouter'
export type { V2exRoute, V2exRouteKind } from './utils/V2exUrlRouter'

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
export { LocalTopicCard } from './components/LocalTopicCard'
export { ReplyCard } from './components/ReplyCard'
export { PullRefresh } from './components/PullRefresh'
export { PullRefreshListScaffold } from './components/PullRefreshListScaffold'
export { HtmlContent } from './components/HtmlContent'
export { MarkdownContent } from './components/MarkdownContent'
export { HtmlEntityUtils } from './utils/HtmlEntityUtils'
export { LoadingFooter } from './components/LoadingFooter'
export { SecondaryListScaffold } from './components/SecondaryListScaffold'
export { SecondaryFormScaffold } from './components/SecondaryFormScaffold'
export { SectionHeader } from './components/SectionHeader'
export { ListDivider } from './components/ListDivider'
export { ConciseListRow } from './components/ConciseListRow'
export { GroupedListSection } from './components/GroupedListSection'
export { EmptyState } from './components/EmptyState'
export { AppSearchField } from './components/AppSearchField'
export { AppTextField } from './components/AppTextField'
export { AppActionButton } from './components/AppActionButton'
export { AppModalScaffold } from './components/AppModalScaffold'
export { FilterChip } from './components/FilterChip'
export { MarkdownToolbar } from './components/MarkdownToolbar'
