import { http } from '@kit.NetworkKit'
import { HttpClient } from './HttpClient'
import { NetworkProxyRequest } from './NetworkProxyRequest'
import { FeedTabSettings } from '../settings/FeedTabSettings'
import { ApiConstants } from '../constants/ApiConstants'
import { V2exTabParser } from '../parser/V2exTabParser'
import { V2exNotificationParser } from '../parser/V2exNotificationParser'
import { V2exAccountParser } from '../parser/V2exAccountParser'
import { V2exSessionParser } from '../parser/V2exSessionParser'
import { V2exNodeParser, type V2exFavoriteNode } from '../parser/V2exNodeParser'
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
import type {
  V2exTopicWebRepliesAllResult,
  V2exTopicWebRepliesPage,
} from './V2exTopicWebRepliesClient'
import { HtmlEntityUtils } from '../utils/HtmlEntityUtils'
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

  constructor(path: string, message: string = 'V2EX 需要完成两步验证') {
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
 * V2EX API 调用层
 * V1 公开接口（无需认证）+ V2 认证接口占位
 */
export class ApiService {
  private http: HttpClient = HttpClient.getInstance()
  private readonly CONNECT_TIMEOUT_MS: number = 10000
  private readonly READ_TIMEOUT_MS: number = 15000

  // ==================== V1 公开接口 ====================

  /** 获取最新 20 条主题 */
  async getLatestTopics(): Promise<V2exTopic[]> {
    return ApiService.normalizeTopics(await this.http.get<V2exTopic[]>(ApiConstants.API_LATEST))
  }

  /** 获取每日 10 条热门 */
  async getHotTopics(): Promise<V2exTopic[]> {
    return ApiService.normalizeTopics(await this.http.get<V2exTopic[]>(ApiConstants.API_HOT))
  }

  /** 获取网站 hot tab 热榜主题 */
  async getHotTabTopics(): Promise<V2exTopic[]> {
    const html = await this.http.getText('/?tab=hot')
    const ids = V2exTabParser.extractTopicIds(html)
    if (ids.length === 0) {
      throw new Error('热榜没有获取到主题，请稍后重试')
    }
    return this.getBatchTopics(ids)
  }

  /** 获取全站最近更新主题 */
  async getRecentTopics(page: number = 1): Promise<V2exTopic[]> {
    const safePage = Math.max(1, Math.floor(page))
    const html = await this.http.getText(`/recent?p=${safePage}`)
    const ids = V2exTabParser.extractTopicIds(html)
    if (ids.length === 0) {
      throw new Error('最近更新没有获取到主题，请稍后重试')
    }
    return this.getBatchTopics(ids)
  }

  /** 根据 ID 获取单条主题 */
  async getTopicById(topicId: number, cacheBuster: number = 0): Promise<V2exTopic[]> {
    const endpoint =
      cacheBuster > 0
        ? `${ApiConstants.API_TOPIC_SHOW}?id=${topicId}&_=${cacheBuster}`
        : `${ApiConstants.API_TOPIC_SHOW}?id=${topicId}`
    const topics =
      cacheBuster > 0
        ? await this.http.getNoCache<V2exTopic[]>(endpoint)
        : await this.http.get<V2exTopic[]>(endpoint)
    return ApiService.normalizeTopics(topics)
  }

  /** 根据用户名获取其主题 */
  async getTopicsByUsername(username: string): Promise<V2exTopic[]> {
    return ApiService.normalizeTopics(
      await this.http.get<V2exTopic[]>(
        `${ApiConstants.API_TOPIC_SHOW}?${ApiService.queryParam('username', username)}`,
      ),
    )
  }

  /** 根据节点名获取主题 */
  async getTopicsByNode(nodeName: string): Promise<V2exTopic[]> {
    return ApiService.normalizeTopics(
      await this.http.get<V2exTopic[]>(
        `${ApiConstants.API_TOPIC_SHOW}?${ApiService.queryParam('node_name', nodeName)}`,
      ),
    )
  }

  /** 根据节点网页获取主题，支持 /go/{node}?p=N 分页。 */
  async getNodeTopicsPage(nodeName: string, page: number = 1): Promise<V2exNodeTopicsPageResult> {
    const clean = (nodeName || '').trim()
    if (!clean) {
      throw new Error('节点名称不能为空')
    }
    const safePage = Math.max(1, Math.floor(page))
    const html = await this.http.getText(`/go/${encodeURIComponent(clean)}?p=${safePage}`)
    const snapshot: V2exNodeTopicsPageSnapshot = V2exNodeParser.parseNodeTopicsPage(html)
    if (snapshot.topicIds.length === 0) {
      return { topics: [], hasMore: false }
    }
    return {
      topics: await this.getBatchTopics(snapshot.topicIds),
      hasMore: snapshot.hasMore,
    }
  }

  /** 获取主题的回复列表 */
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

  /** 获取主题回复；当旧公开 API 少于主题回复数时，以公开网页 HTML 为准。 */
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
        console.error('topic web replies fallback failed:', (error as Error).message)
      }
    }
    return apiReplies
  }

  /** 获取公开主题网页中的单页回复，用于主题详情页按页追加和末页刷新。 */
  async getTopicWebRepliesPage(
    topicId: number,
    page: number = 1,
    cacheBuster: number = Date.now(),
    cookie: string = '',
  ): Promise<V2exTopicWebRepliesPage> {
    return this.topicWebRepliesClient().getPage(topicId, page, cacheBuster, cookie)
  }

  /** 获取公开主题网页中的实际回复，用于旧 replies API 为空或滞后时兜底。 */
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

  /** 获取所有节点 */
  async getAllNodes(): Promise<V2exNode[]> {
    return this.http.get<V2exNode[]>(ApiConstants.API_NODES_ALL)
  }

  /** 根据名称获取节点详情 */
  async getNodeByName(name: string): Promise<V2exNode> {
    return this.http.get<V2exNode>(
      `${ApiConstants.API_NODE_SHOW}?${ApiService.queryParam('name', name)}`,
    )
  }

  /** 获取用户信息 */
  async getMember(username: string): Promise<V2exMemberProfile> {
    return this.http.get<V2exMemberProfile>(
      `${ApiConstants.API_MEMBER_SHOW}?${ApiService.queryParam('username', username)}`,
    )
  }

  /** 获取成员页实际展示的主题、回复和可用操作。主题列表遵循用户网页隐藏设置。 */
  async getMemberPageSnapshot(
    username: string,
    cookie: string = '',
  ): Promise<V2exMemberPageSnapshot> {
    const clean = (username || '').trim()
    if (!clean) {
      throw new Error('无效用户名')
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
      throw new Error('无效用户名')
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
      throw new Error('无效用户名')
    }
    const safePage = Math.max(1, Math.floor(page))
    const path = `/member/${encodeURIComponent(clean)}/replies?p=${safePage}`
    const html = cookie ? await this.getCookieHtml(path, cookie) : await this.http.getText(path)
    return V2exMemberPageParser.parseRepliesPage(html)
  }

  /** 获取站点信息 */
  async getSiteInfo(): Promise<V2exSiteInfo> {
    return this.http.get<V2exSiteInfo>(ApiConstants.API_SITE_INFO)
  }

  // ==================== V2 Token 只读接口 ====================

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
      throw new Error('请先登录')
    }
    const html = await this.getCookieHtml(`/notifications?p=${page}`, cookie)
    if (!V2exSessionParser.extractUsername(html)) {
      throw new Error('Web 会话已失效，请重新登录')
    }
    return V2exNotificationParser.extractNotifications(html)
  }

  async getNotificationUnreadCountWithCookie(cookie: string): Promise<number> {
    if (!cookie) {
      return 0
    }
    const html = await this.getCookieHtml('/', cookie)
    if (!V2exSessionParser.extractUsername(html)) {
      throw new Error('Web 会话已失效，请重新登录')
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
      throw new Error('请先登录')
    }
    if (notificationId <= 0 || !once) {
      throw new Error('缺少通知删除参数')
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
      throw new Error('Web 会话已失效，请重新登录')
    }
    if (await this.isNotificationDeletedFromCookiePage(cookie, action.id, safeVerifyPage)) {
      console.info(`[NotificationDelete] cookie verified id=${action.id} page=${safeVerifyPage}`)
      return
    }
    console.error(`[NotificationDelete] cookie verify_failed id=${action.id} page=${safeVerifyPage}`)
    throw new Error('删除通知未生效，请稍后重试')
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
      throw new Error('缺少通知删除参数')
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
      throw new Error('请先登录')
    }
    const html = await this.getCookieHtml('/balance', cookie)
    if (!V2exSessionParser.extractUsername(html)) {
      throw new Error('Web 会话已失效，请重新登录')
    }
    return V2exAccountParser.extractBalance(html)
  }

  async getDailyMissionWithCookie(cookie: string): Promise<V2exDailyMission> {
    if (!cookie) {
      throw new Error('请先登录')
    }
    const html = await this.getCookieHtml('/mission/daily', cookie)
    if (!V2exSessionParser.extractUsername(html)) {
      throw new Error('Web 会话已失效，请重新登录')
    }
    return V2exAccountParser.extractDailyMission(html)
  }

  async redeemDailyMissionWithCookie(
    cookie: string,
    redeemPath: string,
  ): Promise<V2exDailyMission> {
    if (!redeemPath) {
      throw new Error('今日不可签到')
    }
    await this.getCookieHtml(redeemPath, cookie)
    return this.getDailyMissionWithCookie(cookie)
  }

  async getMyTopicsWithCookie(cookie: string, page: number = 1): Promise<V2exTopic[]> {
    if (!cookie) {
      throw new Error('请先登录')
    }
    const path = page > 1 ? `/my/topics?p=${page}` : '/my/topics'
    const html = await this.getCookieHtml(path, cookie)
    if (!V2exSessionParser.extractUsername(html)) {
      throw new Error('Web 会话已失效，请重新登录')
    }
    const ids = V2exTabParser.extractTopicIds(html)
    if (ids.length === 0) {
      return []
    }
    return this.getTopicsByIds(ids)
  }

  async getMyRepliesWithCookie(cookie: string, page: number = 1): Promise<V2exTopic[]> {
    if (!cookie) {
      throw new Error('请先登录')
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
      throw new Error('Web 会话已失效，请重新登录')
    }
    return username
  }

  async getMyFavoriteNodesWithCookie(cookie: string): Promise<V2exFavoriteNode[]> {
    if (!cookie) {
      throw new Error('请先登录')
    }
    const html = await this.getCookieHtml('/my/nodes', cookie)
    if (!V2exSessionParser.extractUsername(html)) {
      throw new Error('Web 会话已失效，请重新登录')
    }
    return V2exNodeParser.extractFavoriteNodes(html)
  }

  async getFollowingMembersWithCookie(cookie: string): Promise<V2exAccountMemberListItem[]> {
    if (!cookie) {
      throw new Error('请先登录')
    }
    const currentUsername = await this.getSessionUsernameWithCookie(cookie)
    const html = await this.getCookieHtml('/my/following', cookie)
    if (html.indexOf('/signin') >= 0 && !V2exSessionParser.extractUsername(html)) {
      throw new Error('Web 会话已失效，请重新登录')
    }
    return V2exAccountListParser.extractMembers(html, currentUsername)
  }

  // ==================== Cookie 账号操作（站内收藏/关注） ====================

  /**
   * 获取主题收藏/取消收藏的切换链接（依赖 Cookie 会话）
   */
  async getTopicFavoriteToggleActionWithCookie(
    cookie: string,
    topicId: number,
  ): Promise<V2exToggleAction> {
    if (!cookie) {
      throw new Error('请先登录')
    }
    if (topicId <= 0) {
      throw new Error('无效主题 ID')
    }
    const topicPath = `/t/${topicId}`
    const html = await this.getCookieHtml(topicPath, cookie)
    if (!V2exSessionParser.extractUsername(html)) {
      throw new Error('Web 会话已失效，请重新登录')
    }

    const toggle = V2exCollectionActionParser.extractTopicFavoriteToggle(html, topicId)
    if (!toggle) {
      throw new Error('解析收藏操作失败，请稍后重试')
    }
    return toggle
  }

  /**
   * 执行主题收藏切换（依赖 Cookie 会话）
   * - 返回操作后的收藏状态
   */
  async executeTopicFavoriteToggleWithCookie(
    cookie: string,
    topicId: number,
    toggle: V2exToggleAction,
  ): Promise<boolean> {
    if (!cookie) {
      throw new Error('请先登录')
    }
    if (topicId <= 0) {
      throw new Error('无效主题 ID')
    }
    const topicPath = `/t/${topicId}`
    await this.requestTextWithCookieAllowRedirect(toggle.actionPath, cookie, topicPath)

    const verifyHtml = await this.getCookieHtml(topicPath, cookie)
    if (!V2exSessionParser.extractUsername(verifyHtml)) {
      throw new Error('Web 会话已失效，请重新登录')
    }
    const after = V2exCollectionActionParser.extractTopicFavoriteToggle(verifyHtml, topicId)
    if (!after) {
      return !toggle.currentlyOn
    }
    return after.currentlyOn
  }

  /**
   * 站内收藏/取消收藏主题（依赖 Cookie 会话）
   * - 返回操作后的收藏状态
   */
  async toggleTopicFavoriteWithCookie(cookie: string, topicId: number): Promise<boolean> {
    const toggle = await this.getTopicFavoriteToggleActionWithCookie(cookie, topicId)
    return this.executeTopicFavoriteToggleWithCookie(cookie, topicId, toggle)
  }

  /**
   * 获取节点关注/取消关注的切换链接（依赖 Cookie 会话）
   */
  async getNodeFavoriteToggleActionWithCookie(
    cookie: string,
    nodeName: string,
  ): Promise<V2exToggleAction> {
    const cleanName = (nodeName || '').trim()
    if (!cookie) {
      throw new Error('请先登录')
    }
    if (!cleanName) {
      throw new Error('无效节点')
    }
    const nodePath = `/go/${cleanName}`
    const html = await this.getCookieHtml(nodePath, cookie)
    if (!V2exSessionParser.extractUsername(html)) {
      throw new Error('Web 会话已失效，请重新登录')
    }
    const toggle = V2exCollectionActionParser.extractNodeFavoriteToggle(html)
    if (!toggle) {
      throw new Error('解析关注操作失败，请稍后重试')
    }
    return toggle
  }

  /**
   * 执行节点关注切换（依赖 Cookie 会话）
   * - 返回操作后的关注状态
   */
  async executeNodeFavoriteToggleWithCookie(
    cookie: string,
    nodeName: string,
    toggle: V2exToggleAction,
  ): Promise<boolean> {
    const cleanName = (nodeName || '').trim()
    if (!cookie) {
      throw new Error('请先登录')
    }
    if (!cleanName) {
      throw new Error('无效节点')
    }
    const nodePath = `/go/${cleanName}`
    await this.requestTextWithCookieAllowRedirect(toggle.actionPath, cookie, nodePath)

    const verifyHtml = await this.getCookieHtml(nodePath, cookie)
    if (!V2exSessionParser.extractUsername(verifyHtml)) {
      throw new Error('Web 会话已失效，请重新登录')
    }
    const after = V2exCollectionActionParser.extractNodeFavoriteToggle(verifyHtml)
    if (!after) {
      return !toggle.currentlyOn
    }
    return after.currentlyOn
  }

  /**
   * 站内关注/取消关注节点（依赖 Cookie 会话）
   * - 返回操作后的关注状态
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
      throw new Error('请先登录')
    }
    if (!cleanName || !cleanPath) {
      throw new Error('缺少用户操作')
    }
    const memberPath = `/member/${encodeURIComponent(cleanName)}`
    const actionRes = await this.requestHtmlWithCookieAllowRedirect(
      cleanPath,
      cookie,
      memberPath,
      http.RequestMethod.GET,
    )
    if (actionRes.location.indexOf('/signin') >= 0) {
      throw new Error('Web 会话已失效，请重新登录')
    }
    return this.getMemberPageSnapshot(cleanName, cookie)
  }

  /**
   * 提交主题回复（依赖 Cookie 会话）
   */
  async submitReplyWithCookie(cookie: string, topicId: number, content: string): Promise<void> {
    const cleanContent = (content || '').trim()
    if (!cookie) {
      throw new Error('请先登录')
    }
    if (topicId <= 0) {
      throw new Error('无效主题 ID')
    }
    if (!cleanContent) {
      throw new Error('回复内容不能为空')
    }
    const topicPath = `/t/${topicId}`
    const html = await this.getCookieHtml(topicPath, cookie)
    if (!V2exSessionParser.extractUsername(html)) {
      throw new Error('Web 会话已失效，请重新登录')
    }
    const form = V2exWriteFormParser.extractReplyForm(html)
    if (!form) {
      throw new Error('解析回复表单失败，请改用浏览器')
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
      throw new Error('Web 会话已失效，请重新登录')
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
      throw new Error(`提交失败：${problem}`)
    }
    throw new Error('提交失败：未确认回复已发布')
  }

  async getReplyThankActionWithCookie(
    cookie: string,
    topicId: number,
    replyId: number,
  ): Promise<V2exReplyThankAction> {
    if (!cookie) {
      throw new Error('请先登录')
    }
    if (topicId <= 0 || replyId <= 0) {
      throw new Error('无效回复')
    }
    const topicPath = `/t/${topicId}`
    const html = await this.getCookieHtml(topicPath, cookie)
    if (!V2exSessionParser.extractUsername(html)) {
      throw new Error('Web 会话已失效，请重新登录')
    }
    const actionPath = ApiService.extractReplyThankPath(html, replyId)
    if (!actionPath) {
      throw new Error('当前回复不可感谢或已经感谢过')
    }
    return { replyId, actionPath }
  }

  async executeReplyThankWithCookie(
    cookie: string,
    topicId: number,
    action: V2exReplyThankAction,
  ): Promise<void> {
    if (!cookie) {
      throw new Error('请先登录')
    }
    if (topicId <= 0 || !action || action.replyId <= 0 || !action.actionPath) {
      throw new Error('缺少感谢操作')
    }
    const topicPath = `/t/${topicId}`
    const res = await this.requestHtmlWithCookieAllowRedirect(
      action.actionPath,
      cookie,
      topicPath,
      http.RequestMethod.POST,
    )
    if (res.location.indexOf('/signin') >= 0) {
      throw new Error('Web 会话已失效，请重新登录')
    }
    ApiService.assertThankResponse(res.text)
    const problem = V2exSigninParser.extractProblemMessage(res.text)
    if (problem) {
      throw new Error(`感谢失败：${problem}`)
    }
  }

  async getTopicThankActionWithCookie(
    cookie: string,
    topicId: number,
  ): Promise<V2exTopicThankAction> {
    if (!cookie) {
      throw new Error('请先登录')
    }
    if (topicId <= 0) {
      throw new Error('无效主题')
    }
    const topicPath = `/t/${topicId}`
    const html = await this.getCookieHtml(topicPath, cookie)
    if (!V2exSessionParser.extractUsername(html)) {
      throw new Error('Web 会话已失效，请重新登录')
    }
    const actionPath = ApiService.extractTopicThankPath(html, topicId)
    if (!actionPath) {
      throw new Error('当前主题不可感谢或已经感谢过')
    }
    return { topicId, actionPath }
  }

  async executeTopicThankWithCookie(cookie: string, action: V2exTopicThankAction): Promise<void> {
    if (!cookie) {
      throw new Error('请先登录')
    }
    if (!action || action.topicId <= 0 || !action.actionPath) {
      throw new Error('缺少感谢操作')
    }
    const topicPath = `/t/${action.topicId}`
    const res = await this.requestHtmlWithCookieAllowRedirect(
      action.actionPath,
      cookie,
      topicPath,
      http.RequestMethod.POST,
    )
    if (res.location.indexOf('/signin') >= 0) {
      throw new Error('Web 会话已失效，请重新登录')
    }
    ApiService.assertThankResponse(res.text)
    const problem = V2exSigninParser.extractProblemMessage(res.text)
    if (problem) {
      throw new Error(`感谢失败：${problem}`)
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
      '主题不可忽略或已被忽略',
    )
    return { topicId, actionPath }
  }

  async executeTopicIgnoreWithCookie(
    cookie: string,
    action: V2exTopicModerationAction,
  ): Promise<void> {
    if (!action || action.topicId <= 0 || !action.actionPath) {
      throw new Error('缺少忽略操作')
    }
    await this.executeCookieActionWithCookie(
      cookie,
      action.actionPath,
      `/t/${action.topicId}`,
      '忽略失败',
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
      '回复不可忽略或已被忽略',
    )
    return { replyId, actionPath }
  }

  async executeReplyIgnoreWithCookie(
    cookie: string,
    topicId: number,
    action: V2exReplyModerationAction,
  ): Promise<void> {
    if (!action || action.replyId <= 0 || !action.actionPath) {
      throw new Error('缺少忽略操作')
    }
    await this.executeCookieActionWithCookie(cookie, action.actionPath, `/t/${topicId}`, '忽略失败')
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
      '主题不可报告或已报告',
    )
    return { topicId, actionPath }
  }

  async executeTopicReportWithCookie(
    cookie: string,
    action: V2exTopicModerationAction,
  ): Promise<void> {
    if (!action || action.topicId <= 0 || !action.actionPath) {
      throw new Error('缺少报告操作')
    }
    await this.executeCookieActionWithCookie(
      cookie,
      action.actionPath,
      `/t/${action.topicId}`,
      '报告失败',
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
      '回复不可报告或已报告',
    )
    return { replyId, actionPath }
  }

  async executeReplyReportWithCookie(
    cookie: string,
    topicId: number,
    action: V2exReplyModerationAction,
  ): Promise<void> {
    if (!action || action.replyId <= 0 || !action.actionPath) {
      throw new Error('缺少报告操作')
    }
    await this.executeCookieActionWithCookie(cookie, action.actionPath, `/t/${topicId}`, '报告失败')
  }

  /**
   * 提交新主题（依赖 Cookie 会话）
   * - 返回新主题 ID（无法解析时返回 0）
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
      throw new Error('请先登录')
    }
    if (!cleanNode) {
      throw new Error('请选择节点')
    }
    if (!cleanTitle) {
      throw new Error('请输入标题')
    }
    if (!cleanContent) {
      throw new Error('请输入正文')
    }

    const composePath = `/new/${cleanNode}`
    const composeRes = await this.requestHtmlWithCookieAllowRedirect(
      composePath,
      cookie,
      composePath,
      http.RequestMethod.GET,
    )
    if (composeRes.location.indexOf('/signin') >= 0) {
      throw new Error('Web 会话已失效，请重新登录')
    }
    const html = composeRes.text
    if (!V2exSessionParser.extractUsername(html)) {
      throw new Error('Web 会话已失效，请重新登录')
    }
    const form = V2exWriteFormParser.extractTopicCreateForm(html)
    if (!form) {
      throw new Error('解析发帖表单失败，请改用浏览器')
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
      throw new Error('Web 会话已失效，请重新登录')
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
      throw new Error(`提交失败：${problem}`)
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
      throw new Error('缺少操作路径')
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
      if (ApiService.isLocationPath(location, '/2fa')) {
        throw new V2exCookieTwoFactorRequiredError(clean)
      }
      if (statusCode < 200 || statusCode >= 400) {
        throw new Error(`HTTP ${statusCode}: ${url}`)
      }
    } catch (error) {
      throw error as Error
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
      throw new Error('缺少操作路径')
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
      this.assertNoTwoFactorChallenge(clean, text, location)
      if (statusCode < 200 || statusCode >= 400) {
        throw new Error(`HTTP ${statusCode}: ${url}`)
      }
      return { statusCode, text, location }
    } catch (error) {
      throw error as Error
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
    const url = ApiService.resolveSameOriginUrl(baseUrl, pathOrUrl, '操作路径')
    const refererClean = (refererPath || '').trim()
    const refererUrl = refererClean ? ApiService.resolveSameOriginUrl(baseUrl, refererClean, '来源路径') : ''
    return { url, refererUrl }
  }

  private static resolveSameOriginUrl(baseUrl: string, pathOrUrl: string, label: string): string {
    const clean = (pathOrUrl || '').trim()
    if (!clean) {
      throw new Error(`缺少${label}`)
    }
    if (clean.startsWith('http://') || clean.startsWith('https://')) {
      const baseOrigin = ApiService.urlOrigin(baseUrl)
      const targetOrigin = ApiService.urlOrigin(clean)
      if (!baseOrigin || targetOrigin !== baseOrigin) {
        throw new Error(`${label}不允许使用外域链接`)
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
    const message = error.message || '请求失败'
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
        const message = (data['message'] as string) || '感谢失败'
        throw new Error(`感谢失败：${message}`)
      }
    } catch (error) {
      if (error instanceof Error && error.message.indexOf('感谢失败') === 0) {
        throw error
      }
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
      throw new Error('请先登录')
    }
    if (topicId <= 0 || targetId <= 0) {
      throw new Error('无效操作对象')
    }
    const topicPath = `/t/${topicId}`
    const html = await this.getCookieHtml(topicPath, cookie)
    if (!V2exSessionParser.extractUsername(html)) {
      throw new Error('Web 会话已失效，请重新登录')
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
      throw new Error('请先登录')
    }
    if (!actionPath) {
      throw new Error('缺少操作路径')
    }
    const res = await this.requestHtmlWithCookieAllowRedirect(
      actionPath,
      cookie,
      refererPath,
      http.RequestMethod.GET,
    )
    if (res.location.indexOf('/signin') >= 0) {
      throw new Error('Web 会话已失效，请重新登录')
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
      console.error('verify submitted reply failed: ' + (error as Error).message)
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

  // ==================== Tab 聚合接口 ====================

  /**
   * 根据 tab key 获取主题列表
   * - latest 走 JSON API
   * - hot 使用网站最热 tab（/?tab=hot），避免退回每日 10 条热门 API
   * - 其余 tab 先 HTML 抓取 ID，再逐个并发获取详情
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
      const ids = V2exTabParser.extractTopicIds(html)
      if (ids.length === 0) {
        throw new Error(`Tab "${tab}" 没有获取到主题，请稍后重试`)
      }
      topics = await this.getBatchTopics(ids)
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
   * 批量获取主题详情（逐个 ID 并发请求，每批 CONCURRENCY 个）
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

  private static normalizeTopics(topics: V2exTopic[]): V2exTopic[] {
    return (topics || []).map((topic: V2exTopic) => ApiService.normalizeTopic(topic))
  }

  private static normalizeTopic(topic: V2exTopic): V2exTopic {
    if (!topic) {
      return topic
    }
    topic.title = HtmlEntityUtils.decode(topic.title)
    topic.content = HtmlEntityUtils.decode(topic.content)
    topic.content_rendered = HtmlEntityUtils.decode(topic.content_rendered)
    if (topic.node) {
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
}
