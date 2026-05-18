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
  'homeNodeSettings' |
  'readingSettings' |
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
    'HomeNodeSettings': 'homeNodeSettings',
    'ReadingSettings': 'readingSettings',
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
    'replyEditor': '回复',
    'webLogin': '网页登录',
    'nativeLogin': '账号密码登录',
    'nodePicker': '选择节点',
    'search': '搜索',
    'topicEditor': '发帖草稿',
    'myTopics': '收藏主题',
    'myNodes': '收藏节点',
    'accountBlacklist': '屏蔽与忽略',
    'accountFollowing': '关注用户',
    'settings': '设置',
    'storage': '存储',
    'homeNodeSettings': '首页栏目设置',
    'readingSettings': '阅读字体设置',
    'account': '账号',
    'savedTopics': '稍后读',
    'viewedTopics': '最近浏览',
    'savedNodes': '本地关注节点',
    'about': '关于',
    'userTopics': '全部主题',
    'userReplies': '全部回复',
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
    'homeNodeSettings': true,
    'readingSettings': true,
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
