import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { ApiDomainSettings } from './ApiDomainSettings'
import { AutoDailyCheckinSettings } from './AutoDailyCheckinSettings'
import { CookieJarSettings } from './CookieJarSettings'
import { AccountStore } from './AccountStore'
import { AccountSessionCoordinator } from './AccountSessionCoordinator'
import { DiagnosticsSettings } from './DiagnosticsSettings'
import { FeedTabSettings } from './FeedTabSettings'
import { LanguageSettings } from './LanguageSettings'
import { MediaSettings } from './MediaSettings'
import { NetworkProxySettings } from './NetworkProxySettings'
import { ReadingSettings } from './ReadingSettings'
import { ReplyActionAlignmentSettings } from './ReplyActionAlignmentSettings'
import { ReplyCardStyleSettings } from './ReplyCardStyleSettings'
import { ReplyDisplaySettings } from './ReplyDisplaySettings'
import { STORE_NAME_SETTINGS, SettingsPreferencesStore } from './SettingsStorage'
import { ThemeSettings } from './ThemeSettings'
import { AutoDailyCheckinService } from '../services/AutoDailyCheckinService'

export class SettingsBootstrap {
  static async loadAll(context: common.UIAbilityContext): Promise<void> {
    let settingsStore: SettingsPreferencesStore | undefined = undefined
    try {
      settingsStore = await preferences.getPreferences(context, STORE_NAME_SETTINGS)
    } catch (_error) {
      // Do not log here. Keep per-setting load(context) fallback behavior below.
    }

    await SettingsBootstrap.restoreDiagnostics(context, settingsStore)
    await SettingsBootstrap.restoreApiDomain(context, settingsStore)
    await SettingsBootstrap.restoreLanguage(context, settingsStore)
    await SettingsBootstrap.restoreTheme(context, settingsStore)
    await SettingsBootstrap.restoreMedia(context, settingsStore)
    await SettingsBootstrap.restoreNetworkProxy(context, settingsStore)
    await SettingsBootstrap.restoreReplyDisplay(context, settingsStore)
    await SettingsBootstrap.restoreReading(context, settingsStore)
    await SettingsBootstrap.restoreFeedTabs(context)
    await SettingsBootstrap.restoreCookieJar(context)
    await SettingsBootstrap.restoreMultiAccount(context)
    await SettingsBootstrap.restoreAutoDailyCheckin(context, settingsStore)
    SettingsBootstrap.triggerStartupCheckin(context)
    await SettingsBootstrap.restoreReplyCardStyle(context, settingsStore)
    await SettingsBootstrap.restoreReplyActionAlignment(context, settingsStore)
  }

  private static async restoreApiDomain(context: common.UIAbilityContext, settingsStore?: SettingsPreferencesStore): Promise<void> {
    await (settingsStore
      ? ApiDomainSettings.loadFromStore(settingsStore)
      : ApiDomainSettings.load(context)
    ).catch((error: Error) => {
      console.error('restore api domain failed: ' + error.message)
      ApiDomainSettings.apply(false)
    })
  }

  private static async restoreDiagnostics(context: common.UIAbilityContext, settingsStore?: SettingsPreferencesStore): Promise<void> {
    await (settingsStore
      ? DiagnosticsSettings.loadFromStore(settingsStore)
      : DiagnosticsSettings.load(context)
    ).catch((_error: Error) => {
      DiagnosticsSettings.apply(DiagnosticsSettings.DEFAULT_ENABLED, DiagnosticsSettings.DEFAULT_MIN_LEVEL)
    })
  }

  private static async restoreLanguage(context: common.UIAbilityContext, settingsStore?: SettingsPreferencesStore): Promise<void> {
    await (settingsStore
      ? LanguageSettings.loadFromStore(settingsStore)
      : LanguageSettings.load(context)
    ).catch((error: Error) => {
      console.error('restore language settings failed: ' + error.message)
      LanguageSettings.apply(LanguageSettings.MODE_SYSTEM)
    })
  }

  private static async restoreTheme(context: common.UIAbilityContext, settingsStore?: SettingsPreferencesStore): Promise<void> {
    await (settingsStore
      ? ThemeSettings.loadFromStore(settingsStore, context)
      : ThemeSettings.load(context)
    ).catch((error: Error) => {
      console.error('restore theme settings failed: ' + error.message)
      ThemeSettings.apply(context, ThemeSettings.MODE_AUTO)
    })
  }

  private static async restoreMedia(context: common.UIAbilityContext, settingsStore?: SettingsPreferencesStore): Promise<void> {
    await (settingsStore
      ? MediaSettings.loadFromStore(settingsStore)
      : MediaSettings.load(context)
    ).catch((error: Error) => {
      console.error('restore media settings failed: ' + error.message)
      MediaSettings.apply(true, false)
    })
  }

