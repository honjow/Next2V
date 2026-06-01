import { AppStorageV2 } from '@kit.ArkUI'

/**
 * V2 mirror of the user-profile appbar state `UserProfilePage` reports UP to the `Index` title bar
 * (the action menu availability/labels/toggle flags + the title identity strings).
 *
 * Writers route through the `publish*` helpers so this single `@Trace` mirror stays authoritative; the
 * migrated `@ComponentV2` `Index` reads the `@Trace` fields in its user-profile title-bar builder +
 * menu, and `UserProfilePage` reads back the change-guard / per-route `*States` / command-gate values
 * from the same mirror.
 *
 * V2-only: the legacy `AppStorage` half was retired once every reader moved to this mirror.
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
  connectUserProfileAppbar().actionsAvailable = value
}
export function publishUserProfileActionsUsername(value: string): void {
  connectUserProfileAppbar().actionsUsername = value
}
export function publishUserProfileFollowLabel(value: string): void {
  connectUserProfileAppbar().followLabel = value
}
export function publishUserProfileBlockLabel(value: string): void {
  connectUserProfileAppbar().blockLabel = value
}
export function publishUserProfileFollowing(value: boolean): void {
  connectUserProfileAppbar().following = value
}
export function publishUserProfileBlocked(value: boolean): void {
  connectUserProfileAppbar().blocked = value
}
export function publishUserProfileAppbarTitleUsername(value: string): void {
  connectUserProfileAppbar().titleUsername = value
}
export function publishUserProfileAppbarTitleAvatarUrl(value: string): void {
  connectUserProfileAppbar().titleAvatarUrl = value
}
export function publishUserProfileAppbarTitleRouteUsername(value: string): void {
  connectUserProfileAppbar().titleRouteUsername = value
}
export function publishUserProfileAppbarTitleStates(value: string): void {
  connectUserProfileAppbar().titleStates = value
}
export function publishUserProfileAppbarAvatarStates(value: string): void {
  connectUserProfileAppbar().avatarStates = value
}
