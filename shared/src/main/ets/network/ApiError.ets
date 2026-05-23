import { AppStrings } from '../i18n/AppStrings'

/**
 * Stable identifiers for network-layer errors raised by ApiService /
 * ApiV2Service / V2exNativeAuthService. UI / logging / catch sites match on
 * `ApiError.code`; the user-facing string is resolved separately via
 * `translateApiError(err, context)`.
 *
 * Do NOT rename existing values — callers compare to the string literal.
 * Source of truth: .hermes-artifacts/20260523-200000-api-error-code-spike/error-codes.md
 */
export enum ApiErrorCode {
  AUTH_REQUIRED = 'AUTH_REQUIRED',
  WEB_SESSION_EXPIRED = 'WEB_SESSION_EXPIRED',
  INVALID_USERNAME = 'INVALID_USERNAME',
  INVALID_TOPIC_ID = 'INVALID_TOPIC_ID',
  INVALID_NODE = 'INVALID_NODE',
  INVALID_REPLY = 'INVALID_REPLY',
  INVALID_NOTIFICATION_ID = 'INVALID_NOTIFICATION_ID',
  INVALID_OPERATION_TARGET = 'INVALID_OPERATION_TARGET',
  NODE_NAME_REQUIRED = 'NODE_NAME_REQUIRED',
  MISSING_NOTIFICATION_PARAM = 'MISSING_NOTIFICATION_PARAM',
  NOTIFICATION_DELETE_NOT_APPLIED = 'NOTIFICATION_DELETE_NOT_APPLIED',
  CHECKIN_NOT_AVAILABLE = 'CHECKIN_NOT_AVAILABLE',
  PARSE_FAVORITE_ACTION_FAILED = 'PARSE_FAVORITE_ACTION_FAILED',
  PARSE_FOLLOW_ACTION_FAILED = 'PARSE_FOLLOW_ACTION_FAILED',
  MISSING_USER_ACTION = 'MISSING_USER_ACTION',
  REPLY_BODY_REQUIRED = 'REPLY_BODY_REQUIRED',
  PARSE_REPLY_FORM_FAILED = 'PARSE_REPLY_FORM_FAILED',
  SUBMIT_FAILED_DETAIL = 'SUBMIT_FAILED_DETAIL',
  REPLY_SUBMIT_UNCONFIRMED = 'REPLY_SUBMIT_UNCONFIRMED',
  REPLY_THANK_NOT_ALLOWED = 'REPLY_THANK_NOT_ALLOWED',
  MISSING_THANK_ACTION = 'MISSING_THANK_ACTION',
  THANK_FAILED = 'THANK_FAILED',
  TOPIC_THANK_NOT_ALLOWED = 'TOPIC_THANK_NOT_ALLOWED',
  MISSING_IGNORE_ACTION = 'MISSING_IGNORE_ACTION',
  MISSING_REPORT_ACTION = 'MISSING_REPORT_ACTION',
  NODE_REQUIRED = 'NODE_REQUIRED',
  TITLE_REQUIRED = 'TITLE_REQUIRED',
  BODY_REQUIRED = 'BODY_REQUIRED',
  PARSE_TOPIC_FORM_FAILED = 'PARSE_TOPIC_FORM_FAILED',
  MISSING_ACTION_PATH = 'MISSING_ACTION_PATH',
  FIELD_REQUIRED_DETAIL = 'FIELD_REQUIRED_DETAIL',
  FIELD_EXTERNAL_LINK_FORBIDDEN = 'FIELD_EXTERNAL_LINK_FORBIDDEN',
  HOT_TOPICS_EMPTY = 'HOT_TOPICS_EMPTY',
  RECENT_TOPICS_EMPTY = 'RECENT_TOPICS_EMPTY',
  TAB_TOPICS_EMPTY = 'TAB_TOPICS_EMPTY',
  PARSE_LOGIN_PAGE_FAILED = 'PARSE_LOGIN_PAGE_FAILED',
  LOGIN_CAPTCHA_REQUIRED = 'LOGIN_CAPTCHA_REQUIRED',
  CAPTCHA_REQUIRED = 'CAPTCHA_REQUIRED',
  LOGIN_FAILED_DETAIL = 'LOGIN_FAILED_DETAIL',
  LOGIN_REDIRECT_UNSUPPORTED = 'LOGIN_REDIRECT_UNSUPPORTED',
  LOGIN_STATE_UNCONFIRMED = 'LOGIN_STATE_UNCONFIRMED',
  LOGIN_SESSION_MISSING = 'LOGIN_SESSION_MISSING',
  TWO_FACTOR_CODE_REQUIRED = 'TWO_FACTOR_CODE_REQUIRED',
  TWO_FACTOR_FAILED_DETAIL = 'TWO_FACTOR_FAILED_DETAIL',
  TWO_FACTOR_FAILED = 'TWO_FACTOR_FAILED',
  TOKEN_MISSING = 'TOKEN_MISSING',
}

