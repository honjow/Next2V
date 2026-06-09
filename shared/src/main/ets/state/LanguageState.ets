import { AppStorageV2 } from '@kit.ArkUI'

/**
 * V2 mirror of the app language mode (`StorageKeys.LANGUAGE_MODE`).
 *
 * `LanguageSettings.apply()` is the single chokepoint (load/save and EntryAbility's
 * applyStoredPreferredLanguage all route through it); it still writes the legacy `AppStorage` key via
 * `setAppStorageValue` AND seeds this `@Trace` field. The migrated readers — SettingsPage hydration
 * and `LanguageSettings.reapplyForFollowSystem` — read this mirror instead of `AppStorage.get`.
 * Default mirrors `LanguageSettings.MODE_SYSTEM` ('default'); the follow-system fallback /
 * supported-locale normalization semantics are unchanged.
 */
@ObservedV2
export class LanguageState {
  @Trace mode: string = 'default'
}

const LANGUAGE_V2_KEY: string = 'v2:language'

/** Returns the app-wide LanguageState singleton from AppStorageV2. */
export function connectLanguageState(): LanguageState {
  return AppStorageV2.connect(LanguageState, LANGUAGE_V2_KEY, () => new LanguageState())!
}
