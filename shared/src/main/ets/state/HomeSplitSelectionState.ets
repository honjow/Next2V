import { AppStorageV2 } from '@kit.ArkUI'

/**
 * Which topic the large-screen split currently shows in the right pane. The feed reads it to tint the
 * selected card and to ignore a repeat tap on that same topic: every tap pushes a new TopicDetail
 * destination, so tapping the already-open topic re-mounted the detail and made the right pane flash.
 *
 * Writers: the feed tap (optimistic, before the push) and TopicDetailPage (confirm on appear, release
 * on disappear only while it still owns the selection, so switching topics is order-safe).
 */
@ObservedV2
export class HomeSplitSelectionState {
  @Trace selectedTopicId: number = 0
}

const HOME_SPLIT_SELECTION_KEY: string = 'v2:homeSplitSelection'

export function connectHomeSplitSelection(): HomeSplitSelectionState {
  return AppStorageV2.connect(
    HomeSplitSelectionState,
    HOME_SPLIT_SELECTION_KEY,
    () => new HomeSplitSelectionState(),
  )!
}

export function selectHomeSplitTopic(topicId: number): void {
  connectHomeSplitSelection().selectedTopicId = topicId
}

/** Clears only when the given topic is still the selected one (a newer selection wins). */
export function releaseHomeSplitTopic(topicId: number): void {
  const state = connectHomeSplitSelection()
  if (state.selectedTopicId === topicId) {
    state.selectedTopicId = 0
  }
}

export function clearHomeSplitSelection(): void {
  connectHomeSplitSelection().selectedTopicId = 0
}
