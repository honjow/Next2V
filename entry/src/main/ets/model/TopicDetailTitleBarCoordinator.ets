export type TopicDetailTitleAction =
  'thankTopic' |
  'siteFavorite' |
  'saveLater' |
  'ignoreTopic' |
  'reportTopic' |
  'copyTitle' |
  'copyLink' |
  'share' |
  'openBrowser'

export interface TopicDetailTitleActionDescriptor {
  label: string
  action: TopicDetailTitleAction
  stateKey: string
}

export interface TopicDetailTitleState {
  savedLater: boolean
  siteFavorited: boolean
  thanked: boolean
}

export interface TopicDetailTitleIdentity {
  title: string
  avatarUrl: string
  username: string
}

export class TopicDetailTitleBarCoordinator {
  static readonly MENU_MAX_COUNT: number = 3

  static actions(): TopicDetailTitleActionDescriptor[] {
    return [
      { label: '感谢主题', action: 'thankTopic', stateKey: 'thanked' },
      { label: '站内收藏', action: 'siteFavorite', stateKey: 'siteFavorited' },
      { label: '稍后读', action: 'saveLater', stateKey: 'savedLater' },
      { label: '忽略主题', action: 'ignoreTopic', stateKey: '' },
      { label: '举报主题', action: 'reportTopic', stateKey: '' },
      { label: '复制标题', action: 'copyTitle', stateKey: '' },
      { label: '复制链接', action: 'copyLink', stateKey: '' },
      { label: '分享链接', action: 'share', stateKey: '' },
      { label: '浏览器打开', action: 'openBrowser', stateKey: '' },
    ]
  }

  static routeKey(topicId: number): string {
    return topicId > 0 ? topicId.toString() : ''
  }

  static stringForState(statesJson: string, routeKey: string): string {
    if (!routeKey) {
      return ''
    }
    try {
      const states = JSON.parse(statesJson || '{}') as Record<string, string>
      return (states[routeKey] || '').trim()
    } catch (_e) {
      return ''
    }
  }

  static identity(
    routeKey: string,
    routeStateKey: string,
    currentTitle: string,
    currentAvatarUrl: string,
    currentUsername: string,
    titleStatesJson: string,
    avatarStatesJson: string,
    usernameStatesJson: string,
  ): TopicDetailTitleIdentity {
    if (!routeKey) {
      return { title: '', avatarUrl: '', username: '' }
    }
    const routeMatches = (routeStateKey || '').trim() === routeKey
    const title =
      TopicDetailTitleBarCoordinator.stringForState(titleStatesJson, routeKey) ||
      (routeMatches ? (currentTitle || '').trim() : '')
    if (!title) {
      return { title: '', avatarUrl: '', username: '' }
    }
    return {
      title,
      avatarUrl:
        TopicDetailTitleBarCoordinator.stringForState(avatarStatesJson, routeKey) ||
        (routeMatches ? (currentAvatarUrl || '').trim() : ''),
      username:
        TopicDetailTitleBarCoordinator.stringForState(usernameStatesJson, routeKey) ||
        (routeMatches ? (currentUsername || '').trim() : ''),
    }
  }

  static activeForState(action: TopicDetailTitleAction, state: TopicDetailTitleState): boolean {
    if (action === 'thankTopic') {
      return state.thanked
    }
    if (action === 'siteFavorite') {
      return state.siteFavorited
    }
    if (action === 'saveLater') {
      return state.savedLater
    }
    return false
  }
}
