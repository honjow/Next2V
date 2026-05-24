import { NodeViewModel } from '../viewmodel/NodeViewModel'
import {
  AuthSettings, CardEmptyState, CollectionSettings, SavedNode, ApiService, CookieJarSettings,
  PagedListScaffold, PageErrorState, PageLoadingState, StorageKeys, ThemeConstants, TopicCard,
  TopicDetailParams, UserProfileParams, V2exToggleAction, V2exTopic, AppStrings, translateApiError
} from 'shared'
import type { TopicReadState } from 'shared'
import { common } from '@kit.AbilityKit'
import { promptAction } from '@kit.ArkUI'

@Component
export struct NodeTopicPage {
  @Prop nodeName: string = ''
  @Prop nodeTitle: string = ''
  @Consume('ns') stack: NavPathStack
  @StorageProp(StorageKeys.TOP_AVOID_HEIGHT) topH: number = 0
  @StorageProp(StorageKeys.BOTTOM_AVOID_HEIGHT) bottomH: number = 0
  @State vm: NodeViewModel = new NodeViewModel()
  @StorageLink(StorageKeys.TOPIC_READ_STATES) topicReadStates: string = '[]'
  @StorageLink(StorageKeys.NODE_TOPIC_ACTION) @Watch('onNodeTopicActionCommand') nodeTopicActionCommand: string = ''
  @StorageLink(StorageKeys.NODE_TOPIC_SAVED) nodeTopicSaved: boolean = false
  @StorageLink(StorageKeys.NODE_TOPIC_SITE_FAVORITED) nodeTopicSiteFavorited: boolean = false
  @StorageLink(StorageKeys.NODE_TOPIC_TITLE) nodeTopicTitle: string = ''
  @StorageLink(StorageKeys.NODE_TOPIC_SUBTITLE) nodeTopicSubtitle: string = ''
  @State private isNodeSaved: boolean = false
  @State private isSavedNodeLoading: boolean = false
  @State private isSiteNodeFavorited: boolean = false
  @State private isSiteNodeFavoriteLoading: boolean = false
  @State private token: string = ''
  private api: ApiService = new ApiService()

  aboutToAppear(): void {
    this.syncNodeTitleState(false, false)
    this.syncAppbarIdentity()
    this.vm.isLoading = true
    this.loadData()
    this.loadSavedState()
    this.loadSiteNodeFavoriteState()
  }

  build() {
    Stack() {
      PagedListScaffold({
        isLoadingMore: this.vm.isNodeTopicsLoadingMore,
        hasMore: this.vm.nodeTopicsHasMore,
        loadMoreErrorMessage: this.vm.nodeTopicsLoadMoreError,
        loadMoreRetryLabel: AppStrings.text(AppStrings.R_COMMON_RETRY, 'Retry'),
        showFooter: this.vm.nodeTopics.length > 0,
        onRefresh: async () => { await this.refreshData() },
        onReachEnd: () => { this.loadMore() },
        onLoadMoreRetry: () => { this.loadMore() }
      }) {
        if (this.vm.isLoading && this.vm.nodeTopics.length === 0) {
          ListItem() { Column() {}.height(0) }
        } else if (this.vm.errorMessage && this.vm.nodeTopics.length === 0) {
          ListItem() { this.ErrorView() }
        } else if (this.vm.nodeTopics.length === 0) {
          ListItem() { this.EmptyView() }
        } else {
          ForEach(this.vm.nodeTopics, (topic: V2exTopic) => {
            ListItem() {
              TopicCard({
                item: topic,
                isUnread: this.isTopicUnread(topic),
                onUserClick: () => {
                  let p: UserProfileParams = { username: topic.member.username }
                  this.stack.pushPathByName('UserProfile', p as Object)
                }
              })
            }
              .onClick(() => {
                let p: TopicDetailParams = { topicId: topic.id }
                this.stack.pushPathByName('TopicDetail', p as Object)
              })
          })
        }
      }

      if (this.vm.isLoading && this.vm.nodeTopics.length === 0) {
        this.LoadingView()
      }
    }
      .width('100%').height('100%')
      .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }

