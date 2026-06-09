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
  APPEND_BODY_REQUIRED = 'APPEND_BODY_REQUIRED',
  PARSE_APPEND_FORM_FAILED = 'PARSE_APPEND_FORM_FAILED',
  NOT_TOPIC_OWNER = 'NOT_TOPIC_OWNER',
  APPEND_SUBMIT_UNCONFIRMED = 'APPEND_SUBMIT_UNCONFIRMED',
  EDIT_WINDOW_CLOSED = 'EDIT_WINDOW_CLOSED',
  MISSING_ACTION_PATH = 'MISSING_ACTION_PATH',
  FIELD_REQUIRED_DETAIL = 'FIELD_REQUIRED_DETAIL',
  FIELD_EXTERNAL_LINK_FORBIDDEN = 'FIELD_EXTERNAL_LINK_FORBIDDEN',
  HOT_TOPICS_EMPTY = 'HOT_TOPICS_EMPTY',
  RECENT_TOPICS_EMPTY = 'RECENT_TOPICS_EMPTY',
  TAB_TOPICS_EMPTY = 'TAB_TOPICS_EMPTY',
  PARSE_LOGIN_PAGE_FAILED = 'PARSE_LOGIN_PAGE_FAILED',
  LOGIN_RESTRICTED = 'LOGIN_RESTRICTED',
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
  return AppStrings.text($r('app.string.common_load_failed'), 'Operation failed')
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
      $r('app.string.api_error_auth_required'),
      'Please sign in',
    )
  }
  static webSessionExpired(): ApiError {
    return new ApiError(
      ApiErrorCode.WEB_SESSION_EXPIRED,
      $r('app.string.api_error_web_session_expired'),
      'Web session expired',
    )
  }
  static invalidUsername(): ApiError {
    return new ApiError(
      ApiErrorCode.INVALID_USERNAME,
      $r('app.string.api_error_invalid_username'),
      'Invalid username',
    )
  }
  static invalidTopicId(): ApiError {
    return new ApiError(
      ApiErrorCode.INVALID_TOPIC_ID,
      $r('app.string.api_error_invalid_topic_id'),
      'Invalid topic ID',
    )
  }
  static invalidNode(): ApiError {
    return new ApiError(
      ApiErrorCode.INVALID_NODE,
      $r('app.string.api_error_invalid_node'),
      'Invalid node',
    )
  }
  static invalidReply(): ApiError {
    return new ApiError(
      ApiErrorCode.INVALID_REPLY,
      $r('app.string.api_error_invalid_reply'),
      'Invalid reply',
    )
  }
  static invalidNotificationId(): ApiError {
    return new ApiError(
      ApiErrorCode.INVALID_NOTIFICATION_ID,
      $r('app.string.api_error_invalid_notification_id'),
      'Invalid notification ID',
    )
  }
  static invalidOperationTarget(): ApiError {
    return new ApiError(
      ApiErrorCode.INVALID_OPERATION_TARGET,
      $r('app.string.api_error_invalid_operation_target'),
      'Invalid operation target',
    )
  }
  static nodeNameRequired(): ApiError {
    return new ApiError(
      ApiErrorCode.NODE_NAME_REQUIRED,
      $r('app.string.api_error_node_name_required'),
      'Node name is required',
    )
  }
  static missingNotificationParam(): ApiError {
    return new ApiError(
      ApiErrorCode.MISSING_NOTIFICATION_PARAM,
      $r('app.string.api_error_missing_notification_param'),
      'Missing notification deletion parameters',
    )
  }
  static notificationDeleteNotApplied(): ApiError {
    return new ApiError(
      ApiErrorCode.NOTIFICATION_DELETE_NOT_APPLIED,
      $r('app.string.api_error_notification_delete_not_applied'),
      'Notification deletion did not apply',
    )
  }
  static checkinNotAvailable(): ApiError {
    return new ApiError(
      ApiErrorCode.CHECKIN_NOT_AVAILABLE,
      $r('app.string.api_error_checkin_not_available'),
      'Check-in unavailable today',
    )
  }
  static parseFavoriteActionFailed(): ApiError {
    return new ApiError(
      ApiErrorCode.PARSE_FAVORITE_ACTION_FAILED,
      $r('app.string.api_error_parse_favorite_action_failed'),
      'Failed to parse favorite action',
    )
  }
  static parseFollowActionFailed(): ApiError {
    return new ApiError(
      ApiErrorCode.PARSE_FOLLOW_ACTION_FAILED,
      $r('app.string.api_error_parse_follow_action_failed'),
      'Failed to parse follow action',
    )
  }
  static missingUserAction(): ApiError {
    return new ApiError(
      ApiErrorCode.MISSING_USER_ACTION,
      $r('app.string.api_error_missing_user_action'),
      'Missing user action',
    )
  }
  static replyBodyRequired(): ApiError {
    return new ApiError(
      ApiErrorCode.REPLY_BODY_REQUIRED,
      $r('app.string.api_error_reply_body_required'),
      'Reply body is required',
    )
  }
  static parseReplyFormFailed(): ApiError {
    return new ApiError(
      ApiErrorCode.PARSE_REPLY_FORM_FAILED,
      $r('app.string.api_error_parse_reply_form_failed'),
      'Failed to parse reply form',
    )
  }
  static submitFailedDetail(detail: string): ApiError {
    const context: Record<string, string> = { '0': detail }
    return new ApiError(
      ApiErrorCode.SUBMIT_FAILED_DETAIL,
      $r('app.string.api_error_submit_failed_detail'),
      `Submit failed: ${detail}`,
      { context },
    )
  }
  static replySubmitUnconfirmed(): ApiError {
    return new ApiError(
      ApiErrorCode.REPLY_SUBMIT_UNCONFIRMED,
      $r('app.string.api_error_reply_submit_unconfirmed'),
      'Reply submit unconfirmed',
    )
  }
  static replyThankNotAllowed(): ApiError {
    return new ApiError(
      ApiErrorCode.REPLY_THANK_NOT_ALLOWED,
      $r('app.string.api_error_reply_thank_not_allowed'),
      'Reply cannot be thanked',
    )
  }
  static missingThankAction(): ApiError {
    return new ApiError(
      ApiErrorCode.MISSING_THANK_ACTION,
      $r('app.string.api_error_missing_thank_action'),
      'Missing thank action',
    )
  }
  static thankFailed(detail: string): ApiError {
    const context: Record<string, string> = { '0': detail }
    return new ApiError(
      ApiErrorCode.THANK_FAILED,
      $r('app.string.api_error_thank_failed'),
      `Thank failed: ${detail}`,
      { context },
    )
  }
  static topicThankNotAllowed(): ApiError {
    return new ApiError(
      ApiErrorCode.TOPIC_THANK_NOT_ALLOWED,
      $r('app.string.api_error_topic_thank_not_allowed'),
      'Topic cannot be thanked',
    )
  }
  static missingIgnoreAction(): ApiError {
    return new ApiError(
      ApiErrorCode.MISSING_IGNORE_ACTION,
      $r('app.string.api_error_missing_ignore_action'),
      'Missing ignore action',
    )
  }
  static missingReportAction(): ApiError {
    return new ApiError(
      ApiErrorCode.MISSING_REPORT_ACTION,
      $r('app.string.api_error_missing_report_action'),
      'Missing report action',
    )
  }
  static appendBodyRequired(): ApiError {
    return new ApiError(
      ApiErrorCode.APPEND_BODY_REQUIRED,
      $r('app.string.api_error_append_body_required'),
      'Append body is required',
    )
  }
  static parseAppendFormFailed(): ApiError {
    return new ApiError(
      ApiErrorCode.PARSE_APPEND_FORM_FAILED,
      $r('app.string.api_error_parse_append_form_failed'),
      'Append is not available for this topic',
    )
  }
  static notTopicOwner(): ApiError {
    return new ApiError(
      ApiErrorCode.NOT_TOPIC_OWNER,
      $r('app.string.api_error_not_topic_owner'),
      'Only the topic author can do this',
    )
  }
  static appendSubmitUnconfirmed(): ApiError {
    return new ApiError(
      ApiErrorCode.APPEND_SUBMIT_UNCONFIRMED,
      $r('app.string.api_error_append_submit_unconfirmed'),
      'Append submit unconfirmed',
    )
  }
  static editWindowClosed(): ApiError {
    return new ApiError(
      ApiErrorCode.EDIT_WINDOW_CLOSED,
      $r('app.string.api_error_edit_window_closed'),
      'The topic can no longer be edited (the 10-minute edit window has closed)',
    )
  }
  static nodeRequired(): ApiError {
    return new ApiError(
      ApiErrorCode.NODE_REQUIRED,
      $r('app.string.api_error_node_required'),
      'Node is required',
    )
  }
  static titleRequired(): ApiError {
    return new ApiError(
      ApiErrorCode.TITLE_REQUIRED,
      $r('app.string.api_error_title_required'),
      'Title is required',
    )
  }
  static bodyRequired(): ApiError {
    return new ApiError(
      ApiErrorCode.BODY_REQUIRED,
      $r('app.string.api_error_body_required'),
      'Body is required',
    )
  }
  static parseTopicFormFailed(): ApiError {
    return new ApiError(
      ApiErrorCode.PARSE_TOPIC_FORM_FAILED,
      $r('app.string.api_error_parse_topic_form_failed'),
      'Failed to parse topic form',
    )
  }
  static missingActionPath(): ApiError {
    return new ApiError(
      ApiErrorCode.MISSING_ACTION_PATH,
      $r('app.string.api_error_missing_action_path'),
      'Missing action path',
    )
  }
  static fieldRequiredDetail(label: string): ApiError {
    const context: Record<string, string> = { '0': label }
    return new ApiError(
      ApiErrorCode.FIELD_REQUIRED_DETAIL,
      $r('app.string.api_error_field_required_detail'),
      `Field is required: ${label}`,
      { context },
    )
  }
  static fieldExternalLinkForbidden(label: string): ApiError {
    const context: Record<string, string> = { '0': label }
    return new ApiError(
      ApiErrorCode.FIELD_EXTERNAL_LINK_FORBIDDEN,
      $r('app.string.api_error_field_external_link_forbidden'),
      `External links not allowed: ${label}`,
      { context },
    )
  }
  static hotTopicsEmpty(): ApiError {
    return new ApiError(
      ApiErrorCode.HOT_TOPICS_EMPTY,
      $r('app.string.api_error_hot_topics_empty'),
      'No hot topics returned',
    )
  }
  static recentTopicsEmpty(): ApiError {
    return new ApiError(
      ApiErrorCode.RECENT_TOPICS_EMPTY,
      $r('app.string.api_error_recent_topics_empty'),
      'No recent topics returned',
    )
  }
  static tabTopicsEmpty(tab: string): ApiError {
    const context: Record<string, string> = { '0': tab }
    return new ApiError(
      ApiErrorCode.TAB_TOPICS_EMPTY,
      $r('app.string.api_error_tab_topics_empty'),
      `Tab returned no topics: ${tab}`,
      { context },
    )
  }
  static parseLoginPageFailed(): ApiError {
    return new ApiError(
      ApiErrorCode.PARSE_LOGIN_PAGE_FAILED,
      $r('app.string.api_error_parse_login_page_failed'),
      'Failed to parse login page',
    )
  }
  static loginRestricted(ip: string): ApiError {
    const cleanIp = (ip || '').trim()
    const context: Record<string, string> = { '0': cleanIp }
    return new ApiError(
      ApiErrorCode.LOGIN_RESTRICTED,
      cleanIp ? $r('app.string.api_error_login_restricted_with_ip') : $r('app.string.api_error_login_restricted'),
      cleanIp ? `Login temporarily restricted for IP ${cleanIp}` : 'Login temporarily restricted',
      { context },
    )
  }
  static loginCaptchaRequired(): ApiError {
    return new ApiError(
      ApiErrorCode.LOGIN_CAPTCHA_REQUIRED,
      $r('app.string.api_error_login_captcha_required'),
      'Login captcha required',
    )
  }
  static captchaRequired(): ApiError {
    return new ApiError(
      ApiErrorCode.CAPTCHA_REQUIRED,
      $r('app.string.api_error_captcha_required'),
      'Captcha required',
    )
  }
  static loginFailedDetail(detail: string): ApiError {
    const context: Record<string, string> = { '0': detail }
    return new ApiError(
      ApiErrorCode.LOGIN_FAILED_DETAIL,
      $r('app.string.api_error_login_failed_detail'),
      `Login failed: ${detail}`,
      { context },
    )
  }
  static loginRedirectUnsupported(location: string): ApiError {
    const context: Record<string, string> = { '0': location }
    return new ApiError(
      ApiErrorCode.LOGIN_REDIRECT_UNSUPPORTED,
      $r('app.string.api_error_login_redirect_unsupported'),
      `Login redirect unsupported: ${location}`,
      { context },
    )
  }
  static loginStateUnconfirmed(): ApiError {
    return new ApiError(
      ApiErrorCode.LOGIN_STATE_UNCONFIRMED,
      $r('app.string.api_error_login_state_unconfirmed'),
      'Login state unconfirmed',
    )
  }
  static loginSessionMissing(): ApiError {
    return new ApiError(
      ApiErrorCode.LOGIN_SESSION_MISSING,
      $r('app.string.api_error_login_session_missing'),
      'Login session missing',
    )
  }
  static twoFactorCodeRequired(): ApiError {
    return new ApiError(
      ApiErrorCode.TWO_FACTOR_CODE_REQUIRED,
      $r('app.string.api_error_two_factor_code_required'),
      'Two-factor code required',
    )
  }
  static twoFactorFailedDetail(detail: string): ApiError {
    const context: Record<string, string> = { '0': detail }
    return new ApiError(
      ApiErrorCode.TWO_FACTOR_FAILED_DETAIL,
      $r('app.string.api_error_two_factor_failed_detail'),
      `Two-factor verification failed: ${detail}`,
      { context },
    )
  }
  static twoFactorFailed(): ApiError {
    return new ApiError(
      ApiErrorCode.TWO_FACTOR_FAILED,
      $r('app.string.api_error_two_factor_failed'),
      'Two-factor verification failed',
    )
  }
  static tokenMissing(): ApiError {
    return new ApiError(
      ApiErrorCode.TOKEN_MISSING,
      $r('app.string.api_error_token_missing'),
      'Missing token',
    )
  }
}
