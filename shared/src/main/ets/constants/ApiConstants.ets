/** Tab item definition */
export interface TabItem {
  key: string
  label: ResourceStr
}

export interface ApiDomainOption {
  id: string
  label: string
  baseUrl: string
  hint: string
  recommended: boolean
}

/**
 * V2EX API constants and base URL configuration
 */
export class ApiConstants {
  // Base domain (configurable in settings)
  static readonly BASE_URL_COM: string = 'https://www.v2ex.com'
  // Kept only so old useCoDomain/cookieCo preferences can be migrated away.
  static readonly BASE_URL_CO: string = 'https://www.v2ex.co'

  static readonly PRESET_DOMAINS: ApiDomainOption[] = [
    { id: 'www', label: 'www.v2ex.com', baseUrl: 'https://www.v2ex.com', hint: '全球默认', recommended: true },
    { id: 'edge', label: 'edge.v2ex.com', baseUrl: 'https://edge.v2ex.com', hint: 'Edge CDN', recommended: true },
    { id: 'global', label: 'global.v2ex.com', baseUrl: 'https://global.v2ex.com', hint: '全球加速', recommended: true },
    { id: 'fast', label: 'fast.v2ex.com', baseUrl: 'https://fast.v2ex.com', hint: '快速线路', recommended: true },
    { id: 'cn', label: 'cn.v2ex.com', baseUrl: 'https://cn.v2ex.com', hint: '中国大陆', recommended: true },
    { id: 'us', label: 'us.v2ex.com', baseUrl: 'https://us.v2ex.com', hint: '美国', recommended: true },
    { id: 'jp', label: 'jp.v2ex.com', baseUrl: 'https://jp.v2ex.com', hint: '日本', recommended: true },
    { id: 'hk', label: 'hk.v2ex.com', baseUrl: 'https://hk.v2ex.com', hint: '香港', recommended: true },
  ]

  // V1 API (no auth, read-only)
  static readonly API_LATEST: string = '/api/topics/latest.json'
  static readonly API_HOT: string = '/api/topics/hot.json'
  static readonly API_TOPIC_SHOW: string = '/api/topics/show.json'
  static readonly API_REPLIES_SHOW: string = '/api/replies/show.json'
  static readonly API_NODES_ALL: string = '/api/nodes/all.json'
  static readonly API_NODE_SHOW: string = '/api/nodes/show.json'
  static readonly API_MEMBER_SHOW: string = '/api/members/show.json'
  static readonly API_SITE_INFO: string = '/api/site/info.json'
  static readonly API_SITE_STATS: string = '/api/site/stats.json'

  // V2 API (requires Token auth)
  static readonly API_V2_NOTIFICATIONS: string = '/api/v2/notifications'
  static readonly API_V2_MEMBER: string = '/api/v2/member'
  static readonly API_V2_TOKEN: string = '/api/v2/token'
  static readonly API_V2_NODE: string = '/api/v2/nodes'
  static readonly API_V2_TOPIC: string = '/api/v2/topics'

  // Tab definitions (order matches display order)
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

  /** URL query per tab page (latest has no standalone URL, uses API) */
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

  /** Concurrency batch size after HTML scrape */
  static readonly TAB_HTML_BATCH_SIZE: number = 5

  /** TabBar height */
  static readonly TAB_BAR_HEIGHT: number = 38
}
