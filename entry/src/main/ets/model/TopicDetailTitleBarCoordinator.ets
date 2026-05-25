import { AppStrings } from 'shared/src/main/ets/i18n/AppStrings'

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
      { label: AppStrings.R_TOPIC_ACTION_THANK_TOPIC, action: 'thankTopic', stateKey: 'thanked' },
      { label: AppStrings.R_TOPIC_ACTION_SITE_FAVORITE, action: 'siteFavorite', stateKey: 'siteFavorited' },
      { label: AppStrings.R_TOPIC_ACTION_SAVE_LATER, action: 'saveLater', stateKey: 'savedLater' },
      { label: AppStrings.R_TOPIC_ACTION_IGNORE_TOPIC, action: 'ignoreTopic', stateKey: '' },
      { label: AppStrings.R_TOPIC_ACTION_REPORT_TOPIC, action: 'reportTopic', stateKey: '' },
      { label: AppStrings.R_TOPIC_ACTION_COPY_TITLE, action: 'copyTitle', stateKey: '' },
      { label: AppStrings.R_TOPIC_ACTION_COPY_LINK, action: 'copyLink', stateKey: '' },
      { label: AppStrings.R_TOPIC_ACTION_SHARE_LINK, action: 'share', stateKey: '' },
      { label: AppStrings.R_TOPIC_ACTION_OPEN_BROWSER, action: 'openBrowser', stateKey: '' },
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
