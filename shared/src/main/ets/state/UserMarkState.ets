import { AppStorageV2 } from '@kit.ArkUI'

/**
 * V2 runtime mirror for local user marks.
 *
 * `UserMarkSettings` is the sole persistence writer. UI components read these
 * `@Trace` JSON fields in build to refresh badges immediately after a mark is
 * added, removed, or the visible badge count changes.
 */
@ObservedV2
export class UserMarkState {
  @Trace labelsJson: string = '[]'
  @Trace assignmentsJson: string = '[]'
  @Trace displayLimit: number = 2
  @Trace combinedBadge: boolean = false
  @Trace updatedAt: number = 0
}

const USER_MARKS_V2_KEY: string = 'v2:userMarks'

/** Returns the app-wide UserMarkState singleton from AppStorageV2. */
export function connectUserMarks(): UserMarkState {
  return AppStorageV2.connect(UserMarkState, USER_MARKS_V2_KEY, () => new UserMarkState())!
}
