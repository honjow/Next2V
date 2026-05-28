import { http } from '@kit.NetworkKit'
import { HttpClient } from './HttpClient'
import { NetworkProxyRequest } from './NetworkProxyRequest'
import { FeedTabSettings } from '../settings/FeedTabSettings'
import { ApiConstants } from '../constants/ApiConstants'
import { V2exTabParser } from '../parser/V2exTabParser'
import { V2exNotificationParser } from '../parser/V2exNotificationParser'
import { V2exAccountParser } from '../parser/V2exAccountParser'
import { V2exSessionParser } from '../parser/V2exSessionParser'
import { V2exNodeParser, type V2exFavoriteNode, type V2exNodeNavigationSection } from '../parser/V2exNodeParser'
import {
  V2exCollectionActionParser,
  type V2exToggleAction,
} from '../parser/V2exCollectionActionParser'
import { V2exWriteFormParser } from '../parser/V2exWriteFormParser'
import { V2exSigninParser } from '../parser/V2exSigninParser'
import { V2exMemberPageParser } from '../parser/V2exMemberPageParser'
import {
  V2exAccountListParser,
  type V2exAccountMemberListItem,
} from '../parser/V2exAccountListParser'
import { V2exTopicWebRepliesClient } from './V2exTopicWebRepliesClient'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import type {
  V2exTopicWebRepliesAllResult,
  V2exTopicWebRepliesPage,
} from './V2exTopicWebRepliesClient'
import { HtmlEntityUtils } from '../utils/HtmlEntityUtils'
import { V2exUrlRouter } from '../utils/V2exUrlRouter'
import type {
  V2exTopic,
  V2exReply,
  V2exNode,
  V2exMemberProfile,
  V2exSiteInfo,
  V2exAuthenticatedMember,
  V2exNotification,
  V2exTokenInfo,
  V2exBalance,
  V2exDailyMission,
  V2exMemberPageSnapshot,
  V2exMemberRepliesPageSnapshot,
  V2exMemberTopicsPageSnapshot,
  V2exNodeTopicsPageSnapshot,
  V2exNodeTopicsPageResult,
} from './NetworkTypes'
import { ApiError, ApiErrors, ApiErrorCode, isApiError } from './ApiError'

interface CookieHtmlResponse {
  statusCode: number
  text: string
  location: string
}

interface NotificationDeleteAction {
  id: number
  once: string
}

interface SameOriginRequestUrls {
  url: string
  refererUrl: string
}

export class V2exCookieTwoFactorRequiredError extends Error {
  path: string

  constructor(path: string, message: string = 'V2EX requires two-factor verification') {
    super(message)
    this.name = 'V2exCookieTwoFactorRequiredError'
    this.path = path
  }
}

export interface V2exReplyThankAction {
  replyId: number
  actionPath: string
}

export interface V2exTopicThankAction {
  topicId: number
  actionPath: string
}

export interface V2exTopicModerationAction {
  topicId: number
  actionPath: string
}

export interface V2exReplyModerationAction {
  replyId: number
  actionPath: string
}

/**
 * V2EX API call layer
 * V1 public API (no auth) + V2 authenticated API placeholder
 */
export class ApiService {
  private http: HttpClient = HttpClient.getInstance()
  private readonly CONNECT_TIMEOUT_MS: number = 10000
  private readonly READ_TIMEOUT_MS: number = 15000

  // ==================== V1 Public API (V1) ====================

  /** Get the latest topics from the public HTML feed to avoid legacy JSON API rate limits. */
  async getLatestTopics(): Promise<V2exTopic[]> {
    return this.getRecentTopics(1)
  }

  /** Get hot topics from the public HTML hot tab to avoid legacy JSON API rate limits. */
  async getHotTopics(): Promise<V2exTopic[]> {
    return this.getHotTabTopics()
  }

  /** Get site hot tab trending topics */
  async getHotTabTopics(): Promise<V2exTopic[]> {
    const html = await this.http.getText('/?tab=hot')
    const topics = V2exTabParser.parseTopicList(html)
    if (topics.length === 0) {
      throw ApiErrors.hotTopicsEmpty()
    }
    return ApiService.normalizeTopics(topics)
  }

  async getNodeNavigationSections(): Promise<V2exNodeNavigationSection[]> {
    const homeHtml = await this.http.getText('/')
    const navigationHtml = await this.http.getText('/?tab=nodes')
    const homeSections = V2exNodeParser.extractNodeNavigationSections(homeHtml)
      .filter((section: V2exNodeNavigationSection) => section.titleKey === 'discover_node_navigation_hottest' || section.titleKey === 'discover_node_navigation_recently_created')
    const structuredSections = V2exNodeParser.extractStructuredNodeNavigationSections(navigationHtml)
    return homeSections.concat(structuredSections)
  }

  /** Get all-site recently updated topics */
  async getRecentTopics(page: number = 1): Promise<V2exTopic[]> {
    const safePage = Math.max(1, Math.floor(page))
    const html = await this.http.getText(`/recent?p=${safePage}`)
    const topics = V2exTabParser.parseTopicList(html)
    if (topics.length === 0) {
      throw ApiErrors.recentTopicsEmpty()
    }
    return ApiService.normalizeTopics(topics)
  }

  /** Get a single topic by ID */
  async getTopicById(topicId: number, cacheBuster: number = 0): Promise<V2exTopic[]> {
    if (topicId <= 0) {
      return []
    }
    const endpoint =
      cacheBuster > 0
        ? `${ApiConstants.API_TOPIC_SHOW}?id=${topicId}&_=${cacheBuster}`
        : `${ApiConstants.API_TOPIC_SHOW}?id=${topicId}`
    try {
      // Keep topic detail content on legacy JSON first: its content/content_rendered is the
      // stable input for V2Next's rendered-content parser. HTML is only a no-account fallback.
      const topics =
        cacheBuster > 0
          ? await this.http.getNoCache<V2exTopic[]>(endpoint)
          : await this.http.get<V2exTopic[]>(endpoint)
      return ApiService.normalizeTopics(topics)
    } catch (error) {
      DiagnosticLogger.exception('network', 'topic_json_fallback_to_html_exception', error as Error, { topicId: topicId })
      const path = cacheBuster > 0 ? `/t/${topicId}?_=${cacheBuster}` : `/t/${topicId}`
      const html = await this.http.getText(path)
      return [ApiService.topicFromHtml(topicId, html)]
    }
  }

  /** Get topics by username */
  async getTopicsByUsername(username: string): Promise<V2exTopic[]> {
    const snapshot = await this.getMemberTopicsPage(username, 1)
    return this.getTopicsByIds(snapshot.topicIds)
  }

  /** Get topics by node name */
  async getTopicsByNode(nodeName: string): Promise<V2exTopic[]> {
    const result = await this.getNodeTopicsPage(nodeName, 1)
    return result.topics
  }

  /** Get topics from node page, supports /go/{node}?p=N pagination. */
  async getNodeTopicsPage(nodeName: string, page: number = 1): Promise<V2exNodeTopicsPageResult> {
    const clean = (nodeName || '').trim()
    if (!clean) {
      throw ApiErrors.nodeNameRequired()
    }
    const safePage = Math.max(1, Math.floor(page))
    const html = await this.http.getText(`/go/${encodeURIComponent(clean)}?p=${safePage}`)
    const snapshot: V2exNodeTopicsPageSnapshot = V2exNodeParser.parseNodeTopicsPage(html)
    const topics = V2exTabParser.parseTopicList(html)
    if (topics.length === 0) {
      return { topics: [], hasMore: false }
    }
    return {
      topics: ApiService.normalizeNodeTopics(topics, clean, clean),
      hasMore: snapshot.hasMore,
    }
  }

  /** Get reply list for a topic */
  async getReplies(topicId: number, cacheBuster: number = 0): Promise<V2exReply[]> {
    const endpoint =
      cacheBuster > 0
        ? `${ApiConstants.API_REPLIES_SHOW}?topic_id=${topicId}&_=${cacheBuster}`
        : `${ApiConstants.API_REPLIES_SHOW}?topic_id=${topicId}`
    const replies =
      cacheBuster > 0
        ? await this.http.getNoCache<V2exReply[]>(endpoint)
        : await this.http.get<V2exReply[]>(endpoint)
    return ApiService.normalizeReplies(replies)
  }

