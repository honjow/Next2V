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
      'webLogin': $r('app.string.nav_web_login'),
      'nativeLogin': $r('app.string.nav_native_login'),
      'nodePicker': $r('app.string.nav_node_picker'),
      'search': $r('app.string.nav_search'),
      'topicEditor': $r('app.string.nav_topic_draft'),
      'myTopics': $r('app.string.nav_saved_topics'),
      'myNodes': $r('app.string.nav_saved_nodes'),
      'accountFollowing': $r('app.string.nav_following'),
      'settings': $r('app.string.nav_settings'),
      'blockedLists': $r('app.string.nav_blocked_lists'),
      'storage': $r('app.string.nav_storage'),
      'diagnosticsLog': $r('app.string.nav_diagnostics'),
      'homeNodeSettings': $r('app.string.nav_home_nodes'),
      'readingSettings': $r('app.string.nav_reading'),
      'networkProxySettings': $r('app.string.nav_network_proxy'),
      'imageUploadSettings': $r('app.string.image_upload_settings_title'),
      'domainSettings': $r('app.string.api_domain'),
      'cloudSyncSettings': $r('app.string.cloud_sync'),
      'account': $r('app.string.account_management'),
      'accountDetail': $r('app.string.nav_account'),
      'accountWebView': '',
      'savedTopics': $r('app.string.nav_read_later'),
      'viewedTopics': $r('app.string.nav_recently_viewed'),
      'savedNodes': $r('app.string.nav_local_nodes'),
      'about': $r('app.string.nav_about'),
      'userTopics': $r('app.string.nav_all_topics'),
      'userReplies': $r('app.string.nav_all_replies'),
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
      // verifyReplyText rides alongside targetFloor so the detail page can repair a wrong
      // V2EX #reply anchor by matching the reply text (see TopicDetailScrollCoordinator.verifiedFloor).
      const verifyReplyText = IndexRouteCoordinator.stringParam(param, 'verifyReplyText')
      return { topicId, targetFloor, verifyReplyText }
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