export interface ApiErrorOptions {
  cause?: Object | null
  httpStatus?: number
  context?: Record<string, string>
}

/**
 * Typed network error. `.message` carries an English fallback so logs and
 * pre-init paths (no ResourceManager) stay readable; UI must always render
 * `translateApiError(err, context)` to honour the current locale.
 */
export class ApiError extends Error {
  readonly code: ApiErrorCode
  readonly messageKey: Resource
  readonly httpStatus?: number
  readonly context?: Record<string, string>

  constructor(
    code: ApiErrorCode,
    messageKey: Resource,
    englishFallback: string,
    options?: ApiErrorOptions,
  ) {
    super(englishFallback)
    this.name = 'ApiError'
    this.code = code
    this.messageKey = messageKey
    this.httpStatus = options?.httpStatus
    this.context = options?.context
  }
}

/**
 * `instanceof ApiError` works inside the shared HSP boundary, but cross-HSP
 * release builds with aggressive obfuscation can lose the class identity.
 * Duck-typing fallback keeps catch sites correct in that edge case
 * (see module-boundary-check.md).
 */
export function isApiError(err: Object | null | undefined): boolean {
  if (err instanceof ApiError) return true
  if (err === null || err === undefined) return false
  if (typeof err !== 'object') return false
  const obj = err as Record<string, Object | undefined>
  const code = obj['code']
  const messageKey = obj['messageKey']
  return typeof code === 'string' && messageKey !== undefined && messageKey !== null
}

/**
 * Resolve a thrown error into a localized string suitable for toast / inline
 * UI. `ApiError` payloads are looked up via the bundled `messageKey`
 * Resource, with `context['0']`..`context['N']` injected through
 * `AppStrings.format`. Non-`ApiError` values fall back to `error.message`
 * (legacy throw sites) or a generic localized message.
 */
export function translateApiError(err: Object | null | undefined): string {
  if (isApiError(err)) {
    const apiErr = err as ApiError
    const fallback = apiErr.message
    const template = AppStrings.text(apiErr.messageKey, fallback)
    const context = apiErr.context
    if (context) {
      const values: string[] = []
      for (let i = 0; ; i++) {
        const v = context[String(i)]
        if (v === undefined) break
        values.push(v)
      }
      if (values.length > 0) {
        return AppStrings.format(template, values)
      }
    }
    return template
  }
  if (err instanceof Error) {
    const msg = (err as Error).message
    if (msg && msg.length > 0) {
      return msg
    }
  }
  return AppStrings.text(AppStrings.R_COMMON_LOAD_FAILED, 'Operation failed')
}

/**
 * Static factory for every 46 ApiErrorCode value. Phase 1+ throw sites
 * call these instead of constructing `ApiError` directly so the English
 * fallback and `messageKey` stay in lockstep with `ApiErrorCode`.
 */
