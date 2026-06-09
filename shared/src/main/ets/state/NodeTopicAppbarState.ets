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
  // Whether this node is in the device-global local ignore set (see [[IgnoredNodesState]]). NodeTopicPage
  // is the sole writer; Index reads it to label the overflow menu item (忽略 / 取消忽略此节点).
  @Trace ignored: boolean = false
  @Trace title: string = ''
  @Trace subtitle: string = ''
  // Scroll-reveal appbar identity (mirrors the user-profile pattern): once the node-info card's name
  // scrolls under the overlaid title bar, NodeTopicPage publishes the node name + icon here so Index
  // renders an icon+name title (via a ComponentContent), and clears them when the card is back in view.
  // Keyed by routeNodeName so stacked NodeTopic pages each own their entry.
  @Trace titleNodeName: string = ''
  @Trace titleNodeAvatarUrl: string = ''
  @Trace titleRouteNodeName: string = ''
  @Trace titleNameStates: string = '{}'
  @Trace titleAvatarStates: string = '{}'
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
export function publishNodeTopicIgnored(value: boolean): void {
  connectNodeTopicAppbar().ignored = value
}
export function publishNodeTopicTitle(value: string): void {
  connectNodeTopicAppbar().title = value
}
export function publishNodeTopicSubtitle(value: string): void {
  connectNodeTopicAppbar().subtitle = value
}
export function publishNodeTopicAppbarTitleNodeName(value: string): void {
  connectNodeTopicAppbar().titleNodeName = value
}
export function publishNodeTopicAppbarTitleNodeAvatarUrl(value: string): void {
  connectNodeTopicAppbar().titleNodeAvatarUrl = value
}
export function publishNodeTopicAppbarTitleRouteNodeName(value: string): void {
  connectNodeTopicAppbar().titleRouteNodeName = value
}
export function publishNodeTopicAppbarTitleNameStates(value: string): void {
  connectNodeTopicAppbar().titleNameStates = value
}
export function publishNodeTopicAppbarTitleAvatarStates(value: string): void {
  connectNodeTopicAppbar().titleAvatarStates = value
}
