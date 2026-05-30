import { AppStorageV2 } from '@kit.ArkUI'

/**
 * V2 mirror of the diagnostics-enabled setting (`StorageKeys.DIAGNOSTICS_ENABLED`).
 *
 * `DiagnosticsSettings.apply()` is the single AppStorage writer (hydration `loadFromStore`
 * and `save()` both route through it). During the V1->V2 backbone migration it dual-writes
 * the legacy `AppStorage` key (V1 `@StorageLink` readers) AND this `@Trace` field
 * (`@ComponentV2` readers, e.g. `DiagnosticsLogPage`). Transitional.
 */
@ObservedV2
export class DiagnosticsState {
  // Default mirrors DiagnosticsSettings.DEFAULT_ENABLED (true); published by apply().
  @Trace enabled: boolean = true
}

const DIAGNOSTICS_V2_KEY: string = 'v2:diagnostics'

/** Returns the app-wide DiagnosticsState singleton from AppStorageV2. */
export function connectDiagnostics(): DiagnosticsState {
  return AppStorageV2.connect(
    DiagnosticsState,
    DIAGNOSTICS_V2_KEY,
    () => new DiagnosticsState(),
  )!
}
