import { AppStorageV2 } from '@kit.ArkUI'

/**
 * Bridge between the live `TopicEditorPage` and the `Index` title bar so the editor's Submit action can
 * live in the title-bar (icon) menu instead of a bottom button.
 *
 * - `TopicEditorAppbarState` (`'v2:topicEditorAppbar'`): editor -> Index. The page publishes whether
 *   Submit is currently allowed (`canSubmit()`, which already factors in `isSubmitting`); `Index` reads
 *   the `@Trace submitEnabled` in its title-bar builder so the icon's enabled state updates reactively.
 * - `TopicEditorActionState` (`'v2:topicEditorAction'`): Index -> editor. The title-bar icon writes a
 *   timestamp-tagged `command` (so a repeated tap still fires); the page reacts via `@Monitor`.
 */
@ObservedV2
export class TopicEditorAppbarState {
  @Trace submitEnabled: boolean = false
}

const TOPIC_EDITOR_APPBAR_V2_KEY: string = 'v2:topicEditorAppbar'

export function connectTopicEditorAppbar(): TopicEditorAppbarState {
  return AppStorageV2.connect(TopicEditorAppbarState, TOPIC_EDITOR_APPBAR_V2_KEY, () => new TopicEditorAppbarState())!
}

export function publishTopicEditorSubmitEnabled(value: boolean): void {
  connectTopicEditorAppbar().submitEnabled = value
}

@ObservedV2
export class TopicEditorActionState {
  @Trace command: string = ''
}

const TOPIC_EDITOR_ACTION_V2_KEY: string = 'v2:topicEditorAction'

export function connectTopicEditorAction(): TopicEditorActionState {
  return AppStorageV2.connect(TopicEditorActionState, TOPIC_EDITOR_ACTION_V2_KEY, () => new TopicEditorActionState())!
}

/** Title bar -> page: fire the Submit command (timestamp-tagged so repeated taps still trigger). */
export function sendTopicEditorSubmit(): void {
  connectTopicEditorAction().command = `${Date.now()}`
}