  /** Get topic replies; when public API returns fewer than total, fall back to public web page HTML. */
  async getRepliesWithWebFallback(
    topicId: number,
    expectedReplies: number = 0,
  ): Promise<V2exReply[]> {
    const apiReplies = await this.getReplies(topicId)
    if (apiReplies.length === 0 || (expectedReplies > 0 && apiReplies.length < expectedReplies)) {
      try {
        const webReplies = await this.getTopicWebReplies(topicId)
        if (webReplies.length > apiReplies.length) {
          return webReplies
        }
      } catch (error) {
        const e = error as Error
        DiagnosticLogger.exception('network', 'topic_web_replies_fallback_exception', e, { topicId: topicId })
        console.error('topic web replies fallback failed:', e.message)
      }
    }
    return apiReplies
  }

  /** Get a single page of replies from public topic page, for detail page page-by-page append and last-page refresh. */
  async getTopicWebRepliesPage(
    topicId: number,
    page: number = 1,
    cacheBuster: number = Date.now(),
    cookie: string = '',
  ): Promise<V2exTopicWebRepliesPage> {
    return this.topicWebRepliesClient().getPage(topicId, page, cacheBuster, cookie)
  }

  /** Get actual replies from public topic page, as fallback when legacy replies API is empty or stale. */
  async getTopicWebReplies(topicId: number, cookie: string = ''): Promise<V2exReply[]> {
    return this.topicWebRepliesClient().getReplies(topicId, cookie)
  }

  /**
   * Fetch all reply pages in parallel. Returns merged replies sorted by page order,
   * plus the page count. An optional onProgress callback fires after each page completes.
   */
  async getTopicWebRepliesAll(
    topicId: number,
    cookie: string = '',
    onProgress?: (loaded: number, total: number) => void,
  ): Promise<V2exTopicWebRepliesAllResult> {
    return this.topicWebRepliesClient().getAll(topicId, cookie, onProgress)
  }

  /** Get all nodes */
  async getAllNodes(): Promise<V2exNode[]> {
    return this.http.get<V2exNode[]>(ApiConstants.API_NODES_ALL)
  }

  /** Get node detail by name */
  async getNodeByName(name: string): Promise<V2exNode> {
    return this.http.get<V2exNode>(
      `${ApiConstants.API_NODE_SHOW}?${ApiService.queryParam('name', name)}`,
    )
  }

  /** Get user info */
  async getMember(username: string): Promise<V2exMemberProfile> {
    const clean = (username || '').trim()
    if (!clean) {
      throw ApiErrors.invalidUsername()
    }
    try {
      const html = await this.http.getText(`/member/${encodeURIComponent(clean)}`)
      return ApiService.memberProfileFromHtml(clean, html)
    } catch (error) {
      DiagnosticLogger.exception('network', 'member_profile_html_fallback_exception', error as Error, { username: clean })
      return this.http.get<V2exMemberProfile>(
        `${ApiConstants.API_MEMBER_SHOW}?${ApiService.queryParam('username', clean)}`,
      )
    }
  }

  /** Get topics, replies, and available actions from member page. Topic list respects user's web hide settings. */
  async getMemberPageSnapshot(
    username: string,
    cookie: string = '',
  ): Promise<V2exMemberPageSnapshot> {
    const clean = (username || '').trim()
    if (!clean) {
      throw ApiErrors.invalidUsername()
    }
    const path = `/member/${encodeURIComponent(clean)}`
    const html = cookie ? await this.getCookieHtml(path, cookie) : await this.http.getText(path)
    return V2exMemberPageParser.parse(html, clean)
  }

  async getMemberTopicsPage(
    username: string,
    page: number = 1,
    cookie: string = '',
  ): Promise<V2exMemberTopicsPageSnapshot> {
    const clean = (username || '').trim()
    if (!clean) {
      throw ApiErrors.invalidUsername()
    }
    const safePage = Math.max(1, Math.floor(page))
    const path = `/member/${encodeURIComponent(clean)}/topics?p=${safePage}`
    const html = cookie ? await this.getCookieHtml(path, cookie) : await this.http.getText(path)
    return V2exMemberPageParser.parseTopicsPage(html)
  }

  async getMemberRepliesPage(
    username: string,
    page: number = 1,
    cookie: string = '',
  ): Promise<V2exMemberRepliesPageSnapshot> {
    const clean = (username || '').trim()
    if (!clean) {
      throw ApiErrors.invalidUsername()
    }
    const safePage = Math.max(1, Math.floor(page))
    const path = `/member/${encodeURIComponent(clean)}/replies?p=${safePage}`
    const html = cookie ? await this.getCookieHtml(path, cookie) : await this.http.getText(path)
    return V2exMemberPageParser.parseRepliesPage(html)
  }

  /** Get site info */
  async getSiteInfo(): Promise<V2exSiteInfo> {
    return this.http.get<V2exSiteInfo>(ApiConstants.API_SITE_INFO)
  }

  // ==================== V2 Token Read-only endpoints ====================

  async getAuthenticatedMember(token: string): Promise<V2exAuthenticatedMember> {
    return this.http.getWithHeaders<V2exAuthenticatedMember>(
      ApiConstants.API_V2_MEMBER,
      ApiService.authHeaders(token),
    )
  }

  async getTokenInfo(token: string): Promise<V2exTokenInfo> {
    return this.http.getWithHeaders<V2exTokenInfo>(
      ApiConstants.API_V2_TOKEN,
      ApiService.authHeaders(token),
    )
  }

  async getNotifications(token: string, page: number = 1): Promise<V2exNotification[]> {
    return this.http.getWithHeaders<V2exNotification[]>(
      `${ApiConstants.API_V2_NOTIFICATIONS}?p=${page}`,
      ApiService.authHeaders(token),
    )
  }

  async getNotificationsWithCookie(cookie: string, page: number = 1): Promise<V2exNotification[]> {
    if (!cookie) {
      throw ApiErrors.authRequired()
    }
    const html = await this.getCookieHtml(`/notifications?p=${page}`, cookie)
    if (!V2exSessionParser.extractUsername(html)) {
      throw ApiErrors.webSessionExpired()
    }
    return V2exNotificationParser.extractNotifications(html)
  }

  async getNotificationUnreadCountWithCookie(cookie: string): Promise<number> {
    if (!cookie) {
      return 0
    }
    const html = await this.getCookieHtml('/', cookie)
    if (!V2exSessionParser.extractUsername(html)) {
      throw ApiErrors.webSessionExpired()
    }
    return V2exSessionParser.extractUnreadNotificationCount(html)
  }

  async deleteNotificationWithCookie(
    cookie: string,
    notificationId: number,
    once: string,
    verifyPage: number = 1
  ): Promise<void> {
    if (!cookie) {
      throw ApiErrors.authRequired()
    }
    if (notificationId <= 0 || !once) {
      throw ApiErrors.missingNotificationParam()
    }
    const safeVerifyPage = Math.max(1, Math.floor(verifyPage))
    console.info(`[NotificationDelete] cookie start id=${notificationId} page=${safeVerifyPage}`)
    const action = await this.latestNotificationDeleteAction(cookie, notificationId, safeVerifyPage)
    if (action.id <= 0) {
      console.info(`[NotificationDelete] cookie already_deleted id=${notificationId} page=${safeVerifyPage}`)
      return
    }
    if (action.id !== notificationId || action.once !== once) {
      console.info(`[NotificationDelete] cookie refreshed_action id=${notificationId} fresh=${action.id} page=${safeVerifyPage}`)
    }
    const res = await this.deleteNotificationWithCookieRequest(cookie, action.id, action.once)
    console.info(`[NotificationDelete] cookie request_done id=${action.id} status=${res.statusCode} signin=${res.location.indexOf('/signin') >= 0}`)
    if (res.location.indexOf('/signin') >= 0) {
      throw ApiErrors.webSessionExpired()
    }
    if (await this.isNotificationDeletedFromCookiePage(cookie, action.id, safeVerifyPage)) {
      console.info(`[NotificationDelete] cookie verified id=${action.id} page=${safeVerifyPage}`)
      return
    }
    console.error(`[NotificationDelete] cookie verify_failed id=${action.id} page=${safeVerifyPage}`)
    throw ApiErrors.notificationDeleteNotApplied()
  }

