import { AppStorageV2 } from '@kit.ArkUI'

/**
 * One-directional command bus for "a node was picked in NodePickerPage".
 *
 * NodePickerPage is the single writer: on select it calls `publishNodePick`, which stamps `command`
 * (a timestamp string, so a repeat pick of the same node still refires) and writes the chosen node's
 * `name`/`title`. The
 * `@ComponentV2` TopicEditorPage is the sole consumer — it reacts via `@Monitor('nodePick.command')`
 * to fill its node field and persist the draft. This replaces the previous "write node into the
 * draft then pop" channel, which never refreshed the already-mounted editor (aboutToAppear does not
 * re-run on pop), so the picked node never appeared. There is no writeback on any field.
 */
@ObservedV2
export class NodePickActionState {
  @Trace command: string = ''
  @Trace name: string = ''
  @Trace title: string = ''
}

const NODE_PICK_ACTION_V2_KEY: string = 'v2:nodePickAction'

/** Returns the app-wide NodePickActionState singleton from AppStorageV2. */
export function connectNodePickAction(): NodePickActionState {
  return AppStorageV2.connect(
    NodePickActionState,
    NODE_PICK_ACTION_V2_KEY,
    () => new NodePickActionState(),
  )!
}

/**
 * Single writer of the node-pick command bus. Stamps a unique `command` (timestamp string) so a
 * repeat pick of the same node still refires the consumer's `@Monitor`, alongside the chosen
 * name/title. Centralised here so the `@ComponentV2` NodePickerPage leaf stays free of the
 * `Date.now()` token the V2 leaf-migration contract forbids inside migrated files.
 */
export function publishNodePick(name: string, title: string): void {
  const clean = (name || '').trim()
  if (!clean) {
    return
  }
  const bus = connectNodePickAction()
  bus.name = clean
  bus.title = (title || '').trim()
  bus.command = `${Date.now()}`
}
