import { V2exMemberProfile, V2exTopic, ApiService } from 'shared'

/**
 * 用户主页 ViewModel
 */
@Observed
export class UserViewModel {
  profile: V2exMemberProfile | null = null
  topics: V2exTopic[] = []
  isLoading: boolean = false
  username: string = ''

  private api: ApiService = new ApiService()

  constructor(username: string) {
    this.username = username
  }

  async load(): Promise<void> {
    this.isLoading = true
    try {
      this.profile = await this.api.getMember(this.username)
      this.topics = await this.api.getTopicsByUsername(this.username)
    } catch (error) {
      console.error('Failed to load user:', error.message)
    } finally {
      this.isLoading = false
    }
  }
}