  private async deleteNotificationWithCookieRequest(
    cookie: string,
    notificationId: number,
    once: string
  ): Promise<CookieHtmlResponse> {
    try {
      return await this.requestHtmlWithCookieAllowRedirect(
        `/delete/notification/${notificationId}?once=${encodeURIComponent(once)}`,
        cookie,
        '/notifications',
        http.RequestMethod.POST,
        '',
        {
          'Accept': '*/*',
          'X-Requested-With': 'XMLHttpRequest'
        }
      )
    } catch (error) {
      const e = error as Error
      DiagnosticLogger.exception('network', 'notification_delete_cookie_request_exception', e, { notificationId: notificationId })
      console.error(`[NotificationDelete] cookie request_failed id=${notificationId} message=${ApiService.safeOperationErrorMessage(e)}`)
      throw new Error(ApiService.safeOperationErrorMessage(e))
    }
  }

  private async latestNotificationDeleteAction(
    cookie: string,
    notificationId: number,
    page: number
  ): Promise<NotificationDeleteAction> {
    const latest = await this.getNotificationsWithCookie(cookie, page)
    const item = latest.find((current: V2exNotification) => {
      return current.id === notificationId || current.delete_id === notificationId
    })
    if (!item) {
      return { id: 0, once: '' }
    }
    const id = item.delete_id || item.id || 0
    const once = (item.delete_once || '').trim()
    if (id <= 0 || !once) {
      throw ApiErrors.missingNotificationParam()
    }
    return { id, once }
  }

  private async isNotificationDeletedFromCookiePage(cookie: string, notificationId: number, page: number): Promise<boolean> {
    const latest = await this.getNotificationsWithCookie(cookie, page)
    return !latest.some((item: V2exNotification) => {
      return item.id === notificationId || item.delete_id === notificationId
    })
  }

  async getBalanceWithCookie(cookie: string): Promise<V2exBalance> {
    if (!cookie) {
      throw ApiErrors.authRequired()
    }
    const html = await this.getCookieHtml('/balance', cookie)
    if (!V2exSessionParser.extractUsername(html)) {
      throw ApiErrors.webSessionExpired()
    }
    return V2exAccountParser.extractBalance(html)
  }

  async getDailyMissionWithCookie(cookie: string): Promise<V2exDailyMission> {
    if (!cookie) {
      throw ApiErrors.authRequired()
    }
    const html = await this.getCookieHtml('/mission/daily', cookie)
    if (!V2exSessionParser.extractUsername(html)) {
      throw ApiErrors.webSessionExpired()
    }
    return V2exAccountParser.extractDailyMission(html)
  }

  async redeemDailyMissionWithCookie(
    cookie: string,
    redeemPath: string,
  ): Promise<V2exDailyMission> {
    if (!redeemPath) {
      throw ApiErrors.checkinNotAvailable()
    }
    await this.getCookieHtml(redeemPath, cookie)
    return this.getDailyMissionWithCookie(cookie)
  }

  async getMyTopicsWithCookie(cookie: string, page: number = 1): Promise<V2exTopic[]> {
    if (!cookie) {
      throw ApiErrors.authRequired()
    }
    const path = page > 1 ? `/my/topics?p=${page}` : '/my/topics'
    const html = await this.getCookieHtml(path, cookie)
    if (!V2exSessionParser.extractUsername(html)) {
      throw ApiErrors.webSessionExpired()
    }
    const ids = V2exTabParser.extractTopicIds(html)
    if (ids.length === 0) {
      return []
    }
    return this.getTopicsByIds(ids)
  }

  async getMyRepliesWithCookie(cookie: string, page: number = 1): Promise<V2exTopic[]> {
    if (!cookie) {
      throw ApiErrors.authRequired()
    }
    const username = await this.getSessionUsernameWithCookie(cookie)
    const encodedUsername = encodeURIComponent(username)
    const path =
      page > 1
        ? `/member/${encodedUsername}/replies?p=${page}`
        : `/member/${encodedUsername}/replies`
    const html = await this.getCookieHtml(path, cookie)
    const ids = V2exTabParser.extractTopicIds(html)
    if (ids.length === 0) {
      return []
    }
    return this.getTopicsByIds(ids)
  }

  private async getSessionUsernameWithCookie(cookie: string): Promise<string> {
    const html = await this.getCookieHtml('/settings', cookie)
    const username = V2exSessionParser.extractUsername(html)
    if (!username) {
      throw ApiErrors.webSessionExpired()
    }
    return username
  }

  async getMyFavoriteNodesWithCookie(cookie: string): Promise<V2exFavoriteNode[]> {
    if (!cookie) {
      throw ApiErrors.authRequired()
    }
    const html = await this.getCookieHtml('/my/nodes', cookie)
    if (!V2exSessionParser.extractUsername(html)) {
      throw ApiErrors.webSessionExpired()
    }
    return V2exNodeParser.extractFavoriteNodes(html)
  }

  async getFollowingMembersWithCookie(cookie: string): Promise<V2exAccountMemberListItem[]> {
    if (!cookie) {
      throw ApiErrors.authRequired()
    }
    const currentUsername = await this.getSessionUsernameWithCookie(cookie)
    const html = await this.getCookieHtml('/my/following', cookie)
    if (html.indexOf('/signin') >= 0 && !V2exSessionParser.extractUsername(html)) {
      throw ApiErrors.webSessionExpired()
    }
    return V2exAccountListParser.extractMembers(html, currentUsername)
  }

  // ==================== Cookie account actions (site favorites/follows) ====================

  /**
   * Get the favorite/unfavorite toggle link for a topic (requires Cookie session)
   */
  async getTopicFavoriteToggleActionWithCookie(
    cookie: string,
    topicId: number,
  ): Promise<V2exToggleAction> {
    if (!cookie) {
      throw ApiErrors.authRequired()
    }
    if (topicId <= 0) {
      throw ApiErrors.invalidTopicId()
    }
    const topicPath = `/t/${topicId}`
    const html = await this.getCookieHtml(topicPath, cookie)
    if (!V2exSessionParser.extractUsername(html)) {
      throw ApiErrors.webSessionExpired()
    }

    const toggle = V2exCollectionActionParser.extractTopicFavoriteToggle(html, topicId)
    if (!toggle) {
      throw ApiErrors.parseFavoriteActionFailed()
    }
    return toggle
  }

  /**
   * Execute topic favorite toggle (requires Cookie session)
   * - Returns favorite state after operation
   */
  async executeTopicFavoriteToggleWithCookie(
    cookie: string,
    topicId: number,
    toggle: V2exToggleAction,
  ): Promise<boolean> {
    if (!cookie) {
      throw ApiErrors.authRequired()
    }
    if (topicId <= 0) {
      throw ApiErrors.invalidTopicId()
    }
    const topicPath = `/t/${topicId}`
    await this.requestTextWithCookieAllowRedirect(toggle.actionPath, cookie, topicPath)

    const verifyHtml = await this.getCookieHtml(topicPath, cookie)
    if (!V2exSessionParser.extractUsername(verifyHtml)) {
      throw ApiErrors.webSessionExpired()
    }
    const after = V2exCollectionActionParser.extractTopicFavoriteToggle(verifyHtml, topicId)
    if (!after) {
      return !toggle.currentlyOn
    }
    return after.currentlyOn
  }

  /**
   * Site favorite/unfavorite topic (requires Cookie session)
   * - Returns favorite state after operation
   */
  async toggleTopicFavoriteWithCookie(cookie: string, topicId: number): Promise<boolean> {
    const toggle = await this.getTopicFavoriteToggleActionWithCookie(cookie, topicId)
    return this.executeTopicFavoriteToggleWithCookie(cookie, topicId, toggle)
  }

  /**
   * Get the follow/unfollow toggle link for a node (requires Cookie session)
   */
  async getNodeFavoriteToggleActionWithCookie(
    cookie: string,
    nodeName: string,
  ): Promise<V2exToggleAction> {
    const cleanName = (nodeName || '').trim()
    if (!cookie) {
      throw ApiErrors.authRequired()
    }
    if (!cleanName) {
      throw ApiErrors.invalidNode()
    }
    const nodePath = `/go/${cleanName}`
    const html = await this.getCookieHtml(nodePath, cookie)
    if (!V2exSessionParser.extractUsername(html)) {
      throw ApiErrors.webSessionExpired()
    }
    const toggle = V2exCollectionActionParser.extractNodeFavoriteToggle(html)
    if (!toggle) {
      throw ApiErrors.parseFollowActionFailed()
    }
    return toggle
  }

