import type {
  V2exTopic,
} from 'shared'

export interface TopicDetailAppbarVisibilityInput {
  hasTopic: boolean
  titleContentBottom: number
  currentScrollOffset: number
  appbarBottom: number
  hysteresis: number
  currentlyVisible: boolean
}

export interface TopicDetailAppbarVisibility {
  visible: boolean
  shouldPublish: boolean
}

export interface TopicDetailAppbarIdentity {
  title: string
  avatarUrl: string
  username: string
}

export class TopicDetailAppbarCoordinator {
  static areaLength(value: Length | undefined): number {
    if (typeof value === 'number') {
      return value
    }
    if (typeof value === 'string') {
      const parsed = Number.parseFloat(value)
      return Number.isNaN(parsed) ? 0 : parsed
    }
    return 0
  }

  static areaY(value: Length | undefined): number {
    return TopicDetailAppbarCoordinator.areaLength(value)
  }

  static routeKey(topicId: number): string {
    return topicId > 0 ? topicId.toString() : ''
  }

  static evaluateVisibility(input: TopicDetailAppbarVisibilityInput): TopicDetailAppbarVisibility {
    if (!input.hasTopic || input.titleContentBottom <= 0) {
      return {
        visible: false,
        shouldPublish: true,
      }
    }
    const currentTitleBottom = input.titleContentBottom - input.currentScrollOffset
    const visible = input.currentlyVisible
      ? currentTitleBottom <= input.appbarBottom + input.hysteresis
      : currentTitleBottom <= input.appbarBottom
    return {
      visible,
      shouldPublish: visible !== input.currentlyVisible,
    }
  }

  static identity(topic: V2exTopic | null | undefined, visible: boolean): TopicDetailAppbarIdentity {
    if (!visible || !topic) {
      return {
        title: '',
        avatarUrl: '',
        username: '',
      }
    }
    return {
      title: (topic.title || '').trim(),
      avatarUrl: (topic.member.avatar_large || topic.member.avatar_normal || '').trim(),
      username: (topic.member.username || '').trim(),
    }
  }

  static nextStringState(statesJson: string, key: string, value: string): string {
    let states: Record<string, string> = {}
    try {
      const parsed = JSON.parse(statesJson || '{}') as Record<string, string>
      if (parsed && typeof parsed === 'object' && !Array.isArray(parsed)) {
        states = parsed
      }
    } catch (_error) {}
    states[key] = value
    return JSON.stringify(states)
  }
}
