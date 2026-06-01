import { AppStorageV2 } from '@kit.ArkUI'

/**
 * V2 store of the floating reply-button hand edge ('left' | 'right').
 *
 * `MotionHandStateService.setEdge` is the single writer (smart-grip holding-hand detection,
 * fixed-left/right alignment, and follow-operation all funnel through it) and the service reads this
 * `@Trace` field back internally. A `@ComponentV2` consumer (`TopicDetailPage`) animates its visual
 * edge via `@Monitor('<member>.edge')` when the grip changes. V2-only: the legacy `AppStorage` half
 * was retired once every reader moved here.
 */
@ObservedV2
export class MotionHandEdgeState {
  // Default matches MotionHandStateService.ensureDefaultEdge ('right').
  @Trace edge: string = 'right'
}

const MOTION_HAND_EDGE_V2_KEY: string = 'v2:motionHandEdge'

/** Returns the app-wide MotionHandEdgeState singleton from AppStorageV2. */
export function connectMotionHandEdge(): MotionHandEdgeState {
  return AppStorageV2.connect(MotionHandEdgeState, MOTION_HAND_EDGE_V2_KEY, () => new MotionHandEdgeState())!
}
