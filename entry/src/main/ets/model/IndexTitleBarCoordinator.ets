import { AppStrings } from 'shared'

export interface TitleBarMenuStats {
  itemCount: number
  maxCount: number
}

export interface UserProfileTitleBarIdentity {
  routeUsername: string
  title: string
  avatarUrl: string
}

export interface NodeTopicTitleBarText {
  title: string
  subtitle: string
}

export interface NodeTopicTitleBarIdentity {
  routeNodeName: string
  title: string
  avatarUrl: string
}

export interface IndexTitleMenuDescriptor {
  label: ResourceStr
  action: string
  icon: string
}

export class IndexTitleBarCoordinator {
  static readonly SINGLE_ITEM_MENU_MAX_COUNT: number = 1
  static readonly WEB_LOGIN_MENU_MAX_COUNT: number = 2

  static emptyMenu(): Record<string, Object> {
    return { 'value': [], 'maxCount': 0 }
  }

  static meMenuItems(): IndexTitleMenuDescriptor[] {
    return [{ label: AppStrings.R_NAV_SETTINGS, action: 'settings', icon: 'settings' }]
  }

  static notificationMenuItems(): IndexTitleMenuDescriptor[] {
    return [{ label: AppStrings.R_NAV_REFRESH, action: 'refresh', icon: 'refresh' }]
  }

  static searchMenuItems(): IndexTitleMenuDescriptor[] {
    return [{ label: AppStrings.R_NAV_FILTER, action: 'filter', icon: 'filter' }]
  }

  static accountManagementMenuItems(): IndexTitleMenuDescriptor[] {
    return [{ label: AppStrings.R_ACCOUNT_ADD_ANOTHER, action: 'addAccount', icon: 'add' }]
  }

  static webLoginMenuItems(): IndexTitleMenuDescriptor[] {
    return [
      { label: AppStrings.R_NAV_SAVE_LOGIN, action: 'save', icon: 'confirm' },
      { label: AppStrings.R_NAV_RELOAD, action: 'reload', icon: 'refresh' },
    ]
  }

  static accountWebViewMenuItems(): IndexTitleMenuDescriptor[] {
    return [{ label: AppStrings.R_NAV_RELOAD, action: 'reload', icon: 'refresh' }]
  }

  static imagePreviewMenuItems(): IndexTitleMenuDescriptor[] {
    return [{ label: AppStrings.R_NAV_SAVE_IMAGE, action: 'save', icon: 'download' }]
  }

  static menuStats(menu: Record<string, Object>): TitleBarMenuStats {
    const value = menu['value'] as Record<string, Object>[]
    const maxCount = menu['maxCount'] as number
    return {
      itemCount: value ? value.length : 0,
      maxCount: maxCount === undefined ? 0 : Math.max(0, maxCount)
    }
  }

  static sameUsername(a: string, b: string): boolean {
    return !!a && !!b && a.trim().toLowerCase() === b.trim().toLowerCase()
  }

  static stringForUsernameState(statesJson: string, username: string): string {
    const key = (username || '').trim().toLowerCase()
    if (!key) {
      return ''
    }
    try {
      const states = JSON.parse(statesJson || '{}') as Record<string, string>
      return (states[key] || '').trim()
    } catch (_e) {
      return ''
    }
  }

  static userProfileIdentity(
    username: string,
    titleRouteUsername: string,
    currentTitleUsername: string,
    currentAvatarUrl: string,
    titleStatesJson: string,
    avatarStatesJson: string
  ): UserProfileTitleBarIdentity {
    const routeUsername = (username || '').trim()
    const titleFromState = IndexTitleBarCoordinator.stringForUsernameState(titleStatesJson, routeUsername)
    const avatarFromState = IndexTitleBarCoordinator.stringForUsernameState(avatarStatesJson, routeUsername)
    const routeMatches = IndexTitleBarCoordinator.sameUsername(titleRouteUsername, routeUsername)
    const title = titleFromState || (currentTitleUsername && routeMatches ? currentTitleUsername : ' ')
    const avatarUrl = avatarFromState || (routeMatches ? (currentAvatarUrl || '').trim() : '')
    return { routeUsername, title, avatarUrl }
  }

  static userProfileActionsAvailable(
    routeUsername: string,
    actionUsername: string,
    actionsAvailable: boolean
  ): boolean {
    return actionsAvailable && routeUsername === actionUsername
  }

  static nodeTopicText(
    nodeName: string,
    nodeTitle: string,
    liveTitle: string,
    liveSubtitle: string
  ): NodeTopicTitleBarText {
    const baseTitle = (nodeTitle || nodeName || '').trim()
    return {
      title: (liveTitle || '').trim() || baseTitle,
      subtitle: (liveSubtitle || '').trim()
    }
  }

  // Scroll-reveal node title identity (mirrors userProfileIdentity): empty title until the node-info
  // card's name scrolls under the app bar, then the per-route reveal ledger supplies icon + name.
  static nodeTopicIdentity(
    nodeName: string,
    titleRouteNodeName: string,
    currentTitleNodeName: string,
    currentAvatarUrl: string,
    titleNameStatesJson: string,
    titleAvatarStatesJson: string
  ): NodeTopicTitleBarIdentity {
    const routeNodeName = (nodeName || '').trim()
    const nameFromState = IndexTitleBarCoordinator.stringForUsernameState(titleNameStatesJson, routeNodeName)
    const avatarFromState = IndexTitleBarCoordinator.stringForUsernameState(titleAvatarStatesJson, routeNodeName)
    const routeMatches = IndexTitleBarCoordinator.sameUsername(titleRouteNodeName, routeNodeName)
    const title = nameFromState || (currentTitleNodeName && routeMatches ? currentTitleNodeName : '')
    const avatarUrl = avatarFromState || (routeMatches ? (currentAvatarUrl || '').trim() : '')
    return { routeNodeName, title, avatarUrl }
  }
}
