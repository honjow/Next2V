/** Tab item definition */
export interface TabItem {
  key: string
  label: ResourceStr
}

/**
 * V2EX API constants and base URL configuration
 */
export class ApiConstants {
  // Base domain (configurable in settings)
  static readonly BASE_URL_COM: string = 'https://www.v2ex.com'
  static readonly BASE_URL_CO: string = 'https://www.v2ex.co'

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
