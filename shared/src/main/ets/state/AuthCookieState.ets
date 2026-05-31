import { AppStorageV2 } from '@kit.ArkUI'

/**
 * V2 mirror of the "auth cookie configured" flag (`StorageKeys.AUTH_COOKIE_CONFIGURED`).
 *
 * `CookieJarSettings.refreshConfiguredState` is the single AppStorage writer (every cookie
 * mutation — apply / set / clear — routes through it). During the State Management V1->V2
 * backbone migration it dual-writes: the legacy `AppStorage` key (still read by V1
 * `@StorageLink` pages: AccountPage / AccountDetailPage / NotificationPage) AND this `@Trace`
 * field (read by `@ComponentV2`, e.g. `TopicDetailPage`'s reply-button lock glyph), so the two
 * stores never diverge.
 *
 * Reading `configured` inside a `@ComponentV2` `build()` subscribes that component to
 * login/logout transitions. Transitional — drop the `AppStorage` half once every reader is V2.
 */
@ObservedV2
export class AuthCookieState {
  @Trace configured: boolean = false
}

const AUTH_COOKIE_V2_KEY: string = 'v2:authCookieConfigured'

/** Returns the app-wide AuthCookieState singleton from AppStorageV2. */
export function connectAuthCookie(): AuthCookieState {
  return AppStorageV2.connect(AuthCookieState, AUTH_COOKIE_V2_KEY, () => new AuthCookieState())!
}
