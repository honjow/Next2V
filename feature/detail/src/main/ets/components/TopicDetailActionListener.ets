import { StorageKeys } from 'shared'
import { TopicDetailActionCoordinator } from '../model/TopicDetailActionCoordinator'

/**
 * V1 @Component adapter that owns the topic-detail appbar command bus for the (now `@ComponentV2`)
 * `TopicDetailPage`.
 *
 * Why this stays V1 while its parent is `@ComponentV2`: the command is a one-directional bus —
 * `Index.sendTopicAction` writes a `<ts>:<topicId>:<action>` string into `AppStorage`
 * (`StorageKeys.TOPIC_DETAIL_ACTION`, timestamp-tagged so a repeated action still fires) and the
 * matching live page reacts. A `@ComponentV2` cannot reactively observe a V1 `AppStorage` key
 * (`SubscribedAbstractProperty` exposes no change callback), and the codebase's mirror+dual-write
 * fix would require editing `Index.sendTopicAction`, which this lane must not touch. So the V1-only
 * `@StorageLink` + `@Watch` subscription lives entirely inside this tiny adapter, which the page
 * hosts as a zero-size child and which reports up through a plain `onCommand` callback (legal across
 * the V2-parent -> V1-child boundary). This mirrors the `UserProfileActivityTabs` /
 * `BlockedListsTabsSegment` adapter precedent and leaves Index untouched.
 *
 * The `topicId` filter is essential: without it the global `AppStorage` watch broadcasts the action
 * to every live `TopicDetailPage` in the nav stack (top and underneath), firing duplicate dialogs.
 */
@Component
export struct TopicDetailActionListener {
  @Prop topicId: number = 0;
  onCommand?: (action: string) => void;
  @StorageLink(StorageKeys.TOPIC_DETAIL_ACTION)
  @Watch('onTopicActionCommand')
  private topicActionCommand: string = '';

  private onTopicActionCommand(_propName: string): void {
    const command = TopicDetailActionCoordinator.parseCommand(this.topicActionCommand)
    if (!command || command.topicId !== this.topicId) {
      return
    }
    if (this.onCommand) {
      this.onCommand(command.action)
    }
  }

  build() {
    // Zero-size, non-interactive host: exists only to keep the @StorageLink subscription alive
    // for as long as the owning page is mounted in the nav stack.
    Stack() {}
      .width(0)
      .height(0)
      .hitTestBehavior(HitTestMode.None)
  }
}
