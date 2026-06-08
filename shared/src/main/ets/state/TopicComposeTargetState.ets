import { AppStorageV2 } from '@kit.ArkUI'

/**
 * Carries what the shared TopicEditorPage should compose when it opens: a brand-new topic ('create'),
 * a 附言(append) on an existing topic ('append'), or an in-place 'edit' of an existing topic — the last
 * two carry the target topicId. Every push to the 'TopicEditor' route sets this first (Home compose →
 * create; the detail-page 附言/编辑 actions → append/edit), so a stale value can't leak between the
 * entry points. Read once in TopicEditorPage.aboutToAppear.
 */
@ObservedV2
export class TopicComposeTargetState {
  @Trace mode: string = 'create'
  @Trace topicId: number = 0
}

const TOPIC_COMPOSE_TARGET_KEY: string = 'v2:topicComposeTarget'

export function connectTopicComposeTarget(): TopicComposeTargetState {
  return AppStorageV2.connect(
    TopicComposeTargetState,
    TOPIC_COMPOSE_TARGET_KEY,
    () => new TopicComposeTargetState(),
  )!
}

export function publishTopicComposeTarget(mode: string, topicId: number): void {
  const state = connectTopicComposeTarget()
  state.mode = mode === 'append' || mode === 'edit' ? mode : 'create'
  state.topicId = topicId > 0 ? topicId : 0
}
