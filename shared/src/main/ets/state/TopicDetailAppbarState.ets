import { AppStorageV2 } from '@kit.ArkUI'

/**
 * V2 mirror of the topic-detail appbar state that `TopicDetailPage` reports UP to the `Index` title bar
 * (the `savedLater` / `siteFavorited` / `thanked` action-icon flags plus the appbar identity strings).
 *
 * These fields are written by `TopicDetailPage` in many scattered action/rollback sites; every writer
 * routes through the `publish*` helpers below so the single `@Trace` mirror stays authoritative. The
 * migrated `@ComponentV2` `Index` reads the `@Trace` fields in its title-bar builders so the appbar
 * re-renders reactively as the topic loads / the user toggles thank/favorite/save. `TopicDetailPage`
 * reads back the per-route `*States` ledgers and the `thanked` flag from this same mirror.
 *
 * V2-only: the legacy `AppStorage` half was retired once every reader moved to this mirror.
 */
@ObservedV2
export class TopicDetailAppbarState {
  @Trace savedLater: boolean = false
  @Trace siteFavorited: boolean = false
  @Trace thanked: boolean = false
  @Trace title: string = ''
  @Trace avatarUrl: string = ''
  @Trace username: string = ''
  @Trace routeTopicId: string = ''
  @Trace titleStates: string = '{}'
  @Trace avatarStates: string = '{}'
  @Trace usernameStates: string = '{}'
}

const TOPIC_DETAIL_APPBAR_V2_KEY: string = 'v2:topicDetailAppbar'

/** Returns the app-wide TopicDetailAppbarState singleton from AppStorageV2. */
export function connectTopicDetailAppbar(): TopicDetailAppbarState {
  return AppStorageV2.connect(TopicDetailAppbarState, TOPIC_DETAIL_APPBAR_V2_KEY, () => new TopicDetailAppbarState())!
}

// Single-writer helpers: every TopicDetailPage write funnels through these so the @Trace mirror the
// @ComponentV2 Index appbar reads stays authoritative.
export function publishTopicDetailSavedLater(value: boolean): void {
  connectTopicDetailAppbar().savedLater = value
}
export function publishTopicDetailSiteFavorited(value: boolean): void {
  connectTopicDetailAppbar().siteFavorited = value
}
export function publishTopicDetailThanked(value: boolean): void {
  connectTopicDetailAppbar().thanked = value
}
export function publishTopicDetailAppbarTitle(value: string): void {
  connectTopicDetailAppbar().title = value
}
export function publishTopicDetailAppbarAvatarUrl(value: string): void {
  connectTopicDetailAppbar().avatarUrl = value
}
export function publishTopicDetailAppbarUsername(value: string): void {
  connectTopicDetailAppbar().username = value
}
export function publishTopicDetailAppbarRouteTopicId(value: string): void {
  connectTopicDetailAppbar().routeTopicId = value
}
export function publishTopicDetailAppbarTitleStates(value: string): void {
  connectTopicDetailAppbar().titleStates = value
}
export function publishTopicDetailAppbarAvatarStates(value: string): void {
  connectTopicDetailAppbar().avatarStates = value
}
export function publishTopicDetailAppbarUsernameStates(value: string): void {
  connectTopicDetailAppbar().usernameStates = value
}
