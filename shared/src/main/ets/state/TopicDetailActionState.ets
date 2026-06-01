import { AppStorageV2 } from '@kit.ArkUI'

/**
 * V2 command bus for the topic-detail appbar (`'v2:topicDetailAction'`).
 *
 * One-directional bus: the (now `@ComponentV2`) `Index.sendTopicAction` writes a
 * `<ts>:<topicId>:<action>` string (timestamp-tagged so a repeated action still fires) for the
 * topic-detail title-bar menu, and the matching live `@ComponentV2` `TopicDetailPage` reacts via
 * `@Monitor('<member>.command')`, filtering by its own topicId so stacked pages don't double-fire.
 *
 * Replaces the former V1 `TopicDetailActionListener` zero-size child adapter: with Index migrated to
 * V2 it writes this `@Trace` mirror directly, so the page observes the bus without a V1 host. The legacy
 * `AppStorage` (`topicDetailAction`) key + its dual-write were retired once no reader read the V1 half.
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
