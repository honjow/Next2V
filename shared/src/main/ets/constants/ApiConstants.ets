/** Tab 项定义 */
export interface TabItem {
  key: string
  label: ResourceStr
}

/**
 * V2EX API 常量和基础 URL 配置
 */
export class ApiConstants {
  // 基础域名（可在设置中切换）
  static readonly BASE_URL_COM: string = 'https://www.v2ex.com'
  static readonly BASE_URL_CO: string = 'https://www.v2ex.co'

  // V1 API（无需认证，纯读取）
  static readonly API_LATEST: string = '/api/topics/latest.json'
  static readonly API_HOT: string = '/api/topics/hot.json'
  static readonly API_TOPIC_SHOW: string = '/api/topics/show.json'
  static readonly API_REPLIES_SHOW: string = '/api/replies/show.json'
  static readonly API_NODES_ALL: string = '/api/nodes/all.json'
  static readonly API_NODE_SHOW: string = '/api/nodes/show.json'
  static readonly API_MEMBER_SHOW: string = '/api/members/show.json'
  static readonly API_SITE_INFO: string = '/api/site/info.json'
  static readonly API_SITE_STATS: string = '/api/site/stats.json'

  // V2 API（需要 Token 认证）
  static readonly API_V2_NOTIFICATIONS: string = '/api/v2/notifications'
  static readonly API_V2_MEMBER: string = '/api/v2/member'
  static readonly API_V2_TOKEN: string = '/api/v2/token'
  static readonly API_V2_NODE: string = '/api/v2/nodes'
  static readonly API_V2_TOPIC: string = '/api/v2/topics'

  // Tab 定义（顺序即显示顺序）
  static readonly TAB_ITEMS: TabItem[] = [
    { key: 'tech', label: $r('app.string.v2ex_tab_tech') },
    { key: 'creative', label: $r('app.string.v2ex_tab_creative') },
    { key: 'play', label: $r('app.string.v2ex_tab_play') },
    { key: 'apple', label: 'Apple' },
    { key: 'jobs', label: $r('app.string.v2ex_tab_jobs') },
    { key: 'deals', label: $r('app.string.v2ex_tab_deals') },
    { key: 'city', label: $r('app.string.v2ex_tab_city') },
    { key: 'qna', label: $r('app.string.v2ex_tab_qna') },
    { key: 'hot', label: $r('app.string.v2ex_tab_hot') },
    { key: 'latest', label: $r('app.string.common_all') },
    { key: 'r2', label: 'R2' },
  ]

  /** Tab 页面对应的 URL query（latest 无独立 URL，走 API） */
  static readonly TAB_URLS: Record<string, string> = {
    'tech': '/?tab=tech',
    'creative': '/?tab=creative',
    'play': '/?tab=play',
    'apple': '/?tab=apple',
    'jobs': '/?tab=jobs',
    'deals': '/?tab=deals',
    'city': '/?tab=city',
    'qna': '/?tab=qna',
    'hot': '/?tab=hot',
    'r2': '/?tab=r2',
  }

  /** HTML 抓取后并发请求的批次大小 */
  static readonly TAB_HTML_BATCH_SIZE: number = 5

  /** TabBar 高度 */
  static readonly TAB_BAR_HEIGHT: number = 38
}
