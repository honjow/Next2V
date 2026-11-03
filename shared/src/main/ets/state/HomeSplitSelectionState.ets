import { AppStorageV2 } from '@kit.ArkUI'

/**
 * Which topic the large-screen split currently shows in the right pane. The feed reads it to tint the
 * selected card and to ignore a repeat tap on that same topic: every tap pushes a new TopicDetail
 * destination, so tapping the already-open topic re-mounted the detail and made the right pane flash.
 *
 * The feed selects optimistically before pushing. The root navigation updates this state when a
 * destination is shown, since hidden destinations can remain mounted in the navigation stack.
 * The transparent image preview preserves the selection of the visible page underneath.
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

export function clearHomeSplitSelection(): void {
  connectHomeSplitSelection().selectedTopicId = 0
}
