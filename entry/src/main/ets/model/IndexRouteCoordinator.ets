import { AppStrings } from 'shared'
import type {
  ImagePreviewParams,
  NodeTopicListParams,
  TopicDetailParams,
  UserProfileParams,
  V2exRoute,
} from 'shared'

export interface ReplyEditorRouteParams {
  topicId: number
  topicTitle: string
  initialContent: string
}

export type IndexDestinationFamily =
  'topicDetail' |
  'replyEditor' |
  'webLogin' |
  'nativeLogin' |
  'nodePicker' |
  'search' |
  'topicEditor' |
  'myTopics' |
  'myNodes' |
  'accountBlacklist' |
  'accountFollowing' |
  'settings' |
  'storage' |
  'diagnosticsLog' |
  'homeNodeSettings' |
  'readingSettings' |
  'networkProxySettings' |
  'account' |
  'savedTopics' |
  'viewedTopics' |
  'savedNodes' |
  'about' |
  'imagePreview' |
  'nodeTopic' |
  'userProfile' |
  'userTopics' |
  'userReplies'

export interface IndexDestinationDescriptor {
  family: IndexDestinationFamily
  topicDetailParams: TopicDetailParams
  replyEditorParams: ReplyEditorRouteParams
  imagePreviewParams: ImagePreviewParams
  nodeTopicParams: NodeTopicListParams
  userProfileParams: UserProfileParams
  title: string
}

export class IndexRouteCoordinator {
  private static readonly DESTINATION_FAMILIES: Record<string, IndexDestinationFamily> = {
    'TopicDetail': 'topicDetail',
    'ReplyEditor': 'replyEditor',
    'V2exWebLogin': 'webLogin',
    'V2exNativeLogin': 'nativeLogin',
    'NodePicker': 'nodePicker',
    'Search': 'search',
    'TopicEditor': 'topicEditor',
    'MyTopics': 'myTopics',
    'MyNodes': 'myNodes',
    'AccountBlacklist': 'accountBlacklist',
    'AccountFollowing': 'accountFollowing',
    'Settings': 'settings',
    'Storage': 'storage',
    'DiagnosticsLog': 'diagnosticsLog',
    'HomeNodeSettings': 'homeNodeSettings',
    'ReadingSettings': 'readingSettings',
    'NetworkProxySettings': 'networkProxySettings',
    'Account': 'account',
    'SavedTopics': 'savedTopics',
    'ViewedTopics': 'viewedTopics',
    'SavedNodes': 'savedNodes',
    'About': 'about',
    'ImagePreview': 'imagePreview',
    'NodeTopicList': 'nodeTopic',
    'UserProfile': 'userProfile',
    'UserTopics': 'userTopics',
    'UserReplies': 'userReplies',
  }

  private static readonly DESTINATION_TITLES: Record<string, string> = {
    'replyEditor': AppStrings.t(AppStrings.R_NAV_REPLY, 'Reply'),
    'webLogin': AppStrings.t(AppStrings.R_NAV_WEB_LOGIN, 'Web login'),
    'nativeLogin': AppStrings.t(AppStrings.R_NAV_NATIVE_LOGIN, 'Password login'),
    'nodePicker': AppStrings.t(AppStrings.R_NAV_NODE_PICKER, 'Select node'),
    'search': AppStrings.t(AppStrings.R_NAV_SEARCH, 'Search'),
    'topicEditor': AppStrings.t(AppStrings.R_NAV_TOPIC_DRAFT, 'Topic draft'),
    'myTopics': AppStrings.t(AppStrings.R_NAV_SAVED_TOPICS, 'Favorite topics'),
    'myNodes': AppStrings.t(AppStrings.R_NAV_SAVED_NODES, 'Favorite nodes'),
    'accountBlacklist': AppStrings.t(AppStrings.R_NAV_BLACKLIST, 'Blocked and ignored'),
    'accountFollowing': AppStrings.t(AppStrings.R_NAV_FOLLOWING, 'Following'),
    'settings': AppStrings.t(AppStrings.R_NAV_SETTINGS, 'Settings'),
    'storage': AppStrings.t(AppStrings.R_NAV_STORAGE, 'Storage'),
    'diagnosticsLog': AppStrings.t(AppStrings.R_NAV_DIAGNOSTICS, 'Diagnostics log'),
    'homeNodeSettings': AppStrings.t(AppStrings.R_NAV_HOME_NODES, 'Home tab settings'),
    'readingSettings': AppStrings.t(AppStrings.R_NAV_READING, 'Reading font settings'),
    'networkProxySettings': AppStrings.t(AppStrings.R_NAV_NETWORK_PROXY, 'Network proxy'),
    'account': AppStrings.t(AppStrings.R_ACCOUNT_SECTION, 'Account'),
    'savedTopics': AppStrings.t(AppStrings.R_NAV_READ_LATER, 'Read later'),
    'viewedTopics': AppStrings.t(AppStrings.R_NAV_RECENTLY_VIEWED, 'Recently viewed'),
    'savedNodes': AppStrings.t(AppStrings.R_NAV_LOCAL_NODES, 'Local followed nodes'),
    'about': AppStrings.t(AppStrings.R_NAV_ABOUT, 'About'),
    'userTopics': AppStrings.t(AppStrings.R_NAV_ALL_TOPICS, 'All topics'),
    'userReplies': AppStrings.t(AppStrings.R_NAV_ALL_REPLIES, 'All replies'),
  }

