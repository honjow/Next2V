import { AppStorageV2 } from '@kit.ArkUI'

/**
 * V2 mirror of the per-topic read-state ledger.
 *
 * The read states historically live in V1 `AppStorage` (`StorageKeys.TOPIC_READ_STATES`,
 * a JSON-encoded `TopicReadState[]` string) written ONLY by `LocalDataPublisher`
 * (publish/clear) and read by several pages to decide a topic's unread dot. During the
 * State Management V1->V2 migration the ledger lives in BOTH stores at once: V1
 * `@StorageLink` readers (HomePage / UserProfilePage / NodeTopicPage) keep reading
 * `AppStorage`, while `@ComponentV2` readers read this `@Trace` field. `LocalDataPublisher`
 * is the single writer and dual-writes both, so the two stores never diverge.
 *
 * Reading `statesJson` inside a `@ComponentV2` `build()` subscribes that component to
 * read-state changes (e.g. unread dots refresh after a topic is opened).
 *
 * Transitional: drop the `AppStorage` half once every reader has moved to V2.
 */
@ObservedV2
export class TopicReadStatesState {
  @Trace statesJson: string = '[]'
}

const TOPIC_READ_STATES_V2_KEY: string = 'v2:topicReadStates'

/** Returns the app-wide TopicReadStatesState singleton from AppStorageV2. */
export function connectTopicReadStates(): TopicReadStatesState {
  return AppStorageV2.connect(TopicReadStatesState, TOPIC_READ_STATES_V2_KEY, () => new TopicReadStatesState())!
}
