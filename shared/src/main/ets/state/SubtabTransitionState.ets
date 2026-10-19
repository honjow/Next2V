import { AppStorageV2 } from '@kit.ArkUI'

/**
 * One-shot intent channel for a tap on a pinned shared sub-tab bar (the FeedPills title-bar bar).
 *
 * The bar lives in the HDS title-bar ComponentContent tree while the HomePage Swiper lives in the page
 * tree (separate branches). A click therefore must NOT first change the shared selection state: the
 * controlled Swiper .index() binding would settle the page instantly and the tab indicator with it
 * (the pre-fix click-jump root cause). This channel carries only the requested target; the page host
 * consumes it to start the NATIVE Swiper transition (changeIndex(target, true)), and the settled key
 * flows back through the normal onChange -> publishSelectedKey path. It never becomes the selected/
 * persisted key itself.
 *
 * Ported from the NextE mature implementation (shared/src/main/ets/state/SubtabTransitionState.ets).
 */
@ObservedV2
export class SubtabTransitionState {
  @Trace scope: string = ''
  @Trace targetKey: string = ''
  // A repeated tap on the same target remains a distinct UI request, even when the key text is unchanged.
  @Trace requestSeq: number = 0
}

export const SUBTAB_TRANSITION_SCOPE_HOME: string = 'home'

const SUBTAB_TRANSITION_V2_KEY: string = 'v2:subtabTransition'

/** Returns the app-wide SubtabTransitionState singleton from AppStorageV2. */
export function connectSubtabTransition(): SubtabTransitionState {
  return AppStorageV2.connect(
    SubtabTransitionState,
    SUBTAB_TRANSITION_V2_KEY,
    () => new SubtabTransitionState(),
  )!
}

/** Single writer for a click-driven shared-subtab transition request. */
export class SubtabTransitionBridge {
  static request(scope: string, targetKey: string): void {
    const state: SubtabTransitionState = connectSubtabTransition()
    state.scope = scope
    state.targetKey = targetKey
    state.requestSeq = state.requestSeq + 1
  }
}