  @Builder LoadingView() {
    Column() {
      PageLoadingState()
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height('100%')
    .padding({ top: this.topH + ThemeConstants.TITLE_BAR_HEIGHT, bottom: this.bottomH })
    .hitTestBehavior(HitTestMode.None)
  }

  @Builder EmptyView() {
    CardEmptyState({ message: AppStrings.text(AppStrings.R_NODE_NO_TOPICS, 'No topics'), expand: false })
  }

  @Builder ErrorView() {
    PageErrorState({
      message: this.vm.errorMessage || AppStrings.text(AppStrings.R_NODE_LOAD_FAILED, 'Failed to load node topics'),
      expand: false,
      retryAction: () => {
        this.loadData()
      }
    })
  }

  private loadSavedState(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    const nodeName = this.currentNodeName()
    if (!nodeName) {
      this.syncNodeTitleState(false, this.isSiteNodeFavorited)
      return
    }
    CollectionSettings.isNodeSaved(context, nodeName)
      .then((saved: boolean) => {
        this.isNodeSaved = saved
        this.nodeTopicSaved = saved
      })
      .catch((error: Error) => {
        console.error('load saved node state failed: ' + error.message)
      })
  }

  private loadSiteNodeFavoriteState(): void {
    if (this.isSiteNodeFavoriteLoading) {
      return
    }
    const cookie = CookieJarSettings.getCurrentCookie()
    if (!cookie || !this.nodeName) {
      this.isSiteNodeFavorited = false
      this.nodeTopicSiteFavorited = false
      return
    }
    this.isSiteNodeFavoriteLoading = true
    this.api.getNodeFavoriteToggleActionWithCookie(cookie, this.nodeName)
      .then((toggle: V2exToggleAction) => {
        this.isSiteNodeFavorited = toggle.currentlyOn
        this.nodeTopicSiteFavorited = toggle.currentlyOn
      })
      .catch((error: Error) => {
        console.error('load site node favorite state failed: ' + error.message)
      })
      .finally(() => {
        this.isSiteNodeFavoriteLoading = false
      })
  }

  private prepareSiteNodeFavoriteToggle(): void {
    if (this.isSiteNodeFavoriteLoading) {
      return
    }
    const cookie = CookieJarSettings.getCurrentCookie()
    if (!cookie) {
      promptAction.openToast({ message: AppStrings.text($r('app.string.api_error_auth_required'), 'Please sign in') }).catch((_error: Error) => { })
      return
    }
    const cleanName = (this.nodeName || '').trim()
    if (!cleanName) {
      promptAction.openToast({ message: AppStrings.text(AppStrings.R_NODE_INFO_MISSING, 'Node info missing') }).catch((_error: Error) => { })
      return
    }
    this.isSiteNodeFavoriteLoading = true
    this.api.getNodeFavoriteToggleActionWithCookie(cookie, cleanName)
      .then((toggle: V2exToggleAction) => {
        this.isSiteNodeFavorited = toggle.currentlyOn
        this.nodeTopicSiteFavorited = toggle.currentlyOn
        this.confirmSiteNodeFavoriteToggle(cookie, cleanName, toggle)
      })
      .catch((error: Error) => {
        promptAction.openToast({ message: translateApiError(error) }).catch((_error: Error) => { })
      })
      .finally(() => {
        this.isSiteNodeFavoriteLoading = false
      })
  }

  private confirmSiteNodeFavoriteToggle(cookie: string, nodeName: string, toggle: V2exToggleAction): void {
    const title = (this.nodeTitle || this.nodeName || '').trim()
    const verb = this.isSiteNodeFavorited
      ? AppStrings.text(AppStrings.R_SITE_FAVORITE_ACTION_UNFAVORITE, 'Unfavorite')
      : AppStrings.text(AppStrings.R_SITE_FAVORITE_ACTION_FAVORITE, 'Favorite')
    this.getUIContext().showAlertDialog({
      title: AppStrings.text(AppStrings.R_SITE_FAVORITE_TITLE, 'Site Favorite'),
      message: title
        ? AppStrings.format(
            AppStrings.text(AppStrings.R_SITE_FAVORITE_CONFIRM, 'Confirm {0} node "{1}"?'),
            [verb, title]
          )
        : `${verb} this node?`,
      primaryButton: {
        value: AppStrings.text(AppStrings.R_COMMON_CANCEL, 'Cancel'),
        action: () => { }
      },
      secondaryButton: { value: verb, action: () => { this.executeSiteNodeFavoriteToggle(cookie, nodeName, toggle) } }
    })
  }

  private executeSiteNodeFavoriteToggle(cookie: string, nodeName: string, toggle: V2exToggleAction): void {
    if (this.isSiteNodeFavoriteLoading) {
      return
    }
    this.isSiteNodeFavoriteLoading = true
    this.api.executeNodeFavoriteToggleWithCookie(cookie, nodeName, toggle)
      .then((favorited: boolean) => {
        this.isSiteNodeFavorited = favorited
        this.nodeTopicSiteFavorited = favorited
        promptAction.openToast({ message: favorited ? $r('app.string.favorited') : $r('app.string.unfavorited') }).catch((_error: Error) => { })
      })
      .catch((error: Error) => {
        promptAction.openToast({ message: translateApiError(error) }).catch((_error: Error) => { })
      })
      .finally(() => {
        this.isSiteNodeFavoriteLoading = false
      })
  }

  private async refreshData(): Promise<void> {
    await this.loadData()
    this.loadSavedState()
    this.loadSiteNodeFavoriteState()
  }

  private async loadData(): Promise<void> {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    try {
      const snapshot = await AuthSettings.load(context)
      this.token = snapshot.token || ''
      if (this.token) {
        await this.vm.loadNodeDetailV2(this.nodeName, this.token)
        await this.vm.loadNodeTopicsV2(this.nodeName, this.token)
      } else {
        await this.vm.loadNodeDetail(this.nodeName)
        await this.vm.loadNodeTopics(this.nodeName)
      }
      this.syncAppbarIdentity()
    } catch (error) {
      this.token = ''
      this.vm.nodeDetailError = translateApiError(error)
      await this.vm.loadNodeDetail(this.nodeName)
      await this.vm.loadNodeTopics(this.nodeName)
      this.syncAppbarIdentity()
    }
  }

  private loadMore(): void {
    if (this.vm.nodeTopicsUseV2 && this.token) {
      this.vm.loadMoreNodeTopicsV2(this.nodeName, this.token)
        .finally(() => { this.syncAppbarIdentity() })
      return
    }
    this.vm.loadMoreNodeTopics(this.nodeName)
      .finally(() => { this.syncAppbarIdentity() })
  }

  private toggleSavedNode(): void {
    if (this.isSavedNodeLoading) {
      return
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    const nodeName = this.currentNodeName()
    if (!nodeName) {
      promptAction.openToast({ message: AppStrings.text(AppStrings.R_NODE_INFO_MISSING, 'Node info missing') }).catch((_error: Error) => { })
      return
    }
    const node: SavedNode = {
      name: nodeName,
      title: CollectionSettings.cleanNodeTitle(this.vm.nodeDetail?.title || this.nodeTitle || nodeName, this.vm.nodeDetail?.topics || 0),
      topics: this.vm.nodeDetail?.topics || 0,
      avatarMini: this.vm.nodeDetail?.avatar_mini,
      avatarNormal: this.vm.nodeDetail?.avatar_normal,
      avatarLarge: this.vm.nodeDetail?.avatar_large,
      savedAt: Math.floor(Date.now() / 1000)
    }
    this.isSavedNodeLoading = true
    const request = this.isNodeSaved
      ? CollectionSettings.removeNode(context, nodeName)
      : CollectionSettings.saveNode(context, node)
    request
      .then((nodes: SavedNode[]) => {
        this.isNodeSaved = nodes.some((item: SavedNode) => item.name === nodeName)
        this.nodeTopicSaved = this.isNodeSaved
      })
      .catch((error: Error) => {
        console.error('toggle saved node failed: ' + error.message)
      })
      .finally(() => {
        this.isSavedNodeLoading = false
      })
  }

  private isTopicUnread(topic: V2exTopic): boolean {
    if (topic.id <= 0) {
      return false
    }
    const lastTouched = topic.last_touched || topic.last_modified || topic.created
    const state = this.findReadState(topic.id)
    if (!state) {
      return true
    }
    return lastTouched > state.touchedAt
  }

  private findReadState(topicId: number): TopicReadState | null {
    try {
      const parsed = JSON.parse(this.topicReadStates || '[]') as TopicReadState[]
      if (!Array.isArray(parsed)) {
        return null
      }
      for (let i = 0; i < parsed.length; i++) {
        if (parsed[i].id === topicId) {
          return parsed[i]
        }
      }
      return null
    } catch (_e) {
      return null
    }
  }

  onNodeTopicActionCommand(_propName: string): void {
    const raw = (this.nodeTopicActionCommand || '').trim()
    if (!raw) {
      return
    }
    const parts = raw.split(':')
    const action = parts.pop() || ''
    const targetNodeName = parts.length >= 2 ? (parts.pop() || '').trim() : ''
    if (targetNodeName && targetNodeName !== this.currentNodeName()) {
      return
    }
    if (action === 'siteFavorite') {
      this.prepareSiteNodeFavoriteToggle()
    } else if (action === 'saveNode') {
      this.toggleSavedNode()
    }
  }

  private currentNodeName(): string {
    return (this.nodeName || this.vm.nodeDetail?.name || '').trim()
  }

  private syncNodeTitleState(saved: boolean, siteFavorited: boolean): void {
    this.isNodeSaved = saved
    this.isSiteNodeFavorited = siteFavorited
    this.nodeTopicSaved = saved
    this.nodeTopicSiteFavorited = siteFavorited
  }

  private syncAppbarIdentity(): void {
    this.nodeTopicTitle = CollectionSettings.cleanNodeTitle(this.vm.nodeDetail?.title || this.nodeTitle || this.nodeName, this.vm.nodeDetail?.topics || 0)
    const identityName = (this.nodeName || '').trim()
    const subtitleParts: string[] = []
    if (this.nodeTopicTitle && identityName && this.nodeTopicTitle !== identityName) {
      subtitleParts.push(identityName)
    }
    const topicCount = this.vm.nodeDetail?.topics || 0
    if (topicCount > 0) {
      subtitleParts.push(AppStrings.format(
        AppStrings.text(AppStrings.R_NODE_TOPICS_COUNT, '{0} topics'),
        [String(topicCount)]
      ))
    }
    this.nodeTopicSubtitle = subtitleParts.join(' · ')
  }
}
