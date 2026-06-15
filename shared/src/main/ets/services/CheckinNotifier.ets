import { notificationManager } from '@kit.NotificationKit'
import { common, Want, wantAgent, WantAgent } from '@kit.AbilityKit'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'

// Stable id so a newer check-in result replaces (not stacks on) an older one.
const CHECKIN_NOTIFICATION_ID: number = 70312

/**
 * Posts the auto check-in result as a system notification. Used for the actionable case — "today's
 * check-in did NOT go through" — so it must reach the user even when the redeem finished after they left
 * the app (a transient toast would be missed). Tapping the notification re-launches the app via a
 * START_ABILITY WantAgent. Publishing the app's own notifications needs no manifest permission, only the
 * user's one-time consent via requestEnableNotification. All calls are best-effort: a denied/unavailable
 * channel must never break the check-in flow.
 */
export class CheckinNotifier {
  // Ask once for consent so a backgrounded result can surface. Safe to call repeatedly: HarmonyOS only
  // shows the dialog on the first undecided call and otherwise settles without UI. Call while foreground
  // (the dialog needs a window) — do it early so the notification can post by the time a failure happens.
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
      // Tapping the notification re-launches the app so the user can check in manually.
      const launchWant: Want = {
        bundleName: 'com.honjow.next2v',
        abilityName: 'EntryAbility',
      }
      const info: wantAgent.WantAgentInfo = {
        wants: [launchWant],
        actionType: wantAgent.OperationType.START_ABILITY,
        requestCode: 0,
        wantAgentFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG],
      }
      wantAgent
        .getWantAgent(info)
        .then((agent: WantAgent) => {
          CheckinNotifier.doPublish(title, text, agent)
        })
        .catch((_error: Error) => {
          // Fall back to a non-tappable notification rather than dropping the alert entirely.
          CheckinNotifier.doPublish(title, text, null)
        })
    } catch (error) {
      DiagnosticLogger.warn(
        'auto_daily_checkin',
        'checkin_notify_publish_error',
        { errorKind: (error as Error).name || 'Error' },
        error as Error,
      )
    }
  }

  private static doPublish(title: string, text: string, agent: WantAgent | null): void {
    try {
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
      if (agent) {
        request.wantAgent = agent
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
