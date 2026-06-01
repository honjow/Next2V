import { AppStorageV2 } from '@kit.ArkUI'

/**
 * V2 mirror of the node-topic appbar state `NodeTopicPage` reports UP to the `Index` title bar
 * (`saved` / `siteFavorited` action-icon flags + `title` / `subtitle`).
 *
 * Writers route through the `publish*` helpers (pure V2: they set the `@Trace` field only); the migrated
 * `@ComponentV2` `Index` reads the `@Trace` fields in its node-topic title-bar builder. The legacy V1
 * `AppStorage` half (`NODE_TOPIC_{SAVED,SITE_FAVORITED,TITLE,SUBTITLE}`) was retired once NodeTopicPage no
 * longer read any of those keys back — Index is the only consumer and it reads this mirror.
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
  connectNodeTopicAppbar().saved = value
}
export function publishNodeTopicSiteFavorited(value: boolean): void {
  connectNodeTopicAppbar().siteFavorited = value
}
export function publishNodeTopicTitle(value: string): void {
  connectNodeTopicAppbar().title = value
}
export function publishNodeTopicSubtitle(value: string): void {
  connectNodeTopicAppbar().subtitle = value
}
