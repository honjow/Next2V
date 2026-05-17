import { UserRepliesViewModel } from '../viewmodel/UserViewModel'
import {
  CardEmptyState, NodeTopicListParams, PageErrorState, PageLoadingState,
  SecondaryListScaffold, StorageKeys, TopicDetailParams, UserProfileParams, V2exRoute,
  V2exUrlRouter, V2exUserReply
} from 'shared'
import { common, Want } from '@kit.AbilityKit'
import { UserRepliesCard } from '../components/UserRepliesComponents'

@Component
export struct UserRepliesPage {
  @Prop username: string = ''
  @Consume('ns') stack: NavPathStack
  @State vm: UserRepliesViewModel = new UserRepliesViewModel(this.username)

  aboutToAppear(): void { this.vm.load() }

  build() {
    Column() {
      if (this.vm.isLoading && this.vm.replyDataSource.totalCount() === 0) {
        PageLoadingState()
      } else if (this.vm.errorMessage && this.vm.replyDataSource.totalCount() === 0) {
        PageErrorState({
          message: this.vm.errorMessage || '加载失败',
          retryAction: () => {
            this.vm.load()
          }
        })
      } else if (this.vm.replyDataSource.totalCount() === 0) {
        CardEmptyState({ message: '暂无回复' })
      } else {
        SecondaryListScaffold({
          onReachEnd: () => {
            this.vm.loadMore()
          }
        }) {
          LazyForEach(this.vm.replyDataSource, (reply: V2exUserReply) => {
            ListItem() {
              this.ReplyItem(reply)
            }
            .onClick(() => {
              let p: TopicDetailParams = { topicId: reply.topic_id, targetFloor: reply.target_floor }
              this.stack.pushPathByName('TopicDetail', p as Object)
            })
          }, (reply: V2exUserReply) => `${reply.topic_id}-${reply.target_floor}-${reply.created}`)

          if (this.vm.isLoadingMore) {
            ListItem() {
              PageLoadingState({ stateHeight: 80, expand: false })
            }
          }
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }

  @Builder ReplyItem(reply: V2exUserReply) {
    UserRepliesCard({
      reply: reply,
      fallbackUsername: this.username,
      openLink: (url: string) => { this.openContentLink(url) },
      openMention: (username: string) => { this.openUserProfile(username) }
    })
  }

  private openUserProfile(username: string): void {
    const clean = (username || '').trim()
    if (!clean) {
      return
    }
    let p: UserProfileParams = { username: clean }
    this.stack.pushPathByName('UserProfile', p as Object)
  }

  private openContentLink(url: string): void {
    const clean = (url || '').trim()
    const route = V2exUrlRouter.parse(clean)
    if (route) {
      this.openV2exRoute(route)
      return
    }
    this.openInSystemBrowser(clean)
  }

  private openV2exRoute(route: V2exRoute): void {
    if (route.kind === 'topic' && route.topicId && route.topicId > 0) {
      const p: TopicDetailParams = route.targetFloor && route.targetFloor > 0
        ? { topicId: route.topicId, targetFloor: route.targetFloor }
        : { topicId: route.topicId }
      this.stack.pushPathByName('TopicDetail', p as Object)
      return
    }
    if (route.kind === 'member' && route.username) {
      this.openUserProfile(route.username)
      return
    }
    if (route.kind === 'node' && route.nodeName) {
      const p: NodeTopicListParams = { nodeName: route.nodeName, nodeTitle: route.nodeName }
      this.stack.pushPathByName('NodeTopicList', p as Object)
      return
    }
    if (route.kind === 'search' && route.query) {
      AppStorage.setOrCreate<string>(StorageKeys.PENDING_SEARCH_QUERY, `${Date.now()}:${route.query}`)
      this.stack.pushPathByName('Search', null)
    }
  }

  private openInSystemBrowser(url: string): void {
    const target = (url || '').trim()
    if (!target) {
      return
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    const want: Want = { action: 'ohos.want.action.viewData', uri: target }
    context.startAbility(want).catch((_error: Error) => { })
  }
}