export class ApiErrors {
  static authRequired(): ApiError {
    return new ApiError(
      ApiErrorCode.AUTH_REQUIRED,
      AppStrings.R_API_ERROR_AUTH_REQUIRED,
      'Please sign in',
    )
  }
  static webSessionExpired(): ApiError {
    return new ApiError(
      ApiErrorCode.WEB_SESSION_EXPIRED,
      AppStrings.R_API_ERROR_WEB_SESSION_EXPIRED,
      'Web session expired',
    )
  }
  static invalidUsername(): ApiError {
    return new ApiError(
      ApiErrorCode.INVALID_USERNAME,
      AppStrings.R_API_ERROR_INVALID_USERNAME,
      'Invalid username',
    )
  }
  static invalidTopicId(): ApiError {
    return new ApiError(
      ApiErrorCode.INVALID_TOPIC_ID,
      AppStrings.R_API_ERROR_INVALID_TOPIC_ID,
      'Invalid topic ID',
    )
  }
  static invalidNode(): ApiError {
    return new ApiError(
      ApiErrorCode.INVALID_NODE,
      AppStrings.R_API_ERROR_INVALID_NODE,
      'Invalid node',
    )
  }
  static invalidReply(): ApiError {
    return new ApiError(
      ApiErrorCode.INVALID_REPLY,
      AppStrings.R_API_ERROR_INVALID_REPLY,
      'Invalid reply',
    )
  }
  static invalidNotificationId(): ApiError {
    return new ApiError(
      ApiErrorCode.INVALID_NOTIFICATION_ID,
      AppStrings.R_API_ERROR_INVALID_NOTIFICATION_ID,
      'Invalid notification ID',
    )
  }
  static invalidOperationTarget(): ApiError {
    return new ApiError(
      ApiErrorCode.INVALID_OPERATION_TARGET,
      AppStrings.R_API_ERROR_INVALID_OPERATION_TARGET,
      'Invalid operation target',
    )
  }
  static nodeNameRequired(): ApiError {
    return new ApiError(
      ApiErrorCode.NODE_NAME_REQUIRED,
      AppStrings.R_API_ERROR_NODE_NAME_REQUIRED,
      'Node name is required',
    )
  }
  static missingNotificationParam(): ApiError {
    return new ApiError(
      ApiErrorCode.MISSING_NOTIFICATION_PARAM,
      AppStrings.R_API_ERROR_MISSING_NOTIFICATION_PARAM,
      'Missing notification deletion parameters',
    )
  }
  static notificationDeleteNotApplied(): ApiError {
    return new ApiError(
      ApiErrorCode.NOTIFICATION_DELETE_NOT_APPLIED,
      AppStrings.R_API_ERROR_NOTIFICATION_DELETE_NOT_APPLIED,
      'Notification deletion did not apply',
    )
  }
  static checkinNotAvailable(): ApiError {
    return new ApiError(
      ApiErrorCode.CHECKIN_NOT_AVAILABLE,
      AppStrings.R_API_ERROR_CHECKIN_NOT_AVAILABLE,
      'Check-in unavailable today',
    )
  }
  static parseFavoriteActionFailed(): ApiError {
    return new ApiError(
      ApiErrorCode.PARSE_FAVORITE_ACTION_FAILED,
      AppStrings.R_API_ERROR_PARSE_FAVORITE_ACTION_FAILED,
      'Failed to parse favorite action',
    )
  }
  static parseFollowActionFailed(): ApiError {
    return new ApiError(
      ApiErrorCode.PARSE_FOLLOW_ACTION_FAILED,
      AppStrings.R_API_ERROR_PARSE_FOLLOW_ACTION_FAILED,
      'Failed to parse follow action',
    )
  }
  static missingUserAction(): ApiError {
    return new ApiError(
      ApiErrorCode.MISSING_USER_ACTION,
      AppStrings.R_API_ERROR_MISSING_USER_ACTION,
      'Missing user action',
    )
  }
  static replyBodyRequired(): ApiError {
    return new ApiError(
      ApiErrorCode.REPLY_BODY_REQUIRED,
      AppStrings.R_API_ERROR_REPLY_BODY_REQUIRED,
      'Reply body is required',
    )
  }
  static parseReplyFormFailed(): ApiError {
    return new ApiError(
      ApiErrorCode.PARSE_REPLY_FORM_FAILED,
      AppStrings.R_API_ERROR_PARSE_REPLY_FORM_FAILED,
      'Failed to parse reply form',
    )
  }
  static submitFailedDetail(detail: string): ApiError {
    const context: Record<string, string> = { '0': detail }
    return new ApiError(
      ApiErrorCode.SUBMIT_FAILED_DETAIL,
      AppStrings.R_API_ERROR_SUBMIT_FAILED_DETAIL,
      `Submit failed: ${detail}`,
      { context },
    )
  }
  static replySubmitUnconfirmed(): ApiError {
    return new ApiError(
      ApiErrorCode.REPLY_SUBMIT_UNCONFIRMED,
      AppStrings.R_API_ERROR_REPLY_SUBMIT_UNCONFIRMED,
      'Reply submit unconfirmed',
    )
  }
  static replyThankNotAllowed(): ApiError {
    return new ApiError(
      ApiErrorCode.REPLY_THANK_NOT_ALLOWED,
      AppStrings.R_API_ERROR_REPLY_THANK_NOT_ALLOWED,
      'Reply cannot be thanked',
    )
  }
  static missingThankAction(): ApiError {
    return new ApiError(
      ApiErrorCode.MISSING_THANK_ACTION,
      AppStrings.R_API_ERROR_MISSING_THANK_ACTION,
      'Missing thank action',
    )
  }
  static thankFailed(detail: string): ApiError {
    const context: Record<string, string> = { '0': detail }
    return new ApiError(
      ApiErrorCode.THANK_FAILED,
      AppStrings.R_API_ERROR_THANK_FAILED,
      `Thank failed: ${detail}`,
      { context },
    )
  }
  static topicThankNotAllowed(): ApiError {
    return new ApiError(
      ApiErrorCode.TOPIC_THANK_NOT_ALLOWED,
      AppStrings.R_API_ERROR_TOPIC_THANK_NOT_ALLOWED,
      'Topic cannot be thanked',
    )
  }
  static missingIgnoreAction(): ApiError {
    return new ApiError(
      ApiErrorCode.MISSING_IGNORE_ACTION,
      AppStrings.R_API_ERROR_MISSING_IGNORE_ACTION,
      'Missing ignore action',
    )
  }
  static missingReportAction(): ApiError {
    return new ApiError(
      ApiErrorCode.MISSING_REPORT_ACTION,
      AppStrings.R_API_ERROR_MISSING_REPORT_ACTION,
      'Missing report action',
    )
  }
  static nodeRequired(): ApiError {
    return new ApiError(
      ApiErrorCode.NODE_REQUIRED,
      AppStrings.R_API_ERROR_NODE_REQUIRED,
      'Node is required',
    )
  }
  static titleRequired(): ApiError {
    return new ApiError(
      ApiErrorCode.TITLE_REQUIRED,
      AppStrings.R_API_ERROR_TITLE_REQUIRED,
      'Title is required',
    )
  }
  static bodyRequired(): ApiError {
    return new ApiError(
      ApiErrorCode.BODY_REQUIRED,
      AppStrings.R_API_ERROR_BODY_REQUIRED,
      'Body is required',
    )
  }
  static parseTopicFormFailed(): ApiError {
    return new ApiError(
      ApiErrorCode.PARSE_TOPIC_FORM_FAILED,
      AppStrings.R_API_ERROR_PARSE_TOPIC_FORM_FAILED,
      'Failed to parse topic form',
    )
  }
  static missingActionPath(): ApiError {
    return new ApiError(
      ApiErrorCode.MISSING_ACTION_PATH,
      AppStrings.R_API_ERROR_MISSING_ACTION_PATH,
      'Missing action path',
    )
  }
  static fieldRequiredDetail(label: string): ApiError {
    const context: Record<string, string> = { '0': label }
    return new ApiError(
      ApiErrorCode.FIELD_REQUIRED_DETAIL,
      AppStrings.R_API_ERROR_FIELD_REQUIRED_DETAIL,
      `Field is required: ${label}`,
      { context },
    )
  }
  static fieldExternalLinkForbidden(label: string): ApiError {
    const context: Record<string, string> = { '0': label }
    return new ApiError(
      ApiErrorCode.FIELD_EXTERNAL_LINK_FORBIDDEN,
      AppStrings.R_API_ERROR_FIELD_EXTERNAL_LINK_FORBIDDEN,
      `External links not allowed: ${label}`,
      { context },
    )
  }
  static hotTopicsEmpty(): ApiError {
    return new ApiError(
      ApiErrorCode.HOT_TOPICS_EMPTY,
      AppStrings.R_API_ERROR_HOT_TOPICS_EMPTY,
      'No hot topics returned',
    )
  }
  static recentTopicsEmpty(): ApiError {
    return new ApiError(
      ApiErrorCode.RECENT_TOPICS_EMPTY,
      AppStrings.R_API_ERROR_RECENT_TOPICS_EMPTY,
      'No recent topics returned',
    )
  }
  static tabTopicsEmpty(tab: string): ApiError {
    const context: Record<string, string> = { '0': tab }
    return new ApiError(
      ApiErrorCode.TAB_TOPICS_EMPTY,
      AppStrings.R_API_ERROR_TAB_TOPICS_EMPTY,
      `Tab returned no topics: ${tab}`,
      { context },
    )
  }
  static parseLoginPageFailed(): ApiError {
    return new ApiError(
      ApiErrorCode.PARSE_LOGIN_PAGE_FAILED,
      AppStrings.R_API_ERROR_PARSE_LOGIN_PAGE_FAILED,
      'Failed to parse login page',
    )
  }
  static loginCaptchaRequired(): ApiError {
    return new ApiError(
      ApiErrorCode.LOGIN_CAPTCHA_REQUIRED,
      AppStrings.R_API_ERROR_LOGIN_CAPTCHA_REQUIRED,
      'Login captcha required',
    )
  }
  static captchaRequired(): ApiError {
    return new ApiError(
      ApiErrorCode.CAPTCHA_REQUIRED,
      AppStrings.R_API_ERROR_CAPTCHA_REQUIRED,
      'Captcha required',
    )
  }
  static loginFailedDetail(detail: string): ApiError {
    const context: Record<string, string> = { '0': detail }
    return new ApiError(
      ApiErrorCode.LOGIN_FAILED_DETAIL,
      AppStrings.R_API_ERROR_LOGIN_FAILED_DETAIL,
      `Login failed: ${detail}`,
      { context },
    )
  }
  static loginRedirectUnsupported(location: string): ApiError {
    const context: Record<string, string> = { '0': location }
    return new ApiError(
      ApiErrorCode.LOGIN_REDIRECT_UNSUPPORTED,
      AppStrings.R_API_ERROR_LOGIN_REDIRECT_UNSUPPORTED,
      `Login redirect unsupported: ${location}`,
      { context },
    )
  }
  static loginStateUnconfirmed(): ApiError {
    return new ApiError(
      ApiErrorCode.LOGIN_STATE_UNCONFIRMED,
      AppStrings.R_API_ERROR_LOGIN_STATE_UNCONFIRMED,
      'Login state unconfirmed',
    )
  }
  static loginSessionMissing(): ApiError {
    return new ApiError(
      ApiErrorCode.LOGIN_SESSION_MISSING,
      AppStrings.R_API_ERROR_LOGIN_SESSION_MISSING,
      'Login session missing',
    )
  }
  static twoFactorCodeRequired(): ApiError {
    return new ApiError(
      ApiErrorCode.TWO_FACTOR_CODE_REQUIRED,
      AppStrings.R_API_ERROR_TWO_FACTOR_CODE_REQUIRED,
      'Two-factor code required',
    )
  }
  static twoFactorFailedDetail(detail: string): ApiError {
    const context: Record<string, string> = { '0': detail }
    return new ApiError(
      ApiErrorCode.TWO_FACTOR_FAILED_DETAIL,
      AppStrings.R_API_ERROR_TWO_FACTOR_FAILED_DETAIL,
      `Two-factor verification failed: ${detail}`,
      { context },
    )
  }
  static twoFactorFailed(): ApiError {
    return new ApiError(
      ApiErrorCode.TWO_FACTOR_FAILED,
      AppStrings.R_API_ERROR_TWO_FACTOR_FAILED,
      'Two-factor verification failed',
    )
  }
  static tokenMissing(): ApiError {
    return new ApiError(
      ApiErrorCode.TOKEN_MISSING,
      AppStrings.R_API_ERROR_TOKEN_MISSING,
      'Missing token',
    )
  }
}
