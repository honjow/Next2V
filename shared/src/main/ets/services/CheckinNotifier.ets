import { notificationManager } from '@kit.NotificationKit'
import { common } from '@kit.AbilityKit'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'

// Stable id so a newer check-in result replaces (not stacks on) an older one.
const CHECKIN_NOTIFICATION_ID: number = 70312

/**
 * Posts the auto check-in result as a system notification when the app is backgrounded (a transient toast
 * would be missed — the redeem finishes ~10-15s after launch). Publishing the app's own notifications needs
 * no manifest permission, only the user's one-time consent via requestEnableNotification. All calls are
 * best-effort: a denied/unavailable notification channel must never break the check-in flow.
 */
export class CheckinNotifier {
  // Ask once for consent so a future backgrounded result can surface. Safe to call repeatedly: HarmonyOS
  // only shows the dialog on the first undecided call and otherwise settles without UI. Call while the app
  // is foreground (the dialog needs a window).
  static ensureEnabled(context: common.UIAbilityContext): void {
    try {
      if (notificationManager.isNotificationEnabledSync()) {
        return
      }
      notificationManager.requestEnableNotification(context).catch((_error: Error) => {})
    } catch (error) {
      DiagnosticLogger.warn(
        'auto_daily_checkin',
        'checkin_notify_enable_error',
        { errorKind: (error as Error).name || 'Error' },
        error as Error,
      )
    }
  }

  static publish(title: string, text: string): void {
    try {
      if (!notificationManager.isNotificationEnabledSync()) {
        return
      }
      const request: notificationManager.NotificationRequest = {
        id: CHECKIN_NOTIFICATION_ID,
        content: {
          notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
          normal: {
            title: title,
            text: text,
          },
        },
      }
      notificationManager.publish(request).catch((_error: Error) => {})
    } catch (error) {
      DiagnosticLogger.warn(
        'auto_daily_checkin',
        'checkin_notify_publish_error',
        { errorKind: (error as Error).name || 'Error' },
        error as Error,
      )
    }
  }
}
