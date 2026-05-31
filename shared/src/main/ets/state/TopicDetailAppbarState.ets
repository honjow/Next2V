import { AppStorageV2 } from '@kit.ArkUI'
import { StorageKeys } from '../constants/StorageKeys'

/**
 * V2 mirror of the topic-detail appbar state that `TopicDetailPage` reports UP to the `Index` title bar
 * (the `TOPIC_DETAIL_SAVED_LATER` / `SITE_FAVORITED` / `THANKED` action-icon flags plus the
 * `TOPIC_DETAIL_APPBAR_*` identity strings).
 *
 * These keys are written by `TopicDetailPage` in many scattered action/rollback sites. To keep the V1
 * `AppStorage` keys and this `@Trace` mirror from drifting, every writer routes through the
 * `publish*` helpers below (write-through: AppStorage + mirror in one call). The migrated `@ComponentV2`
 * `Index` reads the `@Trace` fields in its title-bar builders so the appbar re-renders reactively as the
 * topic loads / the user toggles thank/favorite/save.
 *
 * Transitional: drop the `AppStorage` half once no V1 `@StorageLink` reads these keys.
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

// Write-through helpers: dual-write the V1 AppStorage key AND the V2 mirror so the two never drift.
export function publishTopicDetailSavedLater(value: boolean): void {
  AppStorage.setOrCreate<boolean>(StorageKeys.TOPIC_DETAIL_SAVED_LATER, value)
  connectTopicDetailAppbar().savedLater = value
}
export function publishTopicDetailSiteFavorited(value: boolean): void {
  AppStorage.setOrCreate<boolean>(StorageKeys.TOPIC_DETAIL_SITE_FAVORITED, value)
  connectTopicDetailAppbar().siteFavorited = value
}
export function publishTopicDetailThanked(value: boolean): void {
  AppStorage.setOrCreate<boolean>(StorageKeys.TOPIC_DETAIL_THANKED, value)
  connectTopicDetailAppbar().thanked = value
}
export function publishTopicDetailAppbarTitle(value: string): void {
  AppStorage.setOrCreate<string>(StorageKeys.TOPIC_DETAIL_APPBAR_TITLE, value)
  connectTopicDetailAppbar().title = value
}
export function publishTopicDetailAppbarAvatarUrl(value: string): void {
  AppStorage.setOrCreate<string>(StorageKeys.TOPIC_DETAIL_APPBAR_AVATAR_URL, value)
  connectTopicDetailAppbar().avatarUrl = value
}
export function publishTopicDetailAppbarUsername(value: string): void {
  AppStorage.setOrCreate<string>(StorageKeys.TOPIC_DETAIL_APPBAR_USERNAME, value)
  connectTopicDetailAppbar().username = value
}
export function publishTopicDetailAppbarRouteTopicId(value: string): void {
  AppStorage.setOrCreate<string>(StorageKeys.TOPIC_DETAIL_APPBAR_ROUTE_TOPIC_ID, value)
  connectTopicDetailAppbar().routeTopicId = value
}
export function publishTopicDetailAppbarTitleStates(value: string): void {
  AppStorage.setOrCreate<string>(StorageKeys.TOPIC_DETAIL_APPBAR_TITLE_STATES, value)
  connectTopicDetailAppbar().titleStates = value
}
export function publishTopicDetailAppbarAvatarStates(value: string): void {
  AppStorage.setOrCreate<string>(StorageKeys.TOPIC_DETAIL_APPBAR_AVATAR_STATES, value)
  connectTopicDetailAppbar().avatarStates = value
}
export function publishTopicDetailAppbarUsernameStates(value: string): void {
  AppStorage.setOrCreate<string>(StorageKeys.TOPIC_DETAIL_APPBAR_USERNAME_STATES, value)
  connectTopicDetailAppbar().usernameStates = value
}
