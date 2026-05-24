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
      { label: AppStrings.text(AppStrings.R_TOPIC_ACTION_THANK_TOPIC, 'Thank topic'), action: 'thankTopic', stateKey: 'thanked' },
      { label: AppStrings.text(AppStrings.R_TOPIC_ACTION_SITE_FAVORITE, 'Site favorite'), action: 'siteFavorite', stateKey: 'siteFavorited' },
      { label: AppStrings.text(AppStrings.R_TOPIC_ACTION_SAVE_LATER, 'Save later'), action: 'saveLater', stateKey: 'savedLater' },
      { label: AppStrings.text(AppStrings.R_TOPIC_ACTION_IGNORE_TOPIC, 'Ignore topic'), action: 'ignoreTopic', stateKey: '' },
      { label: AppStrings.text(AppStrings.R_TOPIC_ACTION_REPORT_TOPIC, 'Report topic'), action: 'reportTopic', stateKey: '' },
      { label: AppStrings.text(AppStrings.R_TOPIC_ACTION_COPY_TITLE, 'Copy title'), action: 'copyTitle', stateKey: '' },
      { label: AppStrings.text(AppStrings.R_TOPIC_ACTION_COPY_LINK, 'Copy link'), action: 'copyLink', stateKey: '' },
      { label: AppStrings.text(AppStrings.R_TOPIC_ACTION_SHARE_LINK, 'Share link'), action: 'share', stateKey: '' },
      { label: AppStrings.text(AppStrings.R_TOPIC_ACTION_OPEN_BROWSER, 'Open in browser'), action: 'openBrowser', stateKey: '' },
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
