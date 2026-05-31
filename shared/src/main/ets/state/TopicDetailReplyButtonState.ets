import { AppStorageV2 } from '@kit.ArkUI'

/**
 * V2 mirror of the topic-detail floating reply button auto-hide preference
 * (`StorageKeys.TOPIC_DETAIL_REPLY_BUTTON_AUTO_HIDE`).
 *
 * `TopicDetailReplyActionSettings.apply` is the single AppStorage writer (load / save both route
 * through it). During the State Management V1->V2 backbone migration it dual-writes: the legacy
 * `AppStorage` key (still read by the V1 `SettingsPage` toggle) AND this `@Trace` field (read by
 * `@ComponentV2` `TopicDetailPage`), so the two stores never diverge.
 *
 * A `@ComponentV2` consumer re-binds its scroller via `@Monitor('<member>.autoHide')` when the
 * preference flips. Transitional — drop the `AppStorage` half once every reader is V2.
 */
@ObservedV2
export class TopicDetailReplyButtonState {
  // Default mirrors TopicDetailReplyActionSettings.DEFAULT_AUTO_HIDE (true).
  @Trace autoHide: boolean = true
}

const TOPIC_DETAIL_REPLY_BUTTON_V2_KEY: string = 'v2:topicDetailReplyButtonAutoHide'

/** Returns the app-wide TopicDetailReplyButtonState singleton from AppStorageV2. */
export function connectTopicDetailReplyButton(): TopicDetailReplyButtonState {
  return AppStorageV2.connect(
    TopicDetailReplyButtonState,
    TOPIC_DETAIL_REPLY_BUTTON_V2_KEY,
    () => new TopicDetailReplyButtonState(),
  )!
}
