import { AppStorageV2 } from '@kit.ArkUI'

/**
 * V2 mirror of the diagnostics settings (`StorageKeys.DIAGNOSTICS_ENABLED` /
 * `StorageKeys.DIAGNOSTICS_MIN_LEVEL`).
 *
 * `DiagnosticsSettings.apply()` is the single chokepoint (hydration `loadFromStore` and `save()`
 * both route through it). It publishes these `@Trace` fields (read by `@ComponentV2`
 * `DiagnosticsLogPage` and by `DiagnosticsSettings`' own getters) while still mirroring the
 * preferences-backed AppStorage keys for the contract-pinned settings hydration path.
 */
@ObservedV2
export class DiagnosticsState {
  // Default mirrors DiagnosticsSettings.DEFAULT_ENABLED (true); published by apply().
  @Trace enabled: boolean = true
  // Default mirrors DiagnosticsSettings.DEFAULT_MIN_LEVEL ('info'); published by apply().
  @Trace minLevel: string = 'info'
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
