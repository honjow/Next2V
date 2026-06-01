import { AppStorageV2 } from '@kit.ArkUI'

/**
 * V2 command buses for the two one-directional UserProfile appbar inputs
 * (`'v2:userProfileAction'`: the `command` + `shown` fields).
 *
 * Both are one-directional command buses written ONLY by the `@ComponentV2` `Index.ets` title bar:
 * - `command` mirrors `USER_PROFILE_ACTION`: the follow / block menu items write a
 *   `<token>:<action>` string (`Index.sendUserProfileAction`, the single writer); the
 *   `@ComponentV2` `UserProfilePage` reacts to run the matching toggle.
 * - `shown` mirrors `USER_PROFILE_SHOWN`: when a UserProfile destination appears Index writes a
 *   `<token>:<username>` string (`Index.notifyUserProfileShown`, the single writer); the page
 *   reacts to republish its appbar / action-menu state for the now-visible profile.
 *
 * The leading `<token>` (a timestamp) only guarantees the string changes so the bus refires for a
 * repeated action/username — it is Index's pre-existing command-bus encoding, NOT a key-churn UI
 * workaround. The page reports its appbar/action state back to Index through the separate
 * `UserProfileAppbarState` keys; there is no writeback on these two command fields.
 *
 * A `@ComponentV2` consumer holds the singleton and runs each reaction via
 * `@Monitor('<member>.command')` / `@Monitor('<member>.shown')` when the field changes. The legacy V1
 * `AppStorage` (`userProfileAction` / `userProfileShown`) keys + their dual-write were retired once no
 * reader read the V1 half.
 */
@ObservedV2
export class UserProfileActionState {
  @Trace command: string = ''
  @Trace shown: string = ''
}

const USER_PROFILE_ACTION_V2_KEY: string = 'v2:userProfileAction'

/** Returns the app-wide UserProfileActionState singleton from AppStorageV2. */
export function connectUserProfileAction(): UserProfileActionState {
  return AppStorageV2.connect(UserProfileActionState, USER_PROFILE_ACTION_V2_KEY, () => new UserProfileActionState())!
}