  private static readonly STANDARD_TITLE_BAR_FAMILIES: Record<string, boolean> = {
    'replyEditor': true,
    'nativeLogin': true,
    'nodePicker': true,
    'topicEditor': true,
    'myTopics': true,
    'myNodes': true,
    'accountBlacklist': true,
    'accountFollowing': true,
    'settings': true,
    'storage': true,
    'diagnosticsLog': true,
    'homeNodeSettings': true,
    'readingSettings': true,
    'networkProxySettings': true,
    'account': true,
    'savedTopics': true,
    'viewedTopics': true,
    'savedNodes': true,
    'about': true,
    'userTopics': true,
    'userReplies': true,
  }

  private static numberParam(param: Object, key: string): number {
    try {
      const value = (param as Record<string, Object>)[key]
      return typeof value === 'number' && Number.isFinite(value) ? value : 0
    } catch (_error) {
      return 0
    }
  }

  private static stringParam(param: Object, key: string): string {
    try {
      const value = (param as Record<string, Object>)[key]
      return typeof value === 'string' ? value : ''
    } catch (_error) {
      return ''
    }
  }

  static topicDetailRouteParams(param: Object): TopicDetailParams {
    const topicId = IndexRouteCoordinator.numberParam(param, 'topicId')
    const targetFloor = IndexRouteCoordinator.numberParam(param, 'targetFloor')
    if (targetFloor > 0) {
      return { topicId, targetFloor }
    }
    return { topicId }
  }

  static replyEditorRouteParams(param: Object): ReplyEditorRouteParams {
    return {
      topicId: IndexRouteCoordinator.numberParam(param, 'topicId'),
      topicTitle: IndexRouteCoordinator.stringParam(param, 'topicTitle'),
      initialContent: IndexRouteCoordinator.stringParam(param, 'initialContent'),
    }
  }

  static imagePreviewRouteParams(param: Object): ImagePreviewParams {
    return { url: IndexRouteCoordinator.stringParam(param, 'url') }
  }

  static nodeTopicRouteParams(param: Object): NodeTopicListParams {
    const nodeName = IndexRouteCoordinator.stringParam(param, 'nodeName')
    const nodeTitle = IndexRouteCoordinator.stringParam(param, 'nodeTitle')
    return { nodeName, nodeTitle }
  }

  static userProfileRouteParams(param: Object): UserProfileParams {
    return { username: IndexRouteCoordinator.stringParam(param, 'username') }
  }

  private static destinationDescriptor(
    family: IndexDestinationFamily,
    param: Object,
  ): IndexDestinationDescriptor {
    return {
      family: family,
      topicDetailParams: IndexRouteCoordinator.topicDetailRouteParams(param),
      replyEditorParams: IndexRouteCoordinator.replyEditorRouteParams(param),
      imagePreviewParams: IndexRouteCoordinator.imagePreviewRouteParams(param),
      nodeTopicParams: IndexRouteCoordinator.nodeTopicRouteParams(param),
      userProfileParams: IndexRouteCoordinator.userProfileRouteParams(param),
      title: IndexRouteCoordinator.DESTINATION_TITLES[family] || '',
    }
  }

  static destination(name: string, param: Object): IndexDestinationDescriptor | null {
    const family = IndexRouteCoordinator.DESTINATION_FAMILIES[(name || '').trim()]
    if (!family) {
      return null
    }
    return IndexRouteCoordinator.destinationDescriptor(family, param)
  }

  static usesStandardTitleBar(family: IndexDestinationFamily): boolean {
    return !!IndexRouteCoordinator.STANDARD_TITLE_BAR_FAMILIES[family]
  }

  static commandPayload(command: string): string {
    const raw = (command || '').trim()
    if (!raw) {
      return ''
    }
    const stampedMatch = raw.match(/^\d+:(.+)$/)
    const payload = stampedMatch && stampedMatch[1] ? stampedMatch[1] : raw
    return payload.trim()
  }

  static simpleCommand(action: string, now: number): string {
    return `${now}:${(action || '').trim()}`
  }

  static topicActionCommand(topicId: number, action: string, now: number): string {
    return `${now}:${topicId}:${(action || '').trim()}`
  }

  static nodeTopicActionCommand(nodeName: string, action: string, now: number): string {
    return `${now}:${(nodeName || '').trim()}:${(action || '').trim()}`
  }

  static userProfileShownCommand(username: string, now: number): string {
    return `${now}:${(username || '').trim()}`
  }

  static pendingSearchQueryCommand(query: string, now: number): string {
    return `${now}:${(query || '').trim()}`
  }

  static topicParams(route: V2exRoute): TopicDetailParams | null {
    if (route.kind !== 'topic' || !route.topicId || route.topicId <= 0) {
      return null
    }
    if (route.targetFloor && route.targetFloor > 0) {
      return { topicId: route.topicId, targetFloor: route.targetFloor }
    }
    return { topicId: route.topicId }
  }

  static userProfileParams(route: V2exRoute): UserProfileParams | null {
    if (route.kind !== 'member' || !route.username) {
      return null
    }
    return { username: route.username }
  }

  static nodeTopicParams(route: V2exRoute): NodeTopicListParams | null {
    if (route.kind !== 'node' || !route.nodeName) {
      return null
    }
    return { nodeName: route.nodeName, nodeTitle: route.nodeName }
  }

  static searchQuery(route: V2exRoute): string {
    if (route.kind !== 'search' || !route.query) {
      return ''
    }
    return route.query.trim()
  }
}
