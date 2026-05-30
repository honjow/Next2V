import { AppStorageV2 } from '@kit.ArkUI'

/**
 * V2 mirror of the node-topic appbar command (`StorageKeys.NODE_TOPIC_ACTION`).
 *
 * The command is a one-directional bus: the V1 `Index.ets` node-topic title-bar menu writes a
 * `<token>:<nodeName>:<action>` string (`Index.sendNodeTopicAction`, the single writer) for the
 * site-favorite / save-node menu items, and `NodeTopicPage` reacts to run the matching toggle.
 * There is no writeback on this key — the page reports its appbar state (saved / favorited / title /
 * subtitle) back to Index through the other NODE_TOPIC_* keys, which Index still reads V1-style.
 *
 * During the State Management V1->V2 migration the command lives in BOTH stores at once: the writer
 * dual-writes the V1 `AppStorage` key AND this `@Trace` field so the bridge stays uniform and
 * reversible, mirroring the `ImagePreviewActionState` precedent.
 *
 * A `@ComponentV2` consumer holds the singleton and runs the action via
 * `@Monitor('<member>.command')` when it changes.
 *
 * Transitional: drop the `AppStorage` half once the writer no longer needs it.
 */
@ObservedV2
export class NodeTopicActionState {
  @Trace command: string = ''
}

const NODE_TOPIC_ACTION_V2_KEY: string = 'v2:nodeTopicAction'

/** Returns the app-wide NodeTopicActionState singleton from AppStorageV2. */
export function connectNodeTopicAction(): NodeTopicActionState {
  return AppStorageV2.connect(NodeTopicActionState, NODE_TOPIC_ACTION_V2_KEY, () => new NodeTopicActionState())!
}