  /**
   * Execute node follow toggle (requires Cookie session)
   * - Returns follow state after operation
   */
  async executeNodeFavoriteToggleWithCookie(
    cookie: string,
    nodeName: string,
    toggle: V2exToggleAction,
  ): Promise<boolean> {
    const cleanName = (nodeName || '').trim()
    if (!cookie) {
      throw ApiErrors.authRequired()
    }
    if (!cleanName) {
      throw ApiErrors.invalidNode()
    }
    const nodePath = `/go/${cleanName}`
    await this.requestTextWithCookieAllowRedirect(toggle.actionPath, cookie, nodePath)

    const verifyHtml = await this.getCookieHtml(nodePath, cookie)
    if (!V2exSessionParser.extractUsername(verifyHtml)) {
      throw ApiErrors.webSessionExpired()
    }
    const after = V2exCollectionActionParser.extractNodeFavoriteToggle(verifyHtml)
    if (!after) {
      return !toggle.currentlyOn
    }
    return after.currentlyOn
  }

  /**
   * Site follow/unfollow node (requires Cookie session)
   * - Returns follow state after operation
   */
  async toggleNodeFavoriteWithCookie(cookie: string, nodeName: string): Promise<boolean> {
    const toggle = await this.getNodeFavoriteToggleActionWithCookie(cookie, nodeName)
    return this.executeNodeFavoriteToggleWithCookie(cookie, nodeName, toggle)
  }

  async executeMemberActionWithCookie(
    cookie: string,
    username: string,
    actionPath: string,
  ): Promise<V2exMemberPageSnapshot> {
    const cleanName = (username || '').trim()
    const cleanPath = (actionPath || '').trim()
    if (!cookie) {
      throw ApiErrors.authRequired()
    }
    if (!cleanName || !cleanPath) {
      throw ApiErrors.missingUserAction()
    }
    const memberPath = `/member/${encodeURIComponent(cleanName)}`
    const actionRes = await this.requestHtmlWithCookieAllowRedirect(
      cleanPath,
      cookie,
      memberPath,
      http.RequestMethod.GET,
    )
    if (actionRes.location.indexOf('/signin') >= 0) {
      throw ApiErrors.webSessionExpired()
    }
    return this.getMemberPageSnapshot(cleanName, cookie)
  }

  /**
   * Submit topic reply (requires Cookie session)
   */
  async submitReplyWithCookie(cookie: string, topicId: number, content: string): Promise<void> {
    const cleanContent = (content || '').trim()
    if (!cookie) {
      throw ApiErrors.authRequired()
    }
    if (topicId <= 0) {
      throw ApiErrors.invalidTopicId()
    }
    if (!cleanContent) {
      throw ApiErrors.replyBodyRequired()
    }
    const topicPath = `/t/${topicId}`
    const html = await this.getCookieHtml(topicPath, cookie)
    if (!V2exSessionParser.extractUsername(html)) {
      throw ApiErrors.webSessionExpired()
    }
    const form = V2exWriteFormParser.extractReplyForm(html)
    if (!form) {
      throw ApiErrors.parseReplyFormFailed()
    }

    const fields: Record<string, string> = {}
    const hiddenKeys = Object.keys(form.hiddenFields)
    for (const key of hiddenKeys) {
      fields[key] = form.hiddenFields[key]
    }
    fields[form.contentField] = cleanContent
    // V2EX has changed the reply textarea/id/name shape more than once. Send the
    // observed field plus stable aliases so the server receives the body even
    // when the parser picked an id-like field name from current markup.
    fields['content'] = cleanContent
    fields['reply_content'] = cleanContent
    const body = ApiService.encodeFormFields(fields)

    // V2EX replies are submitted to the topic URL itself. The parsed form is
    // used for the current once/content field names, but relying on the action
    // attribute can silently post to a non-mutating page when the page markup
    // changes or another form is selected.
    const res = await this.requestHtmlWithCookieAllowRedirect(
      topicPath,
      cookie,
      topicPath,
      http.RequestMethod.POST,
      body,
    )
    if (res.location.indexOf('/signin') >= 0) {
      throw ApiErrors.webSessionExpired()
    }
    if (ApiService.isTopicLocation(res.location, topicId)) {
      return
    }
    const username = V2exSessionParser.extractUsername(html)
    if (await this.hasSubmittedReplyOnLastPage(cookie, topicId, username, cleanContent)) {
      return
    }
    const problem = V2exSigninParser.extractProblemMessage(res.text)
    if (problem) {
      throw ApiErrors.submitFailedDetail(problem)
    }
    throw ApiErrors.replySubmitUnconfirmed()
  }

  async getReplyThankActionWithCookie(
    cookie: string,
    topicId: number,
    replyId: number,
  ): Promise<V2exReplyThankAction> {
    if (!cookie) {
      throw ApiErrors.authRequired()
    }
    if (topicId <= 0 || replyId <= 0) {
      throw ApiErrors.invalidReply()
    }
    const topicPath = `/t/${topicId}`
    const html = await this.getCookieHtml(topicPath, cookie)
    if (!V2exSessionParser.extractUsername(html)) {
      throw ApiErrors.webSessionExpired()
    }
    const actionPath = ApiService.extractReplyThankPath(html, replyId)
    if (!actionPath) {
      throw ApiErrors.replyThankNotAllowed()
    }
    return { replyId, actionPath }
  }

  async executeReplyThankWithCookie(
    cookie: string,
    topicId: number,
    action: V2exReplyThankAction,
  ): Promise<void> {
    if (!cookie) {
      throw ApiErrors.authRequired()
    }
    if (topicId <= 0 || !action || action.replyId <= 0 || !action.actionPath) {
      throw ApiErrors.missingThankAction()
    }
    const topicPath = `/t/${topicId}`
    const res = await this.requestHtmlWithCookieAllowRedirect(
      action.actionPath,
      cookie,
      topicPath,
      http.RequestMethod.POST,
    )
    if (res.location.indexOf('/signin') >= 0) {
      throw ApiErrors.webSessionExpired()
    }
    ApiService.assertThankResponse(res.text)
    const problem = V2exSigninParser.extractProblemMessage(res.text)
    if (problem) {
      throw ApiErrors.thankFailed(problem)
    }
  }

  async getTopicThankActionWithCookie(
    cookie: string,
    topicId: number,
  ): Promise<V2exTopicThankAction> {
    if (!cookie) {
      throw ApiErrors.authRequired()
    }
    if (topicId <= 0) {
      throw ApiErrors.invalidTopicId()
    }
    const topicPath = `/t/${topicId}`
    const html = await this.getCookieHtml(topicPath, cookie)
    if (!V2exSessionParser.extractUsername(html)) {
      throw ApiErrors.webSessionExpired()
    }
    const actionPath = ApiService.extractTopicThankPath(html, topicId)
    if (!actionPath) {
      throw ApiErrors.topicThankNotAllowed()
    }
    return { topicId, actionPath }
  }

  async executeTopicThankWithCookie(cookie: string, action: V2exTopicThankAction): Promise<void> {
    if (!cookie) {
      throw ApiErrors.authRequired()
    }
    if (!action || action.topicId <= 0 || !action.actionPath) {
      throw ApiErrors.missingThankAction()
    }
    const topicPath = `/t/${action.topicId}`
    const res = await this.requestHtmlWithCookieAllowRedirect(
      action.actionPath,
      cookie,
      topicPath,
      http.RequestMethod.POST,
    )
    if (res.location.indexOf('/signin') >= 0) {
      throw ApiErrors.webSessionExpired()
    }
    ApiService.assertThankResponse(res.text)
    const problem = V2exSigninParser.extractProblemMessage(res.text)
    if (problem) {
      throw ApiErrors.thankFailed(problem)
    }
  }

  async getTopicIgnoreActionWithCookie(
    cookie: string,
    topicId: number,
  ): Promise<V2exTopicModerationAction> {
    const actionPath = await this.getCookieActionPath(
      cookie,
      topicId,
      'ignore',
      'topic',
      topicId,
      'Topic cannot be ignored or already ignored',
    )
    return { topicId, actionPath }
  }

