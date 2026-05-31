import { AppStorageV2 } from '@kit.ArkUI'
import { StorageKeys } from '../constants/StorageKeys'

/**
 * V2 mirror of the user-profile appbar state `UserProfilePage` reports UP to the `Index` title bar
 * (the action menu availability/labels/toggle flags + the `USER_PROFILE_APPBAR_TITLE_*` identity).
 *
 * Writers route through the `publish*` helpers (write-through: AppStorage + mirror) so the V1 keys and
 * this `@Trace` mirror never drift; the migrated `@ComponentV2` `Index` reads the `@Trace` fields in its
 * user-profile title-bar builder + menu. Transitional: drop the AppStorage half once no V1 `@StorageLink`
 * reads these keys.
 */
@ObservedV2
export class UserProfileAppbarState {
  @Trace actionsAvailable: boolean = false
  @Trace actionsUsername: string = ''
  @Trace followLabel: string = ''
  @Trace blockLabel: string = ''
  @Trace following: boolean = false
  @Trace blocked: boolean = false
  @Trace titleUsername: string = ''
  @Trace titleAvatarUrl: string = ''
  @Trace titleRouteUsername: string = ''
  @Trace titleStates: string = '{}'
  @Trace avatarStates: string = '{}'
}

const USER_PROFILE_APPBAR_V2_KEY: string = 'v2:userProfileAppbar'

/** Returns the app-wide UserProfileAppbarState singleton from AppStorageV2. */
export function connectUserProfileAppbar(): UserProfileAppbarState {
  return AppStorageV2.connect(UserProfileAppbarState, USER_PROFILE_APPBAR_V2_KEY, () => new UserProfileAppbarState())!
}

export function publishUserProfileActionsAvailable(value: boolean): void {
  AppStorage.setOrCreate<boolean>(StorageKeys.USER_PROFILE_ACTIONS_AVAILABLE, value)
  connectUserProfileAppbar().actionsAvailable = value
}
export function publishUserProfileActionsUsername(value: string): void {
  AppStorage.setOrCreate<string>(StorageKeys.USER_PROFILE_ACTIONS_USERNAME, value)
  connectUserProfileAppbar().actionsUsername = value
}
export function publishUserProfileFollowLabel(value: string): void {
  AppStorage.setOrCreate<string>(StorageKeys.USER_PROFILE_FOLLOW_LABEL, value)
  connectUserProfileAppbar().followLabel = value
}
export function publishUserProfileBlockLabel(value: string): void {
  AppStorage.setOrCreate<string>(StorageKeys.USER_PROFILE_BLOCK_LABEL, value)
  connectUserProfileAppbar().blockLabel = value
}
export function publishUserProfileFollowing(value: boolean): void {
  AppStorage.setOrCreate<boolean>(StorageKeys.USER_PROFILE_FOLLOWING, value)
  connectUserProfileAppbar().following = value
}
export function publishUserProfileBlocked(value: boolean): void {
  AppStorage.setOrCreate<boolean>(StorageKeys.USER_PROFILE_BLOCKED, value)
  connectUserProfileAppbar().blocked = value
}
export function publishUserProfileAppbarTitleUsername(value: string): void {
  AppStorage.setOrCreate<string>(StorageKeys.USER_PROFILE_APPBAR_TITLE_USERNAME, value)
  connectUserProfileAppbar().titleUsername = value
}
export function publishUserProfileAppbarTitleAvatarUrl(value: string): void {
  AppStorage.setOrCreate<string>(StorageKeys.USER_PROFILE_APPBAR_TITLE_AVATAR_URL, value)
  connectUserProfileAppbar().titleAvatarUrl = value
}
export function publishUserProfileAppbarTitleRouteUsername(value: string): void {
  AppStorage.setOrCreate<string>(StorageKeys.USER_PROFILE_APPBAR_TITLE_ROUTE_USERNAME, value)
  connectUserProfileAppbar().titleRouteUsername = value
}
export function publishUserProfileAppbarTitleStates(value: string): void {
  AppStorage.setOrCreate<string>(StorageKeys.USER_PROFILE_APPBAR_TITLE_STATES, value)
  connectUserProfileAppbar().titleStates = value
}
export function publishUserProfileAppbarAvatarStates(value: string): void {
  AppStorage.setOrCreate<string>(StorageKeys.USER_PROFILE_APPBAR_AVATAR_STATES, value)
  connectUserProfileAppbar().avatarStates = value
}
