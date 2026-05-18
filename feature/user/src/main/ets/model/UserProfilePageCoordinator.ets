import { V2exMemberActionState } from 'shared'

export interface UserProfileTabLabels {
  topicLabel: string
  replyLabel: string
}

export interface UserProfileActionMenuState {
  username: string
  available: boolean
  followLabel: string
  blockLabel: string
  following: boolean
  blocked: boolean
}

export interface UserProfileAppbarIdentity {
  routeUsername: string
  titleUsername: string
  avatarUrl: string
}

export class UserProfilePageCoordinator {
  static tabLabels(topicCount: number, replyCount: number): UserProfileTabLabels {
    return {
      topicLabel: topicCount > 0 ? `主题 ${topicCount}` : '主题',
      replyLabel: replyCount > 0 ? `回复 ${replyCount}` : '回复'
    }
  }

  static shouldShowAllActivityButton(
    activityTab: number,
    topicCount: number,
    topicsHidden: boolean,
    replyCount: number
  ): boolean {
    if (activityTab === 0) {
      return topicCount > 0 && !topicsHidden
    }
    return replyCount > 0
  }

  static displayUsername(profileUsername: string, routeUsername: string): string {
    return (profileUsername || routeUsername || '').trim()
  }

  static shouldShowAppbarTitle(
    displayUsername: string,
    usernameContentBottom: number,
    currentScrollOffset: number,
    topAvoidHeight: number,
    titleBarHeight: number,
    previousVisible: boolean,
    hysteresis: number
  ): boolean {
    if (!displayUsername || usernameContentBottom <= 0) {
      return false
    }
    const currentUsernameBottom = usernameContentBottom - currentScrollOffset
    const appbarBottom = topAvoidHeight + titleBarHeight
    return previousVisible
      ? currentUsernameBottom <= appbarBottom + hysteresis
      : currentUsernameBottom <= appbarBottom
  }

  static appbarIdentity(
    visible: boolean,
    routeUsername: string,
    displayUsername: string,
    avatarUrl: string
  ): UserProfileAppbarIdentity {
    return {
      routeUsername: visible ? routeUsername : '',
      titleUsername: visible ? displayUsername : '',
      avatarUrl: visible ? avatarUrl : ''
    }
  }

  static nextStringState(statesJson: string, username: string, value: string): string {
    const key = (username || '').trim().toLowerCase()
    if (!key) {
      return statesJson || '{}'
    }
    let states: Record<string, string> = {}
    try {
      const parsed = JSON.parse(statesJson || '{}') as Record<string, string>
      if (parsed && typeof parsed === 'object' && !Array.isArray(parsed)) {
        states = parsed
      }
    } catch (_e) {}
    states[key] = value
    return JSON.stringify(states)
  }

  static actionMenuState(
    actions: V2exMemberActionState | null,
    isCurrentSessionUser: boolean,
    hasCookie: boolean,
    username: string,
    following: boolean,
    blocked: boolean
  ): UserProfileActionMenuState {
    const canShowActions = actions !== null && !isCurrentSessionUser && hasCookie
    const hasFollowAction = canShowActions && !!actions?.followPath
    const hasBlockAction = canShowActions && !!actions?.blockPath
    return {
      username: username,
      available: hasFollowAction || hasBlockAction,
      followLabel: hasFollowAction ? (following ? '取消关注' : '关注') : '',
      blockLabel: hasBlockAction ? (blocked ? '取消屏蔽' : '屏蔽') : '',
      following: hasFollowAction && following,
      blocked: hasBlockAction && blocked
    }
  }

  static sameUsername(a: string, b: string): boolean {
    return !!a && !!b && a.trim().toLowerCase() === b.trim().toLowerCase()
  }
}
