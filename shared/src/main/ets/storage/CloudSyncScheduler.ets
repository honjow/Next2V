import { common } from '@kit.AbilityKit'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { connectCloudSync } from '../state/CloudSyncState'
import { CloudSyncSettings } from '../settings/CloudSyncSettings'

export type CloudSyncExecutor = (context: common.UIAbilityContext, reason: string) => Promise<boolean>

const LOCAL_WRITE_DEBOUNCE_MS: number = 15000
const FOREGROUND_DEBOUNCE_MS: number = 3000
const MIN_ATTEMPT_INTERVAL_MS: number = 45000
const RETRY_BASE_MS: number = 60000
const RETRY_MAX_MS: number = 300000

// Coalesces noisy local writes into a near-term manual cloud sync. System autoSync still remains enabled;
// this scheduler makes user-visible writes push sooner without firing one cloud round per row.
export class CloudSyncScheduler {
  private static context: common.UIAbilityContext | null = null
  private static executor: CloudSyncExecutor | null = null
  private static timerId: number = 0
  private static scheduledAt: number = 0
  private static inFlight: boolean = false
  private static pendingReason: string = ''
  private static lastAttemptAt: number = 0
  private static failureCount: number = 0

  static bindExecutor(executor: CloudSyncExecutor): void {
    CloudSyncScheduler.executor = executor
  }

  static rememberContext(context: common.UIAbilityContext): void {
    CloudSyncScheduler.context = context
  }

  static requestAfterLocalWrite(context: common.UIAbilityContext, reason: string): void {
    CloudSyncScheduler.request(context, reason, LOCAL_WRITE_DEBOUNCE_MS)
  }

  static requestAfterForeground(context: common.UIAbilityContext, reason: string): void {
    CloudSyncScheduler.request(context, reason, FOREGROUND_DEBOUNCE_MS)
  }

  private static request(
    context: common.UIAbilityContext,
    reason: string,
    requestedDelayMs: number,
  ): void {
    CloudSyncScheduler.context = context
    if (!CloudSyncSettings.isEnabled()) {
      return
    }
    CloudSyncScheduler.pendingReason = reason
    const delayMs = CloudSyncScheduler.nextDelayMs(Date.now(), requestedDelayMs)
    CloudSyncScheduler.scheduleTimer(delayMs, reason)
  }

  private static nextDelayMs(now: number, requestedDelayMs: number): number {
    let delayMs = Math.max(0, requestedDelayMs)
    if (CloudSyncScheduler.lastAttemptAt > 0) {
      const nextAllowedAt = CloudSyncScheduler.lastAttemptAt + MIN_ATTEMPT_INTERVAL_MS
      if (nextAllowedAt > now) {
        delayMs = Math.max(delayMs, nextAllowedAt - now)
      }
    }
    if (CloudSyncScheduler.failureCount > 0 && CloudSyncScheduler.lastAttemptAt > 0) {
      const retryAt = CloudSyncScheduler.lastAttemptAt + CloudSyncScheduler.retryDelayMs()
      if (retryAt > now) {
        delayMs = Math.max(delayMs, retryAt - now)
      }
    }
    return delayMs
  }

  private static retryDelayMs(): number {
    let delayMs = RETRY_BASE_MS
    let count = CloudSyncScheduler.failureCount
    while (count > 1 && delayMs < RETRY_MAX_MS) {
      delayMs = delayMs * 2
      count = count - 1
    }
    return Math.min(delayMs, RETRY_MAX_MS)
  }

  private static scheduleTimer(delayMs: number, reason: string): void {
    const now = Date.now()
    const dueAt = now + Math.max(0, delayMs)
    if (CloudSyncScheduler.timerId > 0 && CloudSyncScheduler.scheduledAt <= dueAt) {
      DiagnosticLogger.info('cloud_sync', 'cloud_sync_schedule_kept', {
        reason: reason,
        dueInMs: Math.max(0, CloudSyncScheduler.scheduledAt - now),
      })
      return
    }
    if (CloudSyncScheduler.timerId > 0) {
      clearTimeout(CloudSyncScheduler.timerId)
      CloudSyncScheduler.timerId = 0
    }
    CloudSyncScheduler.scheduledAt = dueAt
    CloudSyncScheduler.timerId = setTimeout(() => {
      CloudSyncScheduler.fire()
    }, Math.max(0, delayMs))
    DiagnosticLogger.info('cloud_sync', 'cloud_sync_scheduled', {
      reason: reason,
      delayMs: Math.max(0, delayMs),
    })
  }

  private static fire(): void {
    CloudSyncScheduler.timerId = 0
    CloudSyncScheduler.scheduledAt = 0
    const context = CloudSyncScheduler.context
    const executor = CloudSyncScheduler.executor
    const reason = CloudSyncScheduler.pendingReason || 'scheduled'
    CloudSyncScheduler.pendingReason = ''
    if (context === null || executor === null || !CloudSyncSettings.isEnabled()) {
      return
    }
    if (CloudSyncScheduler.inFlight || connectCloudSync().syncing) {
      CloudSyncScheduler.pendingReason = reason
      CloudSyncScheduler.scheduleTimer(MIN_ATTEMPT_INTERVAL_MS, reason)
      return
    }
    CloudSyncScheduler.inFlight = true
    CloudSyncScheduler.lastAttemptAt = Date.now()
    DiagnosticLogger.info('cloud_sync', 'cloud_sync_scheduled_start', { reason: reason })
    executor(context, reason)
      .then((ok: boolean) => {
        CloudSyncScheduler.finish(ok, reason)
      })
      .catch((error: Error) => {
        CloudSyncScheduler.finish(false, reason)
        DiagnosticLogger.warn(
          'cloud_sync',
          'cloud_sync_scheduled_error',
          { reason: reason, message: error.message || '' },
          error,
        )
      })
      .finally(() => {
        CloudSyncScheduler.inFlight = false
        if (CloudSyncScheduler.pendingReason && CloudSyncSettings.isEnabled()) {
          const pending = CloudSyncScheduler.pendingReason
          CloudSyncScheduler.scheduleTimer(
            CloudSyncScheduler.nextDelayMs(Date.now(), LOCAL_WRITE_DEBOUNCE_MS),
            pending,
          )
        }
      })
  }

  private static finish(ok: boolean, reason: string): void {
    if (ok) {
      CloudSyncScheduler.failureCount = 0
    } else {
      CloudSyncScheduler.failureCount = Math.min(CloudSyncScheduler.failureCount + 1, 4)
    }
    DiagnosticLogger.info('cloud_sync', 'cloud_sync_scheduled_done', {
      ok: ok,
      reason: reason,
      failureCount: CloudSyncScheduler.failureCount,
    })
  }
}
