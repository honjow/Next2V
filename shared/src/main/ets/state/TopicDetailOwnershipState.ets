import { AppStorageV2 } from '@kit.ArkUI'

// V2EX gates topic edit / append purely on seconds since topic.created, and the two windows do NOT abut:
//   0–600s   : the author can EDIT (title/body/node/syntax)
//   600–1800s: dead zone — neither edit nor append
//   ≥1800s   : the author can only APPEND (附言), max 3, ≥20 铜币/千字
// These are the live-rule values (600s confirmed current; 300s is a legacy figure). Kept as named
// constants so a future rule change is a one-line edit. The client timer is only a UX pre-filter — the
// server form fetch is the real gate (an out-of-window action simply fails server-side).
export const TOPIC_EDIT_WINDOW_SEC: number = 600
export const TOPIC_APPEND_UNLOCK_SEC: number = 1800

/**
 * Reactive ownership + time-phase for the topic currently drawn in the detail title bar. Lets the
 * title-bar overflow menu show 编辑/附言 only when the signed-in user is the OP and the topic is in the
 * right time window. `routeTopicId` is the identity gate (the holder is a shared singleton across the
 * stacked detail pages) — readers honour the fields only when `routeTopicId` matches their topic id.
 * Single writer: only `publishTopicDetailOwnership` mutates these fields.
 */
@ObservedV2
export class TopicDetailOwnershipState {
  @Trace routeTopicId: number = 0
  @Trace isCurrentUserOp: boolean = false
  @Trace createdEpochSec: number = 0
  @Trace canEdit: boolean = false
  @Trace canAppend: boolean = false
}

const TOPIC_DETAIL_OWNERSHIP_KEY: string = 'v2:topicDetailOwnership'

export function connectTopicDetailOwnership(): TopicDetailOwnershipState {
  return AppStorageV2.connect(
    TopicDetailOwnershipState,
    TOPIC_DETAIL_OWNERSHIP_KEY,
    () => new TopicDetailOwnershipState(),
  )!
}

export function publishTopicDetailOwnership(
  topicId: number,
  isCurrentUserOp: boolean,
  createdEpochSec: number,
): void {
  const state = connectTopicDetailOwnership()
  state.routeTopicId = topicId
  state.isCurrentUserOp = isCurrentUserOp
  state.createdEpochSec = createdEpochSec
  const ageSec = Math.floor(Date.now() / 1000) - createdEpochSec
  const hasCreated = createdEpochSec > 0
  state.canEdit = isCurrentUserOp && hasCreated && ageSec >= 0 && ageSec < TOPIC_EDIT_WINDOW_SEC
  state.canAppend = isCurrentUserOp && hasCreated && ageSec >= TOPIC_APPEND_UNLOCK_SEC
}

export function clearTopicDetailOwnership(): void {
  const state = connectTopicDetailOwnership()
  state.routeTopicId = 0
  state.isCurrentUserOp = false
  state.createdEpochSec = 0
  state.canEdit = false
  state.canAppend = false
}
