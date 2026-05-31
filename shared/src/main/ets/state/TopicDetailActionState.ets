import { AppStorageV2 } from '@kit.ArkUI'

/**
 * V2 mirror of the topic-detail appbar command bus (`StorageKeys.TOPIC_DETAIL_ACTION`).
 *
 * One-directional bus: the (now `@ComponentV2`) `Index.sendTopicAction` writes a
 * `<ts>:<topicId>:<action>` string (timestamp-tagged so a repeated action still fires) for the
 * topic-detail title-bar menu, and the matching live `@ComponentV2` `TopicDetailPage` reacts via
 * `@Monitor('<member>.command')`, filtering by its own topicId so stacked pages don't double-fire.
 *
 * Replaces the former V1 `TopicDetailActionListener` zero-size child adapter: with Index migrated to
 * V2 it now dual-writes this `@Trace` mirror alongside the legacy `AppStorage` key, so the page can
 * observe the bus directly without a V1 host. Transitional: drop the AppStorage half once no V1 reader
 * remains.
 */
@ObservedV2
export class TopicDetailActionState {
  @Trace command: string = ''
}

const TOPIC_DETAIL_ACTION_V2_KEY: string = 'v2:topicDetailAction'

/** Returns the app-wide TopicDetailActionState singleton from AppStorageV2. */
export function connectTopicDetailAction(): TopicDetailActionState {
  return AppStorageV2.connect(TopicDetailActionState, TOPIC_DETAIL_ACTION_V2_KEY, () => new TopicDetailActionState())!
}
