export interface TopicDetailFollowTouchState {
  active: boolean
  startX: number
  startY: number
  latestX: number
  latestY: number
  reported: boolean
}

export interface TopicDetailFollowTouchUpdate {
  state: TopicDetailFollowTouchState
  shouldReport: boolean
  reportX: number
}

export class TopicDetailFloatingActionCoordinator {
  static actionBarTop(rootHeight: number, bottomAvoidHeight: number, buttonSize: number): number {
    if (rootHeight <= 0) {
      return 0
    }
    return Math.max(0, rootHeight - bottomAvoidHeight - buttonSize)
  }

  static actionBarAlign(edge: string): FlexAlign {
    return edge === 'left' ? FlexAlign.Start : FlexAlign.End
  }

  static initialTouchState(): TopicDetailFollowTouchState {
    return {
      active: false,
      startX: 0,
      startY: 0,
      latestX: 0,
      latestY: 0,
      reported: false,
    }
  }

  static updateTouch(
    state: TopicDetailFollowTouchState,
    type: TouchType,
    x: number,
    y: number,
    verticalThreshold: number,
    verticalDominanceRatio: number,
  ): TopicDetailFollowTouchUpdate {
    if (type === TouchType.Down) {
      return {
        state: {
          active: true,
          startX: x,
          startY: y,
          latestX: x,
          latestY: y,
          reported: false,
        },
        shouldReport: false,
        reportX: 0,
      }
    }
    if (!state.active) {
      return { state, shouldReport: false, reportX: 0 }
    }
    if (type === TouchType.Up || type === TouchType.Cancel) {
      return {
        state: TopicDetailFloatingActionCoordinator.initialTouchState(),
        shouldReport: false,
        reportX: 0,
      }
    }
    if (type !== TouchType.Move) {
      return { state, shouldReport: false, reportX: 0 }
    }
    const nextState: TopicDetailFollowTouchState = {
      active: true,
      startX: state.startX,
      startY: state.startY,
      latestX: x,
      latestY: y,
      reported: state.reported,
    }
    if (state.reported) {
      return { state: nextState, shouldReport: false, reportX: 0 }
    }
    const dx = x - state.startX
    const dy = y - state.startY
    const absDx = Math.abs(dx)
    const absDy = Math.abs(dy)
    if (absDy < verticalThreshold || absDy < absDx * verticalDominanceRatio) {
      return { state: nextState, shouldReport: false, reportX: 0 }
    }
    nextState.reported = true
    return {
      state: nextState,
      shouldReport: true,
      reportX: state.startX,
    }
  }
}
