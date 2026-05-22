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
    return [{ label: '刷新', action: 'refresh', icon: 'refresh' }]
  }

  static searchMenuItems(): IndexTitleMenuDescriptor[] {
    return [{ label: '筛选', action: 'filter', icon: 'filter' }]
  }

  static webLoginMenuItems(): IndexTitleMenuDescriptor[] {
    return [
      { label: '保存登录', action: 'save', icon: 'confirm' },
      { label: '重新加载', action: 'reload', icon: 'refresh' },
    ]
  }

  static imagePreviewMenuItems(): IndexTitleMenuDescriptor[] {
    return [{ label: '保存图片', action: 'save', icon: 'download' }]
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
}