  async executeTopicIgnoreWithCookie(
    cookie: string,
    action: V2exTopicModerationAction,
  ): Promise<void> {
    if (!action || action.topicId <= 0 || !action.actionPath) {
      throw ApiErrors.missingIgnoreAction()
    }
    await this.executeCookieActionWithCookie(
      cookie,
      action.actionPath,
      `/t/${action.topicId}`,
      'Ignore failed',
    )
  }

  async getReplyIgnoreActionWithCookie(
    cookie: string,
    topicId: number,
    replyId: number,
  ): Promise<V2exReplyModerationAction> {
    const actionPath = await this.getCookieActionPath(
      cookie,
      topicId,
      'ignore',
      'reply',
      replyId,
      'Reply cannot be ignored or already ignored',
    )
    return { replyId, actionPath }
  }

  async executeReplyIgnoreWithCookie(
    cookie: string,
    topicId: number,
    action: V2exReplyModerationAction,
  ): Promise<void> {
    if (!action || action.replyId <= 0 || !action.actionPath) {
      throw ApiErrors.missingIgnoreAction()
    }
    await this.executeCookieActionWithCookie(cookie, action.actionPath, `/t/${topicId}`, 'Ignore failed')
  }

  async getTopicReportActionWithCookie(
    cookie: string,
    topicId: number,
  ): Promise<V2exTopicModerationAction> {
    const actionPath = await this.getCookieActionPath(
      cookie,
      topicId,
      'report',
      'topic',
      topicId,
      'Topic cannot be reported or already reported',
    )
    return { topicId, actionPath }
  }

  async executeTopicReportWithCookie(
    cookie: string,
    action: V2exTopicModerationAction,
  ): Promise<void> {
    if (!action || action.topicId <= 0 || !action.actionPath) {
      throw ApiErrors.missingReportAction()
    }
    await this.executeCookieActionWithCookie(
      cookie,
      action.actionPath,
      `/t/${action.topicId}`,
      'Report failed',
    )
  }

  async getReplyReportActionWithCookie(
    cookie: string,
    topicId: number,
    replyId: number,
  ): Promise<V2exReplyModerationAction> {
    const actionPath = await this.getCookieActionPath(
      cookie,
      topicId,
      'report',
      'reply',
      replyId,
      'Reply cannot be reported or already reported',
    )
    return { replyId, actionPath }
  }

  async executeReplyReportWithCookie(
    cookie: string,
    topicId: number,
    action: V2exReplyModerationAction,
  ): Promise<void> {
    if (!action || action.replyId <= 0 || !action.actionPath) {
      throw ApiErrors.missingReportAction()
    }
    await this.executeCookieActionWithCookie(cookie, action.actionPath, `/t/${topicId}`, 'Report failed')
  }

  /**
   * Submit new topic (requires Cookie session)
   * - Returns new topic ID (0 when unparseable)
   */
  async createTopicWithCookie(
    cookie: string,
    nodeName: string,
    title: string,
    content: string,
  ): Promise<number> {
    const cleanNode = (nodeName || '').trim()
    const cleanTitle = (title || '').trim()
    const cleanContent = (content || '').trim()
    if (!cookie) {
      throw ApiErrors.authRequired()
    }
    if (!cleanNode) {
      throw ApiErrors.nodeRequired()
    }
    if (!cleanTitle) {
      throw ApiErrors.titleRequired()
    }
    if (!cleanContent) {
      throw ApiErrors.bodyRequired()
    }

    const composePath = `/new/${cleanNode}`
    const composeRes = await this.requestHtmlWithCookieAllowRedirect(
      composePath,
      cookie,
      composePath,
      http.RequestMethod.GET,
    )
    if (composeRes.location.indexOf('/signin') >= 0) {
      throw ApiErrors.webSessionExpired()
    }
    const html = composeRes.text
    if (!V2exSessionParser.extractUsername(html)) {
      throw ApiErrors.webSessionExpired()
    }
    const form = V2exWriteFormParser.extractTopicCreateForm(html)
    if (!form) {
      throw ApiErrors.parseTopicFormFailed()
    }

    const fields: Record<string, string> = {}
    const hiddenKeys = Object.keys(form.hiddenFields)
    for (const key of hiddenKeys) {
      fields[key] = form.hiddenFields[key]
    }
    fields[form.titleField] = cleanTitle
    fields[form.contentField] = cleanContent
    const body = ApiService.encodeFormFields(fields)

    const res = await this.requestHtmlWithCookieAllowRedirect(
      form.actionPath,
      cookie,
      composePath,
      http.RequestMethod.POST,
      body,
    )
    if (res.location.indexOf('/signin') >= 0) {
      throw ApiErrors.webSessionExpired()
    }

    const topicFromLocation = ApiService.extractTopicId(res.location)
    if (topicFromLocation > 0) {
      return topicFromLocation
    }
    const topicFromText = ApiService.extractTopicId(res.text)
    if (topicFromText > 0) {
      return topicFromText
    }

    const problem = V2exSigninParser.extractProblemMessage(res.text)
    if (problem) {
      throw ApiErrors.submitFailedDetail(problem)
    }
    return 0
  }

  private async getCookieHtml(path: string, cookie: string): Promise<string> {
    const endpoint = this.cookieEndpoint(path)
    const res = await this.http.getTextResponseWithHeaders(endpoint, { 'Cookie': cookie })
    this.assertNoTwoFactorChallenge(endpoint, res.text, res.location)
    return res.text
  }

  private topicWebRepliesClient(): V2exTopicWebRepliesClient {
    return new V2exTopicWebRepliesClient(this.http, (path: string, cookie: string): Promise<string> => {
      return this.getCookieHtml(path, cookie)
    })
  }

  private cookieEndpoint(pathOrUrl: string): string {
    const clean = (pathOrUrl || '').trim()
    if (!clean) {
      return '/'
    }
    const baseUrl = this.http.getBaseUrl().replace(/\/+$/, '')
    if (clean.startsWith(baseUrl)) {
      const endpoint = clean.slice(baseUrl.length)
      return endpoint || '/'
    }
    if (clean.startsWith('http://') || clean.startsWith('https://')) {
      const schemeIdx = clean.indexOf('://')
      const pathStart = clean.indexOf('/', schemeIdx + 3)
      return pathStart >= 0 ? clean.slice(pathStart) : '/'
    }
    return clean.startsWith('/') ? clean : `/${clean}`
  }

  private assertNoTwoFactorChallenge(path: string, text: string, location: string): void {
    if (
      ApiService.isLocationPath(location, '/2fa') ||
      V2exSigninParser.extractTwoFactorForm(text)
    ) {
      throw new V2exCookieTwoFactorRequiredError(path)
    }
  }

  private static isLocationPath(location: string, path: string): boolean {
    if (!location || !path) {
      return false
    }
    const normalized = ApiService.locationPath(location)
    return normalized === path || normalized.indexOf(`${path}?`) === 0
  }

  private static locationPath(location: string): string {
    const trimmed = (location || '').trim()
    if (!trimmed) {
      return ''
    }
    const schemeIdx = trimmed.indexOf('://')
    if (schemeIdx >= 0) {
      const pathStart = trimmed.indexOf('/', schemeIdx + 3)
      return pathStart >= 0 ? trimmed.slice(pathStart) : '/'
    }
    if (trimmed.indexOf('/') !== 0) {
      return `/${trimmed}`
    }
    return trimmed
  }

  private async requestTextWithCookieAllowRedirect(
    pathOrUrl: string,
    cookie: string,
    refererPath: string,
  ): Promise<void> {
    const clean = (pathOrUrl || '').trim()
    if (!clean) {
      throw ApiErrors.missingActionPath()
    }
    const urls = ApiService.resolveCookieRequestUrls(this.http.getBaseUrl(), clean, refererPath)
    const url = urls.url
    const refererUrl = urls.refererUrl

    try {
      const requestHeaders: Record<string, string> = {
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Encoding': 'gzip',
        'Content-Type': 'text/html; charset=utf-8',
        'Cookie': cookie,
        'User-Agent': 'Mozilla/5.0',
      }
      if (refererUrl) {
        requestHeaders['Referer'] = refererUrl
      }

      const response = await NetworkProxyRequest.request(url, {
        method: http.RequestMethod.GET,
        header: requestHeaders,
        connectTimeout: this.CONNECT_TIMEOUT_MS,
        readTimeout: this.READ_TIMEOUT_MS,
        usingCache: false,
        expectDataType: http.HttpDataType.STRING,
      })
      const statusCode = response.responseCode as number
      const location = ApiService.extractHeaderValue(response.header, 'location')
      DiagnosticLogger.info('network', 'cookie_private_request_status', {
        method: 'GET',
        url: url,
        statusCode: statusCode,
        location: location,
        hasCookie: true
      })
      if (ApiService.isLocationPath(location, '/2fa')) {
        throw new V2exCookieTwoFactorRequiredError(clean)
      }
      if (statusCode < 200 || statusCode >= 400) {
        throw new Error(`HTTP ${statusCode}: ${url}`)
      }
    } catch (error) {
      const e = error as Error
      DiagnosticLogger.exception('network', 'cookie_private_request_exception', e, { pathOrUrl: clean, url: url })
      throw e
    }
  }

