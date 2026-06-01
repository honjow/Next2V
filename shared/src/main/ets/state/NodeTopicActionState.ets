import { AppStorageV2 } from '@kit.ArkUI'

/**
 * V2 command bus for the node-topic appbar (`'v2:nodeTopicAction'`).
 *
 * The command is a one-directional bus: the `@ComponentV2` `Index.ets` node-topic title-bar menu writes a
 * `<token>:<nodeName>:<action>` string (`Index.sendNodeTopicAction`, the single writer) for the
 * site-favorite / save-node menu items, and `NodeTopicPage` reacts to run the matching toggle.
 * There is no writeback on this command — the page reports its appbar state (saved / favorited / title /
 * subtitle) back to Index through the `NodeTopicAppbarState` mirror.
 *
 * A `@ComponentV2` consumer holds the singleton and runs the action via
 * `@Monitor('<member>.command')` when it changes. The legacy V1 `AppStorage` (`nodeTopicAction`) key +
 * its dual-write were retired once no reader read the V1 half.
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
