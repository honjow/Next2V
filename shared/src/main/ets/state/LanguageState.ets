import { AppStorageV2 } from '@kit.ArkUI'

/**
 * V2 mirror of the app language mode (`StorageKeys.LANGUAGE_MODE`).
 *
 * `LanguageSettings.apply()` is the single chokepoint (load/save and EntryAbility's
 * applyStoredPreferredLanguage all route through it); it still writes the legacy `AppStorage` key via
 * `setAppStorageValue` AND seeds these `@Trace` fields. `mode` preserves the user's selection, while
 * `effectiveLocale` is the concrete locale currently applied to resource resolution. UI components that
 * show `ResourceStr` text read `effectiveLocale` so a hot language switch re-renders without key churn.
 */
@ObservedV2
export class LanguageState {
  @Trace mode: string = 'default'
  @Trace effectiveLocale: string = ''
}

const LANGUAGE_V2_KEY: string = 'v2:language'

/** Returns the app-wide LanguageState singleton from AppStorageV2. */
export function connectLanguageState(): LanguageState {
  return AppStorageV2.connect(LanguageState, LANGUAGE_V2_KEY, () => new LanguageState())!
}
