export interface NodeTopicAppbarIdentity {
  routeNodeName: string
  titleNodeName: string
  avatarUrl: string
}

/**
 * Pure logic for NodeTopicPage's scroll-reveal app bar (mirrors UserProfilePageCoordinator). Keeps the
 * geometry / identity decisions out of the @ComponentV2 leaf so the page stays a thin view.
 */
export class NodeTopicPageCoordinator {
  static displayName(detailTitle: string, fallbackTitle: string, fallbackName: string): string {
    return (detailTitle || fallbackTitle || fallbackName || '').trim()
  }

  static shouldShowAppbarTitle(
    displayName: string,
    nameContentBottom: number,
    currentScrollOffset: number,
    topAvoidHeight: number,
    titleBarHeight: number,
    previousVisible: boolean,
    hysteresis: number,
  ): boolean {
    if (!displayName || nameContentBottom <= 0) {
      return false
    }
    const currentNameBottom = nameContentBottom - currentScrollOffset
    const appbarBottom = topAvoidHeight + titleBarHeight
    return previousVisible
      ? currentNameBottom <= appbarBottom + hysteresis
      : currentNameBottom <= appbarBottom
  }

  static appbarIdentity(
    visible: boolean,
    routeNodeName: string,
    displayName: string,
    avatarUrl: string,
  ): NodeTopicAppbarIdentity {
    return {
      routeNodeName: visible ? routeNodeName : '',
      titleNodeName: visible ? displayName : '',
      avatarUrl: visible ? avatarUrl : '',
    }
  }

  static nextStringState(statesJson: string, nodeName: string, value: string): string {
    const key = (nodeName || '').trim().toLowerCase()
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

  static sameNodeName(a: string, b: string): boolean {
    return !!a && !!b && a.trim().toLowerCase() === b.trim().toLowerCase()
  }
}
