/** AppStorage 键名常量，避免跨模块硬编码字符串 */
export class StorageKeys {
  static readonly TOP_AVOID_HEIGHT: string = 'topAvoidHeight'
  static readonly BOTTOM_AVOID_HEIGHT: string = 'bottomAvoidHeight'
  static readonly NAV_PATH_STACK: string = 'ns'
  static readonly USE_CO_DOMAIN: string = 'useCoDomain'
  static readonly AUTH_TOKEN_CONFIGURED: string = 'authTokenConfigured'
  static readonly AUTH_USERNAME: string = 'authUsername'
  static readonly AUTH_COOKIE_CONFIGURED: string = 'authCookieConfigured'
  static readonly AUTH_LOGIN_MODE: string = 'authLoginMode'
  static readonly AUTH_SESSION_USERNAME: string = 'authSessionUsername'
  static readonly AUTH_SESSION_AVATAR: string = 'authSessionAvatar'
  static readonly AUTH_SESSION_VALIDATED_AT: string = 'authSessionValidatedAt'
}
