import { AppStorageV2 } from '@kit.ArkUI'

/**
 * V2 mirror of the floating reply-button hand edge (`StorageKeys.MOTION_HAND_EDGE`, 'left' | 'right').
 *
 * `MotionHandStateService.setEdge` is the single AppStorage writer (smart-grip holding-hand
 * detection, fixed-left/right alignment, and follow-operation all funnel through it). During the
 * State Management V1->V2 backbone migration it dual-writes: the legacy `AppStorage` key (read by
 * any remaining V1 `@StorageLink`) AND this `@Trace` field (read by `@ComponentV2`
 * `TopicDetailPage`), so the two stores never diverge.
 *
 * A `@ComponentV2` consumer animates its visual edge via `@Monitor('<member>.edge')` when the
 * grip changes. Transitional — drop the `AppStorage` half once every reader is V2.
 */
@ObservedV2
export class MotionHandEdgeState {
  // Default mirrors MotionHandStateService.ensureDefaultEdge ('right').
  @Trace edge: string = 'right'
}

const MOTION_HAND_EDGE_V2_KEY: string = 'v2:motionHandEdge'

/** Returns the app-wide MotionHandEdgeState singleton from AppStorageV2. */
export function connectMotionHandEdge(): MotionHandEdgeState {
  return AppStorageV2.connect(MotionHandEdgeState, MOTION_HAND_EDGE_V2_KEY, () => new MotionHandEdgeState())!
}