  private async requestHtmlWithCookieAllowRedirect(
    pathOrUrl: string,
    cookie: string,
    refererPath: string,
    method: http.RequestMethod,
    extraData: string = '',
    extraHeaders: Record<string, string> = {},
  ): Promise<CookieHtmlResponse> {
    const clean = (pathOrUrl || '').trim()
    if (!clean) {
      throw ApiErrors.missingActionPath()
    }
    const urls = ApiService.resolveCookieRequestUrls(this.http.getBaseUrl(), clean, refererPath)
    const url = urls.url
    const refererUrl = urls.refererUrl

    let headerBag: Object | null = null
    try {
      const requestHeaders: Record<string, string> = {
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Encoding': 'gzip',
        'Content-Type':
          method === http.RequestMethod.POST
            ? 'application/x-www-form-urlencoded'
            : 'text/html; charset=utf-8',
        'Cookie': cookie,
        'User-Agent': 'Mozilla/5.0',
      }
      if (refererUrl) {
        requestHeaders['Referer'] = refererUrl
      }
      Object.keys(extraHeaders).forEach((key: string) => {
        requestHeaders[key] = extraHeaders[key]
      })

      const options: http.HttpRequestOptions = {
        method: method,
        header: requestHeaders,
        connectTimeout: this.CONNECT_TIMEOUT_MS,
        readTimeout: this.READ_TIMEOUT_MS,
        usingCache: false,
        expectDataType: http.HttpDataType.STRING,
      }
      if (method === http.RequestMethod.POST && extraData) {
        options.extraData = extraData
      }
      const response = await NetworkProxyRequest.request(url, {
        method: method,
        header: requestHeaders,
        connectTimeout: this.CONNECT_TIMEOUT_MS,
        readTimeout: this.READ_TIMEOUT_MS,
        usingCache: false,
        expectDataType: http.HttpDataType.STRING,
        extraData: method === http.RequestMethod.POST ? extraData : '',
        onHeadersReceive: (headers: Object) => { headerBag = headers },
      })
      const statusCode = response.responseCode as number
      const text = (response.result as string) || ''
      const location = ApiService.extractHeaderValue(headerBag || response.header, 'location')
      DiagnosticLogger.info('network', 'cookie_html_request_status', {
        method: method === http.RequestMethod.POST ? 'POST' : 'GET',
        url: url,
        refererUrl: refererUrl,
        statusCode: statusCode,
        location: location,
        hasCookie: true,
        bodyLength: text.length
      })
      this.assertNoTwoFactorChallenge(clean, text, location)
      if (statusCode < 200 || statusCode >= 400) {
        throw new Error(`HTTP ${statusCode}: ${url}`)
      }
      return { statusCode, text, location }
    } catch (error) {
      const e = error as Error
      DiagnosticLogger.exception('network', 'cookie_html_request_exception', e, { pathOrUrl: clean, url: url, refererUrl: refererUrl })
      throw e
    }
  }

  private static extractHeaderValue(headers: Object, key: string): string {
    const cleanKey = (key || '').trim().toLowerCase()
    if (!cleanKey) {
      return ''
    }
    try {
      const bag = headers as Record<string, Object>
      const value =
        bag[cleanKey] || bag[key] || bag[cleanKey.toUpperCase()] || bag[key.toUpperCase()] || ''
      if (typeof value === 'string') {
        return value
      }
      if (Array.isArray(value)) {
        const items = value.filter((v: Object) => typeof v === 'string') as string[]
        return items.length > 0 ? items[0] : ''
      }
      return ''
    } catch (_e) {
      return ''
    }
  }

  private static resolveCookieRequestUrls(baseUrl: string, pathOrUrl: string, refererPath: string): SameOriginRequestUrls {
    const url = ApiService.resolveSameOriginUrl(baseUrl, pathOrUrl, 'action path')
    const refererClean = (refererPath || '').trim()
    const refererUrl = refererClean ? ApiService.resolveSameOriginUrl(baseUrl, refererClean, 'referer path') : ''
    return { url, refererUrl }
  }

  private static resolveSameOriginUrl(baseUrl: string, pathOrUrl: string, label: string): string {
    const clean = (pathOrUrl || '').trim()
    if (!clean) {
      throw ApiErrors.fieldRequiredDetail(label)
    }
    if (clean.startsWith('http://') || clean.startsWith('https://')) {
      const baseOrigin = ApiService.urlOrigin(baseUrl)
      const targetOrigin = ApiService.urlOrigin(clean)
      if (!baseOrigin || targetOrigin !== baseOrigin) {
        throw ApiErrors.fieldExternalLinkForbidden(label)
      }
      return clean
    }
    return clean.startsWith('/') ? `${baseUrl}${clean}` : `${baseUrl}/${clean}`
  }

  private static urlOrigin(url: string): string {
    const clean = (url || '').trim()
    const schemeIdx = clean.indexOf('://')
    if (schemeIdx < 0) {
      return ''
    }
    const pathStart = clean.indexOf('/', schemeIdx + 3)
    return (pathStart >= 0 ? clean.slice(0, pathStart) : clean).toLowerCase()
  }

  private static extractTopicId(text: string): number {
    const m = (text || '').match(/\/t\/(\d+)/i)
    if (!m || !m[1]) {
      return 0
    }
    const parsed = parseInt(m[1], 10)
    return Number.isFinite(parsed) ? parsed : 0
  }

  private static encodeFormFields(fields: Record<string, string>): string {
    const keys = Object.keys(fields)
    if (keys.length === 0) {
      return ''
    }
    const encodedPairs: string[] = []
    for (const key of keys) {
      encodedPairs.push(`${encodeURIComponent(key)}=${encodeURIComponent(fields[key] || '')}`)
    }
    return encodedPairs.join('&')
  }

  private static safeOperationErrorMessage(error: Error): string {
    const message = error.message || 'Request failed'
    return message
      .replace(/once=[^\s&]+/gi, 'once=<redacted>')
      .replace(/https?:\/\/[^\s]+/gi, '<url>')
  }

