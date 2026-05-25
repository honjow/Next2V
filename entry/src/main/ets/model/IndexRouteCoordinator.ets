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
  title: ResourceStr
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

  static destinationTitle(family: IndexDestinationFamily): ResourceStr {
    const titles: Record<string, ResourceStr> = {
      'replyEditor': AppStrings.R_NAV_REPLY,
      'webLogin': AppStrings.R_NAV_WEB_LOGIN,
      'nativeLogin': AppStrings.R_NAV_NATIVE_LOGIN,
      'nodePicker': AppStrings.R_NAV_NODE_PICKER,
      'search': AppStrings.R_NAV_SEARCH,
      'topicEditor': AppStrings.R_NAV_TOPIC_DRAFT,
      'myTopics': AppStrings.R_NAV_SAVED_TOPICS,
      'myNodes': AppStrings.R_NAV_SAVED_NODES,
      'accountFollowing': AppStrings.R_NAV_FOLLOWING,
      'settings': AppStrings.R_NAV_SETTINGS,
      'storage': AppStrings.R_NAV_STORAGE,
      'diagnosticsLog': AppStrings.R_NAV_DIAGNOSTICS,
      'homeNodeSettings': AppStrings.R_NAV_HOME_NODES,
      'readingSettings': AppStrings.R_NAV_READING,
      'networkProxySettings': AppStrings.R_NAV_NETWORK_PROXY,
      'account': AppStrings.R_ACCOUNT_MANAGEMENT,
      'savedTopics': AppStrings.R_NAV_READ_LATER,
      'viewedTopics': AppStrings.R_NAV_RECENTLY_VIEWED,
      'savedNodes': AppStrings.R_NAV_LOCAL_NODES,
      'about': AppStrings.R_NAV_ABOUT,
      'userTopics': AppStrings.R_NAV_ALL_TOPICS,
      'userReplies': AppStrings.R_NAV_ALL_REPLIES,
    }
    return titles[family] || ''
  }

  private static readonly STANDARD_TITLE_BAR_FAMILIES: Record<string, boolean> = {
    'replyEditor': true,
    'nativeLogin': true,
    'nodePicker': true,
    'topicEditor': true,
    'myTopics': true,
    'myNodes': true,
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
      title: IndexRouteCoordinator.destinationTitle(family),
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