  private static async restoreNetworkProxy(context: common.UIAbilityContext, settingsStore?: SettingsPreferencesStore): Promise<void> {
    await (settingsStore
      ? NetworkProxySettings.loadFromStore(settingsStore)
      : NetworkProxySettings.load(context)
    ).catch((error: Error) => {
      console.error('restore network proxy settings failed: ' + error.message)
      NetworkProxySettings.apply(NetworkProxySettings.defaultSnapshot())
    })
  }

  private static async restoreReplyDisplay(context: common.UIAbilityContext, settingsStore?: SettingsPreferencesStore): Promise<void> {
    await (settingsStore
      ? ReplyDisplaySettings.loadFromStore(settingsStore)
      : ReplyDisplaySettings.load(context)
    ).catch((error: Error) => {
      console.error('restore reply display settings failed: ' + error.message)
      ReplyDisplaySettings.apply(ReplyDisplaySettings.MODE_THREAD)
    })
  }

  private static async restoreReading(context: common.UIAbilityContext, settingsStore?: SettingsPreferencesStore): Promise<void> {
    await (settingsStore
      ? ReadingSettings.loadFromStore(settingsStore)
      : ReadingSettings.load(context)
    ).catch((error: Error) => {
      console.error('restore reading settings failed: ' + error.message)
      ReadingSettings.apply(ReadingSettings.TEXT_SCALE_DEFAULT, 20, ReadingSettings.DENSITY_STANDARD)
    })
  }

  private static async restoreFeedTabs(context: common.UIAbilityContext): Promise<void> {
    await FeedTabSettings.load(context).catch((error: Error) => {
      console.error('restore feed tab settings failed: ' + error.message)
      FeedTabSettings.apply(FeedTabSettings.defaultKeysJson())
    })
  }

  private static async restoreCookieJar(context: common.UIAbilityContext): Promise<void> {
    await CookieJarSettings.load(context).catch((error: Error) => {
      console.error('restore cookie jar failed: ' + error.message)
      CookieJarSettings.apply({
        comCookie: '',
        coCookie: '',
        updatedAt: 0,
      })
    })
  }

  private static async restoreMultiAccount(context: common.UIAbilityContext): Promise<void> {
    // Migrate singleton to multi-account if needed
    await AccountStore.migrateFromSingletonIfNeeded(context).catch((error: Error) => {
      console.error('account migration failed: ' + error.message)
    })
    // Restore active account's cookie/session from AccountStore into runtime
    await AccountSessionCoordinator.restoreActiveAccount(context).catch((error: Error) => {
      console.error('restore active account failed: ' + error.message)
    })
  }

  private static async restoreAutoDailyCheckin(context: common.UIAbilityContext, settingsStore?: SettingsPreferencesStore): Promise<void> {
    await (settingsStore
      ? AutoDailyCheckinSettings.loadFromStore(settingsStore)
      : AutoDailyCheckinSettings.load(context)
    ).catch((error: Error) => {
      console.error('restore auto daily check-in setting failed: ' + error.message)
      AutoDailyCheckinSettings.apply(true)
    })
  }

  private static triggerStartupCheckin(context: common.UIAbilityContext): void {
    AutoDailyCheckinService.tryCheckin(
      context,
      CookieJarSettings.getCurrentCookie(),
      'startup',
    ).catch((error: Error) => {
      console.info('auto daily check-in startup trigger failed: ' + error.message)
    })
  }

  private static async restoreReplyCardStyle(context: common.UIAbilityContext, settingsStore?: SettingsPreferencesStore): Promise<void> {
    await (settingsStore
      ? ReplyCardStyleSettings.loadFromStore(settingsStore)
      : ReplyCardStyleSettings.load(context)
    ).catch((error: Error) => {
      console.error('restore reply card style failed: ' + error.message)
      ReplyCardStyleSettings.apply(ReplyCardStyleSettings.STYLE_STANDARD)
    })
  }

  private static async restoreReplyActionAlignment(context: common.UIAbilityContext, settingsStore?: SettingsPreferencesStore): Promise<void> {
    await (settingsStore
      ? ReplyActionAlignmentSettings.loadFromStore(settingsStore)
      : ReplyActionAlignmentSettings.load(context)
    ).catch((error: Error) => {
      console.error('restore reply action alignment failed: ' + error.message)
      ReplyActionAlignmentSettings.apply(ReplyActionAlignmentSettings.MODE_UNSET)
    })
  }
}