  private static extractReplyThankPath(html: string, replyId: number): string {
    if (!html || replyId <= 0) {
      return ''
    }
    const direct = new RegExp(
      `['"]([^'"]*\\/thank\\/reply\\/${replyId}\\?once=\\d+[^'"]*)['"]`,
      'i',
    )
    const directMatch = html.match(direct)
    if (directMatch && directMatch[1]) {
      return ApiService.decodeHtml(directMatch[1])
    }
    const loose = new RegExp(`\\/thank\\/reply\\/${replyId}\\?once=\\d+`, 'i')
    const looseMatch = html.match(loose)
    if (looseMatch && looseMatch[0]) {
      return ApiService.decodeHtml(looseMatch[0])
    }
    const jsCall = new RegExp(`thankReply\\(\\s*${replyId}\\s*\\)`, 'i')
    if (jsCall.test(html)) {
      const globalOnceMatch = html.match(/(?:var|let|const)\s+once\s*=\s*['\"]?(\d+)['\"]?/i)
      if (globalOnceMatch && globalOnceMatch[1]) {
        return `/thank/reply/${replyId}?once=${globalOnceMatch[1]}`
      }
    }
    return ''
  }

  private static extractTopicThankPath(html: string, topicId: number): string {
    if (!html || topicId <= 0) {
      return ''
    }
    const direct = new RegExp(
      `['"]([^'"]*\\/thank\\/topic\\/${topicId}\\?once=\\d+[^'"]*)['"]`,
      'i',
    )
    const directMatch = html.match(direct)
    if (directMatch && directMatch[1]) {
      return ApiService.decodeHtml(directMatch[1])
    }
    const loose = new RegExp(`\\/thank\\/topic\\/${topicId}\\?once=\\d+`, 'i')
    const looseMatch = html.match(loose)
    if (looseMatch && looseMatch[0]) {
      return ApiService.decodeHtml(looseMatch[0])
    }
    const jsCall = new RegExp(`thankTopic\\(\\s*${topicId}\\s*,\\s*['\"](\\d+)['\"]\\s*\\)`, 'i')
    const jsCallMatch = html.match(jsCall)
    if (jsCallMatch && jsCallMatch[1]) {
      return `/thank/topic/${topicId}?once=${jsCallMatch[1]}`
    }
    return ''
  }

  private static assertThankResponse(text: string): void {
    const clean = (text || '').trim()
    if (!clean || clean.charAt(0) !== '{') {
      return
    }
    try {
      const data = JSON.parse(clean) as Record<string, Object>
      if (data['success'] === false) {
        const message = (data['message'] as string) || 'Thank failed'
        throw ApiErrors.thankFailed(message)
      }
    } catch (error) {
      if (isApiError(error) && error.code === ApiErrorCode.THANK_FAILED) {
        throw error as ApiError
      }
      DiagnosticLogger.exception('network', 'thank_response_json_parse_exception', error as Error)
    }
  }

  private static extractCookieActionPath(
    html: string,
    action: string,
    target: string,
    targetId: number,
  ): string {
    if (!html || !action || !target || targetId <= 0) {
      return ''
    }
    const pattern = `\\/${action}\\/${target}\\/${targetId}\\?once=\\d+`
    const direct = new RegExp(`['"]([^'"]*${pattern}[^'"]*)['"]`, 'i')
    const directMatch = html.match(direct)
    if (directMatch && directMatch[1]) {
      return ApiService.decodeHtml(directMatch[1])
    }
    const loose = new RegExp(pattern, 'i')
    const looseMatch = html.match(loose)
    return looseMatch && looseMatch[0] ? ApiService.decodeHtml(looseMatch[0]) : ''
  }

  private async getCookieActionPath(
    cookie: string,
    topicId: number,
    action: string,
    target: string,
    targetId: number,
    missingMessage: string,
  ): Promise<string> {
    if (!cookie) {
      throw ApiErrors.authRequired()
    }
    if (topicId <= 0 || targetId <= 0) {
      throw ApiErrors.invalidOperationTarget()
    }
    const topicPath = `/t/${topicId}`
    const html = await this.getCookieHtml(topicPath, cookie)
    if (!V2exSessionParser.extractUsername(html)) {
      throw ApiErrors.webSessionExpired()
    }
    const actionPath = ApiService.extractCookieActionPath(html, action, target, targetId)
    if (!actionPath) {
      throw new Error(missingMessage)
    }
    return actionPath
  }

  private async executeCookieActionWithCookie(
    cookie: string,
    actionPath: string,
    refererPath: string,
    failurePrefix: string,
  ): Promise<void> {
    if (!cookie) {
      throw ApiErrors.authRequired()
    }
    if (!actionPath) {
      throw ApiErrors.missingActionPath()
    }
    const res = await this.requestHtmlWithCookieAllowRedirect(
      actionPath,
      cookie,
      refererPath,
      http.RequestMethod.GET,
    )
    if (res.location.indexOf('/signin') >= 0) {
      throw ApiErrors.webSessionExpired()
    }
    const problem = V2exSigninParser.extractProblemMessage(res.text)
    if (problem) {
      throw new Error(`${failurePrefix}：${problem}`)
    }
  }

  private static isTopicLocation(location: string, topicId: number): boolean {
    if (topicId <= 0) {
      return false
    }
    const path = ApiService.locationPath(location)
    return (
      path === `/t/${topicId}` ||
      path.indexOf(`/t/${topicId}?`) === 0 ||
      path.indexOf(`/t/${topicId}#`) === 0
    )
  }

  private async hasSubmittedReplyOnLastPage(
    cookie: string,
    topicId: number,
    username: string,
    content: string,
  ): Promise<boolean> {
    const cleanUsername = (username || '').trim()
    const cleanContent = ApiService.normalizeReplyProbeText(content)
    if (!cookie || topicId <= 0 || !cleanUsername || !cleanContent) {
      return false
    }
    try {
      const cacheBuster = Date.now()
      const firstPage = await this.getTopicWebRepliesPage(topicId, 1, cacheBuster, cookie)
      const lastPageNumber = Math.max(1, firstPage.pageCount)
      const lastPage =
        lastPageNumber === 1
          ? firstPage
          : await this.getTopicWebRepliesPage(topicId, lastPageNumber, cacheBuster, cookie)
      return lastPage.replies.some((reply: V2exReply) => {
        const replyUsername = reply && reply.member ? (reply.member.username || '').trim() : ''
        if (replyUsername !== cleanUsername) {
          return false
        }
        const replyContent = ApiService.normalizeReplyProbeText(
          reply.content || reply.content_rendered || '',
        )
        if (!replyContent) {
          return false
        }
        return replyContent.indexOf(cleanContent) >= 0 || cleanContent.indexOf(replyContent) >= 0
      })
    } catch (error) {
      const e = error as Error
      DiagnosticLogger.exception('network', 'verify_submitted_reply_exception', e, { topicId: topicId })
      console.error('verify submitted reply failed: ' + e.message)
      return false
    }
  }

  private static normalizeReplyProbeText(value: string): string {
    return HtmlEntityUtils.decode(
      (value || '')
        .replace(/<br\s*\/?>/gi, '\n')
        .replace(/<[^>]+>/g, '')
        .replace(/\r\n/g, '\n')
        .replace(/\r/g, '\n')
        .replace(/\s+/g, ' ')
        .trim(),
    )
  }

  private static decodeHtml(value: string): string {
    return (value || '')
      .replace(/&amp;/g, '&')
      .replace(/&quot;/g, '"')
      .replace(/&#39;/g, "'")
      .replace(/&lt;/g, '<')
      .replace(/&gt;/g, '>')
  }

  // ==================== Tab Aggregate endpoints ====================

  /**
   * Get topic list by tab key
   * - latest uses JSON API
   * - hot uses the site hottest tab (/?tab=hot), to avoid falling back to the daily 10 hot topics API
   * - Other tabs: scrape IDs from HTML first, then fetch details concurrently
   */
  async getTabTopics(tab: string): Promise<V2exTopic[]> {
    const nodeName = FeedTabSettings.nodeNameFromKey(tab)
    let topics: V2exTopic[]
    if (nodeName) {
      topics = await this.getTopicsByNode(nodeName)
    } else if (tab === 'latest') {
      topics = await this.getLatestTopics()
    } else if (tab === 'hot') {
      topics = await this.getHotTabTopics()
    } else {
      const html = await this.http.getText(ApiConstants.TAB_URLS[tab])
      const parsedTopics = V2exTabParser.parseTopicList(html)
      if (parsedTopics.length === 0) {
        throw ApiErrors.tabTopicsEmpty(tab)
      }
      topics = ApiService.normalizeTopics(parsedTopics)
    }
    return topics
  }

  async getTopicsByIds(ids: number[]): Promise<V2exTopic[]> {
    if (ids.length === 0) {
      return []
    }
    return this.getBatchTopics(ids)
  }

  /**
   * Batch fetch topic details (concurrent per ID, CONCURRENCY per batch)
   */
  private async getBatchTopics(ids: number[]): Promise<V2exTopic[]> {
    const CONCURRENCY = ApiConstants.TAB_HTML_BATCH_SIZE
    const results: V2exTopic[] = []
    for (let i = 0; i < ids.length; i += CONCURRENCY) {
      const batch = ids.slice(i, i + CONCURRENCY)
      const batchResults = await Promise.all(
        batch.map((id) => this.http.get<V2exTopic[]>(`${ApiConstants.API_TOPIC_SHOW}?id=${id}`)),
      )
      results.push(...batchResults.map((r) => r[0]).filter((t) => t !== undefined))
    }
    return ApiService.normalizeTopics(results)
  }

  private static topicFromHtml(topicId: number, html: string): V2exTopic {
    const headerMatch = (html || '').match(/<div[^>]*class=["']header["'][^>]*>([\s\S]*?)<\/div>\s*<div[^>]*class=["']cell["']/i)
    const header = headerMatch ? headerMatch[1] : html
    const title = ApiService.extractFirst(header, /<h1[^>]*>([\s\S]*?)<\/h1>/i)
    const author = ApiService.extractFirst(header, /<a[^>]*href=["']\/member\/([^"']+)["'][^>]*>/i)
    const nodeName = ApiService.extractFirst(header, /<a[^>]*href=["']\/go\/([^"']+)["'][^>]*>/i)
    const nodeTitle = ApiService.extractFirst(header, /<a[^>]*href=["']\/go\/[^"']+["'][^>]*>([\s\S]*?)<\/a>/i)
    const avatarTagMatch = header.match(/<img[^>]*class=["']avatar["'][^>]*>/i)
    const avatarTag = avatarTagMatch ? avatarTagMatch[0] : ''
    const avatar = ApiService.extractAttr(avatarTag, 'src')
    const memberId = ApiService.parseNumber(ApiService.extractAttr(avatarTag, 'data-uid'))
    const created = ApiService.parseTimeSeconds(ApiService.extractFirst(header, /<span[^>]*title=["']([^"']+\+08:00)["'][^>]*>/i))
    const contentRendered = ApiService.extractFirst(html, /<div[^>]*class=["'][^"']*\btopic_content\b[^"']*["'][^>]*>([\s\S]*?)<\/div>\s*<\/div>/i)
    const replies = ApiService.parseNumber(ApiService.extractFirst(html, /<span[^>]*class=["']gray["'][^>]*>(\d+)\s+repl(?:y|ies)/i))
    return {
      id: topicId,
      title: title,
      url: V2exUrlRouter.withSelectedBaseUrl(`/t/${topicId}`, HttpClient.getInstance().getBaseUrl()),
      content: ApiService.decodePlain(contentRendered),
      content_rendered: contentRendered,
      replies: replies,
      member: {
        id: memberId,
        username: author,
        tagline: '',
        avatar_mini: avatar,
        avatar_normal: avatar,
        avatar_large: avatar
      },
      node: {
        id: 0,
        name: nodeName,
        title: nodeTitle || nodeName,
        title_alternative: '',
        url: nodeName ? V2exUrlRouter.withSelectedBaseUrl(`/go/${nodeName}`, HttpClient.getInstance().getBaseUrl()) : '',
        topics: 0,
        avatar_mini: '',
        avatar_normal: '',
        avatar_large: ''
      },
      created: created,
      last_modified: created,
      last_touched: created
    }
  }

  private static memberProfileFromHtml(username: string, html: string): V2exMemberProfile {
    const clean = (username || '').trim()
    const avatarTagMatch = (html || '').match(/<img[^>]*class=["']avatar["'][^>]*alt=["'][^"']*["'][^>]*>/i) ||
      (html || '').match(/<img[^>]*alt=["'][^"']*["'][^>]*class=["']avatar["'][^>]*>/i)
    const avatarTag = avatarTagMatch ? avatarTagMatch[0] : ''
    const pageUsername = ApiService.extractFirst(html, /<h1[^>]*>([\s\S]*?)<\/h1>/i) || clean
    const memberId = ApiService.parseNumber(ApiService.extractFirst(html, /V2EX member #(\d+)/i) || ApiService.extractAttr(avatarTag, 'data-uid'))
    const avatar = ApiService.extractAttr(avatarTag, 'src')
    const created = ApiService.parseTimeSeconds(ApiService.extractFirst(html, /joined on ([^<]+?\+08:00)/i))
    return {
      status: pageUsername ? 'found' : 'unknown',
      id: memberId,
      url: V2exUrlRouter.withSelectedBaseUrl(`/member/${encodeURIComponent(clean)}`, HttpClient.getInstance().getBaseUrl()),
      username: ApiService.decodePlain(pageUsername || clean),
      website: '',
      twitter: '',
      psn: '',
      github: '',
      btc: '',
      location: '',
      tagline: '',
      bio: '',
      avatar_mini: avatar,
      avatar_normal: avatar,
      avatar_large: avatar,
      created: created
    }
  }

  private static normalizeTopics(topics: V2exTopic[]): V2exTopic[] {
    return (topics || []).map((topic: V2exTopic) => ApiService.normalizeTopic(topic))
  }

  private static normalizeNodeTopics(topics: V2exTopic[], nodeName: string, nodeTitle: string): V2exTopic[] {
    const cleanName = (nodeName || '').trim()
    const cleanTitle = (nodeTitle || cleanName).trim()
    return ApiService.normalizeTopics(topics).map((topic: V2exTopic): V2exTopic => {
      if (!topic || !cleanName) {
        return topic
      }
      if (!topic.node) {
        topic.node = {
          id: 0,
          name: cleanName,
          title: cleanTitle,
          title_alternative: '',
          url: V2exUrlRouter.withSelectedBaseUrl(`/go/${cleanName}`, HttpClient.getInstance().getBaseUrl()),
          topics: 0,
          avatar_mini: '',
          avatar_normal: '',
          avatar_large: ''
        }
        return topic
      }
      if (!topic.node.name) {
        topic.node.name = cleanName
      }
      if (!topic.node.title) {
        topic.node.title = cleanTitle
      }
      if (!topic.node.url) {
        topic.node.url = V2exUrlRouter.withSelectedBaseUrl(`/go/${cleanName}`, HttpClient.getInstance().getBaseUrl())
      }
      return topic
    })
  }

  private static normalizeTopic(topic: V2exTopic): V2exTopic {
    if (!topic) {
      return topic
    }
    // V2EX API payloads may keep canonical www URLs; selected site origin must
    // propagate to app-owned share/open/copy flows, not only network requests.
    topic.url = V2exUrlRouter.withSelectedBaseUrl(topic.url, HttpClient.getInstance().getBaseUrl())
    topic.title = HtmlEntityUtils.decode(topic.title)
    topic.content = HtmlEntityUtils.decode(topic.content)
    topic.content_rendered = HtmlEntityUtils.decode(topic.content_rendered)
    if (topic.node) {
      topic.node.url = V2exUrlRouter.withSelectedBaseUrl(topic.node.url, HttpClient.getInstance().getBaseUrl())
      topic.node.title = HtmlEntityUtils.decode(topic.node.title)
      topic.node.title_alternative = HtmlEntityUtils.decode(topic.node.title_alternative)
      topic.node.header = HtmlEntityUtils.decode(topic.node.header || '')
      topic.node.footer = HtmlEntityUtils.decode(topic.node.footer || '')
    }
    if (topic.member) {
      topic.member.tagline = HtmlEntityUtils.decode(topic.member.tagline)
    }
    return topic
  }

  private static normalizeReplies(replies: V2exReply[]): V2exReply[] {
    return (replies || []).map((reply: V2exReply) => ApiService.normalizeReply(reply))
  }

  private static normalizeReply(reply: V2exReply): V2exReply {
    if (!reply) {
      return reply
    }
    reply.content = HtmlEntityUtils.decode(reply.content)
    reply.content_rendered = HtmlEntityUtils.decode(reply.content_rendered)
    if (reply.member) {
      reply.member.tagline = HtmlEntityUtils.decode(reply.member.tagline)
    }
    return reply
  }

  private static authHeaders(token: string): Record<string, string> {
    return {
      'Authorization': `Bearer ${token.trim()}`,
    }
  }

  private static queryParam(name: string, value: string): string {
    return `${encodeURIComponent(name)}=${encodeURIComponent((value || '').trim())}`
  }

  private static extractAttr(tag: string, attr: string): string {
    const escaped = attr.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
    const match = (tag || '').match(new RegExp(`${escaped}=["']([^"']*)["']`, 'i'))
    return match && match[1] ? ApiService.decodePlain(match[1]) : ''
  }

  private static extractFirst(text: string, pattern: RegExp): string {
    const match = (text || '').match(pattern)
    return match && match[1] ? ApiService.decodePlain(match[1]) : ''
  }

  private static parseNumber(value: string): number {
    const n = parseInt((value || '').replace(/[^0-9]/g, ''), 10)
    return Number.isFinite(n) ? n : 0
  }

  private static parseTimeSeconds(value: string): number {
    const timestamp = Date.parse((value || '').trim().replace(' +08:00', '+08:00'))
    return Number.isFinite(timestamp) ? Math.floor(timestamp / 1000) : 0
  }

  private static decodePlain(value: string): string {
    return HtmlEntityUtils.decode((value || '').replace(/<[^>]+>/g, '').trim())
  }
}
