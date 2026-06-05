import { AppStrings } from 'shared'
import type {
  ImagePreviewParams,
  NodeTopicListParams,
  TopicDetailParams,
  UserProfileParams,
} from 'shared'

export type IndexDestinationFamily =
  'topicDetail' |
  'webLogin' |
  'nativeLogin' |
  'nodePicker' |
  'search' |
  'topicEditor' |
  'myTopics' |
  'myNodes' |
  'accountFollowing' |
  'settings' |
  'blockedLists' |
  'storage' |
  'diagnosticsLog' |
  'homeNodeSettings' |
  'readingSettings' |
  'networkProxySettings' |
  'imageUploadSettings' |
  'domainSettings' |
  'cloudSyncSettings' |
  'account' |
  'accountDetail' |
  'accountWebView' |
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
  imagePreviewParams: ImagePreviewParams
  nodeTopicParams: NodeTopicListParams
  userProfileParams: UserProfileParams
  title: ResourceStr
}

export class IndexRouteCoordinator {
  private static readonly DESTINATION_FAMILIES: Record<string, IndexDestinationFamily> = {
    'TopicDetail': 'topicDetail',
    'V2exWebLogin': 'webLogin',
    'V2exNativeLogin': 'nativeLogin',
    'NodePicker': 'nodePicker',
    'Search': 'search',
    'TopicEditor': 'topicEditor',
    'MyTopics': 'myTopics',
    'MyNodes': 'myNodes',
    'AccountFollowing': 'accountFollowing',
    'Settings': 'settings',
    'BlockedLists': 'blockedLists',
    'Storage': 'storage',
    'DiagnosticsLog': 'diagnosticsLog',
    'HomeNodeSettings': 'homeNodeSettings',
    'ReadingSettings': 'readingSettings',
    'NetworkProxySettings': 'networkProxySettings',
    'ImageUploadSettings': 'imageUploadSettings',
    'DomainSettings': 'domainSettings',
    'CloudSyncSettings': 'cloudSyncSettings',
    'Account': 'account',
    'AccountDetail': 'accountDetail',
    'AccountWebView': 'accountWebView',
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
      'webLogin': AppStrings.R_NAV_WEB_LOGIN,
      'nativeLogin': AppStrings.R_NAV_NATIVE_LOGIN,
      'nodePicker': AppStrings.R_NAV_NODE_PICKER,
      'search': AppStrings.R_NAV_SEARCH,
      'topicEditor': AppStrings.R_NAV_TOPIC_DRAFT,
      'myTopics': AppStrings.R_NAV_SAVED_TOPICS,
      'myNodes': AppStrings.R_NAV_SAVED_NODES,
      'accountFollowing': AppStrings.R_NAV_FOLLOWING,
      'settings': AppStrings.R_NAV_SETTINGS,
      'blockedLists': AppStrings.R_NAV_BLOCKED_LISTS,
      'storage': AppStrings.R_NAV_STORAGE,
      'diagnosticsLog': AppStrings.R_NAV_DIAGNOSTICS,
      'homeNodeSettings': AppStrings.R_NAV_HOME_NODES,
      'readingSettings': AppStrings.R_NAV_READING,
      'networkProxySettings': AppStrings.R_NAV_NETWORK_PROXY,
      'imageUploadSettings': AppStrings.R_IMAGE_UPLOAD_SETTINGS_TITLE,
      'domainSettings': AppStrings.R_API_DOMAIN,
      'cloudSyncSettings': AppStrings.R_CLOUD_SYNC,
      'account': AppStrings.R_ACCOUNT_MANAGEMENT,
      'accountDetail': AppStrings.R_NAV_ACCOUNT,
      'accountWebView': '',
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
    'nativeLogin': true,
    'nodePicker': true,
    'topicEditor': true,
    'myTopics': true,
    'myNodes': true,
    'accountFollowing': true,
    'settings': true,
    'blockedLists': true,
    'storage': true,
    'diagnosticsLog': true,
    'homeNodeSettings': true,
    'readingSettings': true,
    'networkProxySettings': true,
    'imageUploadSettings': true,
    'domainSettings': true,
    'cloudSyncSettings': true,
    'account': true,
    'accountDetail': true,
    'accountWebView': false,
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
}
