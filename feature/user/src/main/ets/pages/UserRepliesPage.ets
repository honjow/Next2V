import { UserRepliesViewModel } from '../viewmodel/UserViewModel'
import {
  AppStrings, CardEmptyState, connectNavStack, NodeTopicListParams, PageErrorState, PageLoadingState,
  SearchQueryBus, SecondaryListScaffold, TopicDetailParams, UserProfileParams, ImagePreviewParams, V2exRoute,
  V2exUrlRouter, V2exUserReply, connectImageHero, heroIdForUrl, MediaUrlUtils
} from 'shared'
import { common, Want } from '@kit.AbilityKit'
import { UserRepliesCard } from '../components/UserRepliesComponents'

@ComponentV2
export struct UserRepliesPage {
  @Param username: string = ''
  // Same NavPathStack instance HdsNavigation is bound to (see NavStackHolder).
  // Used purely as a method target (pushPathByName), so no V2 reactivity is needed.
  private stack: NavPathStack = connectNavStack().stack
  @Local vm: UserRepliesViewModel = new UserRepliesViewModel(this.username)

  aboutToAppear(): void { this.vm.load() }

  build() {
    Column() {
      if (this.vm.isLoading && this.vm.replyDataSource.totalCount() === 0) {
        PageLoadingState()
      } else if (this.vm.errorMessage && this.vm.replyDataSource.totalCount() === 0) {
        PageErrorState({
          message: this.vm.errorMessage || AppStrings.text(AppStrings.R_COMMON_LOAD_FAILED, 'Load failed'),
          retryAction: () => {
            this.vm.load()
          }
        })
      } else if (this.vm.replyDataSource.totalCount() === 0) {
        CardEmptyState({ message: AppStrings.text(AppStrings.R_USER_PROFILE_NO_REPLIES, 'No replies') })
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
          }, (reply: V2exUserReply) => this.replyStableKey(reply))

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
      openTopic: () => { this.openReplyTopic(reply) },
      openLink: (url: string) => { this.openContentLink(url) },
      openImage: (url: string) => { this.openImagePreview(url) },
      openMention: (username: string) => { this.openUserProfile(username) }
    })
  }

  private openReplyTopic(reply: V2exUserReply): void {
    if (!reply || reply.topic_id <= 0) {
      return
    }
    const p: TopicDetailParams = reply.target_floor && reply.target_floor > 0
      ? { topicId: reply.topic_id, targetFloor: reply.target_floor }
      : { topicId: reply.topic_id }
    this.stack.pushPathByName('TopicDetail', p as Object)
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

  private openImagePreview(url: string): void {
    const normalized = (url || '').trim()
    if (!normalized) {
      return
    }
    // Arm the shared-element (Hero) binding for the tapped image BEFORE the push, so the source thumbnail's
    // geometryTransition id matches the preview's; Index clears it in onHidden after the preview closes.
    connectImageHero().activeId = heroIdForUrl(MediaUrlUtils.normalizeUrl(normalized))
    let p: ImagePreviewParams = { url: normalized }
    // Push INSIDE animateTo (animated=false suppresses the HDS default route animation) so the route mount
    // happens in this window — that is what drives the shared-element (Hero) geometryTransition morph.
    this.getUIContext().animateTo({ duration: 300, curve: Curve.Friction }, () => {
      this.stack.pushPathByName('ImagePreview', p as Object, false)
    })
  }

  private replyStableKey(reply: V2exUserReply): string {
    const parsedKey = (reply.reply_key || '').trim()
    if (parsedKey) {
      return parsedKey
    }
    return `${reply.topic_id}-${reply.target_floor}-${reply.created}-${reply.created_text || ''}-${reply.topic_title}-${reply.content}`
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
      SearchQueryBus.publishPending(route.query)
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
