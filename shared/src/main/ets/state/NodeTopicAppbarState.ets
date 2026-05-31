import { AppStorageV2 } from '@kit.ArkUI'
import { StorageKeys } from '../constants/StorageKeys'

/**
 * V2 mirror of the node-topic appbar state `NodeTopicPage` reports UP to the `Index` title bar
 * (`NODE_TOPIC_SAVED` / `SITE_FAVORITED` action-icon flags + `NODE_TOPIC_TITLE` / `SUBTITLE`).
 *
 * Writers route through the `publish*` helpers (write-through: AppStorage + mirror) so the V1 keys and
 * this `@Trace` mirror never drift; the migrated `@ComponentV2` `Index` reads the `@Trace` fields in its
 * node-topic title-bar builder. Transitional: drop the AppStorage half once no V1 `@StorageLink` reads
 * these keys.
 */
@ObservedV2
export class NodeTopicAppbarState {
  @Trace saved: boolean = false
  @Trace siteFavorited: boolean = false
  @Trace title: string = ''
  @Trace subtitle: string = ''
}

const NODE_TOPIC_APPBAR_V2_KEY: string = 'v2:nodeTopicAppbar'

/** Returns the app-wide NodeTopicAppbarState singleton from AppStorageV2. */
export function connectNodeTopicAppbar(): NodeTopicAppbarState {
  return AppStorageV2.connect(NodeTopicAppbarState, NODE_TOPIC_APPBAR_V2_KEY, () => new NodeTopicAppbarState())!
}

export function publishNodeTopicSaved(value: boolean): void {
  AppStorage.setOrCreate<boolean>(StorageKeys.NODE_TOPIC_SAVED, value)
  connectNodeTopicAppbar().saved = value
}
export function publishNodeTopicSiteFavorited(value: boolean): void {
  AppStorage.setOrCreate<boolean>(StorageKeys.NODE_TOPIC_SITE_FAVORITED, value)
  connectNodeTopicAppbar().siteFavorited = value
}
export function publishNodeTopicTitle(value: string): void {
  AppStorage.setOrCreate<string>(StorageKeys.NODE_TOPIC_TITLE, value)
  connectNodeTopicAppbar().title = value
}
export function publishNodeTopicSubtitle(value: string): void {
  AppStorage.setOrCreate<string>(StorageKeys.NODE_TOPIC_SUBTITLE, value)
  connectNodeTopicAppbar().subtitle = value
}
