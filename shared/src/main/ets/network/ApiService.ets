import { http } from '@kit.NetworkKit'
import { HttpClient } from './HttpClient'
import { ApiConstants } from '../constants/ApiConstants'
import { V2exTabParser } from '../parser/V2exTabParser'
import { V2exNotificationParser } from '../parser/V2exNotificationParser'
import { V2exAccountParser } from '../parser/V2exAccountParser'
import { V2exSessionParser } from '../parser/V2exSessionParser'
import { V2exNodeParser, type V2exFavoriteNode } from '../parser/V2exNodeParser'
import { V2exCollectionActionParser, type V2exToggleAction } from '../parser/V2exCollectionActionParser'
import { V2exWriteFormParser } from '../parser/V2exWriteFormParser'
import { V2exSigninParser } from '../parser/V2exSigninParser'
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
  V2exDailyMission
} from './NetworkTypes'

interface CookieHtmlResponse {
  statusCode: number
  text: string
  location: string
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
    return this.http.get<V2exTopic[]>(ApiConstants.API_LATEST)
  }

  /** 获取每日 10 条热门 */
  async getHotTopics(): Promise<V2exTopic[]> {
    return this.http.get<V2exTopic[]>(ApiConstants.API_HOT)
  }

  /** 根据 ID 获取单条主题 */
  async getTopicById(topicId: number): Promise<V2exTopic[]> {
    return this.http.get<V2exTopic[]>(`${ApiConstants.API_TOPIC_SHOW}?id=${topicId}`)
  }

  /** 根据用户名获取其主题 */
  async getTopicsByUsername(username: string): Promise<V2exTopic[]> {
    return this.http.get<V2exTopic[]>(`${ApiConstants.API_TOPIC_SHOW}?username=${username}`)
  }

  /** 根据节点名获取主题 */
  async getTopicsByNode(nodeName: string): Promise<V2exTopic[]> {
    return this.http.get<V2exTopic[]>(`${ApiConstants.API_TOPIC_SHOW}?node_name=${nodeName}`)
  }

  /** 获取主题的回复列表 */
  async getReplies(topicId: number): Promise<V2exReply[]> {
    return this.http.get<V2exReply[]>(`${ApiConstants.API_REPLIES_SHOW}?topic_id=${topicId}`)
  }

  /** 获取所有节点 */
  async getAllNodes(): Promise<V2exNode[]> {
    return this.http.get<V2exNode[]>(ApiConstants.API_NODES_ALL)
  }

  /** 根据名称获取节点详情 */
  async getNodeByName(name: string): Promise<V2exNode> {
    return this.http.get<V2exNode>(`${ApiConstants.API_NODE_SHOW}?name=${name}`)
  }

  /** 获取用户信息 */
  async getMember(username: string): Promise<V2exMemberProfile> {
    return this.http.get<V2exMemberProfile>(`${ApiConstants.API_MEMBER_SHOW}?username=${username}`)
  }

  /** 获取站点信息 */
  async getSiteInfo(): Promise<V2exSiteInfo> {
    return this.http.get<V2exSiteInfo>(ApiConstants.API_SITE_INFO)
  }

  // ==================== V2 Token 只读接口 ====================

  async getAuthenticatedMember(token: string): Promise<V2exAuthenticatedMember> {
    return this.http.getWithHeaders<V2exAuthenticatedMember>(
      ApiConstants.API_V2_MEMBER,
      ApiService.authHeaders(token)
    )
  }

  async getTokenInfo(token: string): Promise<V2exTokenInfo> {
    return this.http.getWithHeaders<V2exTokenInfo>(
      ApiConstants.API_V2_TOKEN,
      ApiService.authHeaders(token)
    )
  }

  async getNotifications(token: string, page: number = 1): Promise<V2exNotification[]> {
    return this.http.getWithHeaders<V2exNotification[]>(
      `${ApiConstants.API_V2_NOTIFICATIONS}?p=${page}`,
      ApiService.authHeaders(token)
    )
  }

  async getNotificationsWithCookie(cookie: string, page: number = 1): Promise<V2exNotification[]> {
    if (!cookie) {
      throw new Error('请先登录')
    }
    const html = await this.http.getTextWithHeaders(`/notifications?p=${page}`, { 'Cookie': cookie })
    if (!V2exSessionParser.extractUsername(html)) {
      throw new Error('Web 会话已失效，请重新登录')
    }
    return V2exNotificationParser.extractNotifications(html)
  }

  async getBalanceWithCookie(cookie: string): Promise<V2exBalance> {
    if (!cookie) {
      throw new Error('请先登录')
    }
    const html = await this.http.getTextWithHeaders('/balance', { 'Cookie': cookie })
    if (!V2exSessionParser.extractUsername(html)) {
      throw new Error('Web 会话已失效，请重新登录')
    }
    return V2exAccountParser.extractBalance(html)
  }

  async getDailyMissionWithCookie(cookie: string): Promise<V2exDailyMission> {
    if (!cookie) {
      throw new Error('请先登录')
    }
    const html = await this.http.getTextWithHeaders('/mission/daily', { 'Cookie': cookie })
    if (!V2exSessionParser.extractUsername(html)) {
      throw new Error('Web 会话已失效，请重新登录')
    }
    return V2exAccountParser.extractDailyMission(html)
  }

  async redeemDailyMissionWithCookie(cookie: string, redeemPath: string): Promise<V2exDailyMission> {
    if (!redeemPath) {
      throw new Error('今日不可签到')
    }
    await this.http.getTextWithHeaders(redeemPath, { 'Cookie': cookie })
    return this.getDailyMissionWithCookie(cookie)
  }

  async getMyTopicsWithCookie(cookie: string, page: number = 1): Promise<V2exTopic[]> {
    if (!cookie) {
      throw new Error('请先登录')
    }
    const path = page > 1 ? `/my/topics?p=${page}` : '/my/topics'
    const html = await this.http.getTextWithHeaders(path, { 'Cookie': cookie })
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
    const path = page > 1 ? `/my/replies?p=${page}` : '/my/replies'
    const html = await this.http.getTextWithHeaders(path, { 'Cookie': cookie })
    if (!V2exSessionParser.extractUsername(html)) {
      throw new Error('Web 会话已失效，请重新登录')
    }
    const ids = V2exTabParser.extractTopicIds(html)
    if (ids.length === 0) {
      return []
    }
    return this.getTopicsByIds(ids)
  }

  async getMyFavoriteNodesWithCookie(cookie: string): Promise<V2exFavoriteNode[]> {
    if (!cookie) {
      throw new Error('请先登录')
    }
    const html = await this.http.getTextWithHeaders('/my/nodes', { 'Cookie': cookie })
    if (!V2exSessionParser.extractUsername(html)) {
      throw new Error('Web 会话已失效，请重新登录')
    }
    return V2exNodeParser.extractFavoriteNodes(html)
  }

  // ==================== Cookie 写入操作（站内收藏/关注） ====================

  /**
   * 获取主题收藏/取消收藏的切换链接（依赖 Cookie 会话）
   */
  async getTopicFavoriteToggleActionWithCookie(cookie: string, topicId: number): Promise<V2exToggleAction> {
    if (!cookie) {
      throw new Error('请先登录')
    }
    if (topicId <= 0) {
      throw new Error('无效主题 ID')
    }
    const topicPath = `/t/${topicId}`
    const html = await this.http.getTextWithHeaders(topicPath, { 'Cookie': cookie })
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
  async executeTopicFavoriteToggleWithCookie(cookie: string, topicId: number, toggle: V2exToggleAction): Promise<boolean> {
    if (!cookie) {
      throw new Error('请先登录')
    }
    if (topicId <= 0) {
      throw new Error('无效主题 ID')
    }
    const topicPath = `/t/${topicId}`
    await this.requestTextWithCookieAllowRedirect(toggle.actionPath, cookie, topicPath)

    const verifyHtml = await this.http.getTextWithHeaders(topicPath, { 'Cookie': cookie })
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
  async getNodeFavoriteToggleActionWithCookie(cookie: string, nodeName: string): Promise<V2exToggleAction> {
    const cleanName = (nodeName || '').trim()
    if (!cookie) {
      throw new Error('请先登录')
    }
    if (!cleanName) {
      throw new Error('无效节点')
    }
    const nodePath = `/go/${cleanName}`
    const html = await this.http.getTextWithHeaders(nodePath, { 'Cookie': cookie })
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
  async executeNodeFavoriteToggleWithCookie(cookie: string, nodeName: string, toggle: V2exToggleAction): Promise<boolean> {
    const cleanName = (nodeName || '').trim()
    if (!cookie) {
      throw new Error('请先登录')
    }
    if (!cleanName) {
      throw new Error('无效节点')
    }
    const nodePath = `/go/${cleanName}`
    await this.requestTextWithCookieAllowRedirect(toggle.actionPath, cookie, nodePath)

    const verifyHtml = await this.http.getTextWithHeaders(nodePath, { 'Cookie': cookie })
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
    const html = await this.http.getTextWithHeaders(topicPath, { 'Cookie': cookie })
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
    const body = ApiService.encodeFormFields(fields)

    const res = await this.requestHtmlWithCookieAllowRedirect(form.actionPath, cookie, topicPath, http.RequestMethod.POST, body)
    if (res.location.indexOf('/signin') >= 0) {
      throw new Error('Web 会话已失效，请重新登录')
    }
    const problem = V2exSigninParser.extractProblemMessage(res.text)
    if (problem) {
      throw new Error(`提交失败：${problem}`)
    }
  }

  /**
   * 提交新主题（依赖 Cookie 会话）
   * - 返回新主题 ID（无法解析时返回 0）
   */
  async createTopicWithCookie(cookie: string, nodeName: string, title: string, content: string): Promise<number> {
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
    const composeRes = await this.requestHtmlWithCookieAllowRedirect(composePath, cookie, composePath, http.RequestMethod.GET)
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

    const res = await this.requestHtmlWithCookieAllowRedirect(form.actionPath, cookie, composePath, http.RequestMethod.POST, body)
    if (res.location.indexOf('/signin') >= 0) {
      throw new Error('Web 会话已失效，请重新登录')
    }
    const problem = V2exSigninParser.extractProblemMessage(res.text)
    if (problem) {
      throw new Error(`提交失败：${problem}`)
    }

    const topicFromLocation = ApiService.extractTopicId(res.location)
    if (topicFromLocation > 0) {
      return topicFromLocation
    }
    return ApiService.extractTopicId(res.text)
  }

  private async requestTextWithCookieAllowRedirect(pathOrUrl: string, cookie: string, refererPath: string): Promise<void> {
    const clean = (pathOrUrl || '').trim()
    if (!clean) {
      throw new Error('缺少操作路径')
    }
    const baseUrl = this.http.getBaseUrl()
    const url = clean.startsWith('http://') || clean.startsWith('https://')
      ? clean
      : clean.startsWith('/') ? `${baseUrl}${clean}` : `${baseUrl}/${clean}`

    const refererClean = (refererPath || '').trim()
    const refererUrl = !refererClean
      ? ''
      : (refererClean.startsWith('http://') || refererClean.startsWith('https://'))
          ? refererClean
          : refererClean.startsWith('/') ? `${baseUrl}${refererClean}` : `${baseUrl}/${refererClean}`

    let httpRequest = http.createHttp()
    try {
      const requestHeaders: Record<string, string> = {
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Encoding': 'gzip',
        'Content-Type': 'text/html; charset=utf-8',
        'Cookie': cookie,
        'User-Agent': 'Mozilla/5.0'
      }
      if (refererUrl) {
        requestHeaders['Referer'] = refererUrl
      }

      const response = await httpRequest.request(url, {
        method: http.RequestMethod.GET,
        header: requestHeaders,
        connectTimeout: this.CONNECT_TIMEOUT_MS,
        readTimeout: this.READ_TIMEOUT_MS,
        usingCache: false,
        expectDataType: http.HttpDataType.STRING
      })
      const statusCode = response.responseCode as number
      if (statusCode < 200 || statusCode >= 400) {
        throw new Error(`HTTP ${statusCode}: ${url}`)
      }
    } finally {
      httpRequest.destroy()
    }
  }

  private async requestHtmlWithCookieAllowRedirect(
    pathOrUrl: string,
    cookie: string,
    refererPath: string,
    method: http.RequestMethod,
    extraData: string = ''
  ): Promise<CookieHtmlResponse> {
    const clean = (pathOrUrl || '').trim()
    if (!clean) {
      throw new Error('缺少操作路径')
    }
    const baseUrl = this.http.getBaseUrl()
    const url = clean.startsWith('http://') || clean.startsWith('https://')
      ? clean
      : clean.startsWith('/') ? `${baseUrl}${clean}` : `${baseUrl}/${clean}`

    const refererClean = (refererPath || '').trim()
    const refererUrl = !refererClean
      ? ''
      : (refererClean.startsWith('http://') || refererClean.startsWith('https://'))
          ? refererClean
          : refererClean.startsWith('/') ? `${baseUrl}${refererClean}` : `${baseUrl}/${refererClean}`

    let httpRequest = http.createHttp()
    let headerBag: Object | null = null
    httpRequest.on('headersReceive', (headers: Object) => {
      headerBag = headers
    })
    try {
      const requestHeaders: Record<string, string> = {
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Encoding': 'gzip',
        'Content-Type': method === http.RequestMethod.POST ? 'application/x-www-form-urlencoded' : 'text/html; charset=utf-8',
        'Cookie': cookie,
        'User-Agent': 'Mozilla/5.0'
      }
      if (refererUrl) {
        requestHeaders['Referer'] = refererUrl
      }

      const options: http.HttpRequestOptions = {
        method: method,
        header: requestHeaders,
        connectTimeout: this.CONNECT_TIMEOUT_MS,
        readTimeout: this.READ_TIMEOUT_MS,
        usingCache: false,
        expectDataType: http.HttpDataType.STRING
      }
      if (method === http.RequestMethod.POST) {
        options.extraData = extraData
      }
      const response = await httpRequest.request(url, options)
      const statusCode = response.responseCode as number
      if (statusCode < 200 || statusCode >= 400) {
        throw new Error(`HTTP ${statusCode}: ${url}`)
      }
      const text = (response.result as string) || ''
      const location = ApiService.extractHeaderValue(headerBag || response.header, 'location')
      return { statusCode, text, location }
    } finally {
      httpRequest.destroy()
    }
  }

  private static extractHeaderValue(headers: Object, key: string): string {
    const cleanKey = (key || '').trim().toLowerCase()
    if (!cleanKey) {
      return ''
    }
    try {
      const bag = headers as Record<string, Object>
      const value = bag[cleanKey] || bag[key] || bag[cleanKey.toUpperCase()] || bag[key.toUpperCase()] || ''
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

  // ==================== Tab 聚合接口 ====================

  /**
   * 根据 tab key 获取主题列表
   * - latest/hot 直接走 JSON API
   * - 其余 tab 先 HTML 抓取 ID，再逐个并发获取详情
   */
  async getTabTopics(tab: string): Promise<V2exTopic[]> {
    if (tab === 'latest') {
      return this.getLatestTopics()
    }
    if (tab === 'hot') {
      return this.getHotTopics()
    }

    const html = await this.http.getText(ApiConstants.TAB_URLS[tab])
    const ids = V2exTabParser.extractTopicIds(html)
    if (ids.length === 0) {
      throw new Error(`Tab "${tab}" 没有获取到主题，请稍后重试`)
    }
    return this.getBatchTopics(ids)
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
        batch.map(id => this.http.get<V2exTopic[]>(`${ApiConstants.API_TOPIC_SHOW}?id=${id}`))
      )
      results.push(...batchResults.map(r => r[0]).filter(t => t !== undefined))
    }
    return results
  }

  private static authHeaders(token: string): Record<string, string> {
    return {
      'Authorization': `Bearer ${token.trim()}`
    }
  }
}
