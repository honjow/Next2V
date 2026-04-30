import { HttpClient } from './HttpClient'
import { ApiConstants } from '../constants/ApiConstants'
import type {
  V2exTopic,
  V2exReply,
  V2exNode,
  V2exMemberProfile,
  V2exSiteInfo
} from './NetworkTypes'

/**
 * V2EX API 调用层
 * V1 公开接口（无需认证）+ V2 认证接口占位
 */
export class ApiService {
  private http: HttpClient = HttpClient.getInstance()

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
}
