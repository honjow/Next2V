import { V2exMember, V2exNode, V2exTopic } from '../network/NetworkTypes'
import { TopicCard } from './TopicCard'

@Component
export struct LocalTopicCard {
  @Prop topicId: number
  @Prop title: string
  @Prop nodeName: string = ''
  @Prop nodeTitle: string = ''
  @Prop username: string = ''
  @Prop avatar: string = ''
  @Prop created: number = 0
  @Prop replyCount: number = 0
  @Prop hasReplyCount: boolean = false
  @Prop metaLabel: string = ''
  @Prop metaTimestamp: number = 0
  onUserClick?: () => void
  onNodeClick?: () => void

  build() {
    TopicCard({
      item: this.toTopic(),
      metaLabel: this.metaLabel,
      metaTimestamp: this.metaTimestamp,
      showReplyCount: this.hasReplyCount,
      onUserClick: () => {
        if (this.onUserClick) {
          this.onUserClick()
        }
      },
      onNodeClick: () => {
        if (this.onNodeClick) {
          this.onNodeClick()
        }
      }
    })
  }

  private toTopic(): V2exTopic {
    const member: V2exMember = {
      id: 0,
      username: this.username || '',
      tagline: '',
      avatar_mini: this.avatar || '',
      avatar_normal: this.avatar || '',
      avatar_large: this.avatar || ''
    }
    const node: V2exNode = {
      id: 0,
      name: this.nodeName || '',
      title: this.nodeTitle || this.nodeName || '',
      title_alternative: '',
      url: '',
      topics: 0,
      avatar_mini: '',
      avatar_normal: '',
      avatar_large: ''
    }
    return {
      id: this.topicId,
      title: this.title,
      url: '',
      content: '',
      content_rendered: '',
      replies: this.hasReplyCount ? this.replyCount : 0,
      member: member,
      node: node,
      created: this.created > 0 ? this.created : this.metaTimestamp,
      last_modified: this.metaTimestamp,
      last_touched: this.metaTimestamp
    }
  }
}
