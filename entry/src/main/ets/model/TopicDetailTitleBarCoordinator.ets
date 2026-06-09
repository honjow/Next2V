export type TopicDetailTitleAction =
  | 'thankTopic'
  | 'siteFavorite'
  | 'saveLater'
  | 'editTopic'
  | 'moveTopic'
  | 'appendTopic'
  | 'ignoreTopic'
  | 'reportTopic'
  | 'copyTitle'
  | 'copyLink'
  | 'share'
  | 'openInApp'
  | 'openBrowser'

export interface TopicDetailTitleActionDescriptor {
  label: ResourceStr
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
      { label: $r('app.string.topic_action_thank_topic'), action: 'thankTopic', stateKey: 'thanked' },
      {
        label: $r('app.string.topic_action_site_favorite'),
        action: 'siteFavorite',
        stateKey: 'siteFavorited',
      },
      { label: $r('app.string.topic_action_save_later'), action: 'saveLater', stateKey: 'savedLater' },
      // Owner-only, mutually time-exclusive: Index.ets filters editTopic to the edit window (<600s) and
      // appendTopic to the append window (>=1800s). Placed early so they sit near the top of the popup.
      { label: $r('app.string.topic_action_edit'), action: 'editTopic', stateKey: '' },
      { label: $r('app.string.topic_action_move'), action: 'moveTopic', stateKey: '' },
      { label: $r('app.string.topic_action_append'), action: 'appendTopic', stateKey: '' },
      { label: $r('app.string.topic_action_ignore_topic'), action: 'ignoreTopic', stateKey: '' },
      { label: $r('app.string.topic_action_report_topic'), action: 'reportTopic', stateKey: '' },
      { label: $r('app.string.topic_action_copy_title'), action: 'copyTitle', stateKey: '' },
      { label: $r('app.string.topic_action_copy_link'), action: 'copyLink', stateKey: '' },
      { label: $r('app.string.topic_action_share_link'), action: 'share', stateKey: '' },
      { label: $r('app.string.topic_action_open_in_app'), action: 'openInApp', stateKey: '' },
      { label: $r('app.string.topic_action_open_browser'), action: 'openBrowser', stateKey: '' },
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
