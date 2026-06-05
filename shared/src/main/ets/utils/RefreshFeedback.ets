import { promptAction } from '@kit.ArkUI'
import { AppStrings } from '../i18n/AppStrings'

/**
 * Feedback for a failed pull-to-refresh.
 *
 * When a refresh fails while content is already on screen, the error is invisible: the page only
 * renders its error/empty state when the list is empty, so with content present the failure looks
 * like a no-op (e.g. a 403 from a banned exit IP shows nothing until the user opens a topic). Surface
 * it as a toast in exactly that case — initial loads (no content yet) keep their inline error view.
 */
export class RefreshFeedback {
  static notifyRefreshError(hasContent: boolean): void {
    if (!hasContent) {
      return
    }
    promptAction
      .openToast({ message: AppStrings.text(AppStrings.R_COMMON_REFRESH_FAILED, 'Refresh failed') })
      .catch((_error: Error) => {})
  }
}
