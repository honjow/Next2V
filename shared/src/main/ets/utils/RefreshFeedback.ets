import { AppPrompt } from './AppPrompt'
import { AppStrings } from '../i18n/AppStrings'

/**
 * Centralized feedback for a failed pull-to-refresh.
 *
 * The shared `PullRefresh` component calls this when its refresh callback REJECTS. Initial loads
 * (e.g. a ViewModel's `loadData`) never go through `PullRefresh`, so an empty-list first-load failure
 * keeps its inline error/empty view and is never double-reported here. The only thing each feed must do
 * is let its refresh reject on failure (instead of swallowing the error) — the toast itself lives here,
 * written once.
 */
export class RefreshFeedback {
  static notifyRefreshFailed(): void {
    AppPrompt.openToast({ message: AppStrings.text($r('app.string.common_refresh_failed'), 'Refresh failed') })
      .catch((_error: Error) => {})
  }
}
