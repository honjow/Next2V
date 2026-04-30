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
  static readonly API_V2_NODE: string = '/api/v2/nodes'
  static readonly API_V2_TOPIC: string = '/api/v2/topics'
}
