import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { ApiDomainSettings } from './ApiDomainSettings'
import { AvatarAppearanceSettings } from './AvatarAppearanceSettings'
import { AutoDailyCheckinSettings } from './AutoDailyCheckinSettings'
import { CookieJarSettings } from './CookieJarSettings'
import { AccountStore } from './AccountStore'
import { AccountSessionCoordinator } from './AccountSessionCoordinator'
import { DiagnosticsSettings } from './DiagnosticsSettings'
import { FeedTabSettings } from './FeedTabSettings'
import { HomeTabSettings } from './HomeTabSettings'
import { HotReplySettings } from './HotReplySettings'
import { ImmersiveMaterialSettings } from './ImmersiveMaterialSettings'
import { TopicDetailReplyActionSettings } from './TopicDetailReplyActionSettings'
import { LanguageSettings } from './LanguageSettings'
import { MediaSettings } from './MediaSettings'
import { ImageUploadSettings } from './ImageUploadSettings'
import { RecentStickerSettings } from './RecentStickerSettings'
import { IgnoredNodesSettings } from './IgnoredNodesSettings'
import { NetworkProxySettings } from './NetworkProxySettings'
import { ReadingSettings } from './ReadingSettings'
import { ReplyActionAlignmentSettings } from './ReplyActionAlignmentSettings'
import { ReplyCardStyleSettings } from './ReplyCardStyleSettings'
import { ReplyDisplaySettings } from './ReplyDisplaySettings'
import { STORE_NAME_SETTINGS, SettingsPreferencesStore } from './SettingsStorage'
import { ThemeSettings } from './ThemeSettings'
import { ThemeColorSettings } from './ThemeColorSettings'
import { AutoDailyCheckinService } from '../services/AutoDailyCheckinService'
import { BlockedListSettings } from './BlockedListSettings'
import { UserMarkSettings } from './UserMarkSettings'
import { CloudSyncSettings } from './CloudSyncSettings'

export class SettingsBootstrap {
  static async loadAll(context: common.UIAbilityContext): Promise<void> {
    BlockedListSettings.setContext(context)
    let settingsStore: SettingsPreferencesStore | undefined = undefined
    try {
      settingsStore = await preferences.getPreferences(context, STORE_NAME_SETTINGS)
    } catch (_error) {
      // Do not log here. Keep per-setting load(context) fallback behavior below.
    }

    await SettingsBootstrap.restoreDiagnostics(context, settingsStore)
    await SettingsBootstrap.restoreApiDomain(context, settingsStore)
    await SettingsBootstrap.restoreLanguage(context, settingsStore)
    await SettingsBootstrap.restoreThemeColor(context, settingsStore)
    await SettingsBootstrap.restoreImmersiveMaterial(context, settingsStore)
    await SettingsBootstrap.restoreTheme(context, settingsStore)
    await SettingsBootstrap.restoreAvatarAppearance(context, settingsStore)
    await SettingsBootstrap.restoreMedia(context, settingsStore)
    await SettingsBootstrap.restoreImageUpload(context, settingsStore)
    await SettingsBootstrap.restoreRecentStickers(context)
    await SettingsBootstrap.restoreIgnoredNodes(context)
    await SettingsBootstrap.restoreNetworkProxy(context, settingsStore)
    await SettingsBootstrap.restoreReplyDisplay(context, settingsStore)
    await SettingsBootstrap.restoreHotReplies(context, settingsStore)
    await SettingsBootstrap.restoreReading(context, settingsStore)
    await SettingsBootstrap.restoreHomeTabs(context, settingsStore)
    await SettingsBootstrap.restoreTopicDetailReplyAction(context, settingsStore)
    await SettingsBootstrap.restoreFeedTabs(context)
    await SettingsBootstrap.restoreCookieJar(context)
    await SettingsBootstrap.restoreMultiAccount(context)
    await SettingsBootstrap.restoreBlockedLists(context)
    await SettingsBootstrap.restoreUserMarks(context)
    await SettingsBootstrap.restoreAutoDailyCheckin(context, settingsStore)
    SettingsBootstrap.triggerStartupCheckin(context)
    await SettingsBootstrap.restoreReplyCardStyle(context, settingsStore)
    await SettingsBootstrap.restoreReplyActionAlignment(context, settingsStore)
    await SettingsBootstrap.restoreCloudSync(context, settingsStore)
  }

  /**
   * Re-apply the store-backed settings into AppStorage / live state holders after a backup import
   * has written them directly into the unified store. Mirrors loadAll's settings restores, but
   * deliberately skips cookie jar, multi-account, the startup check-in trigger, and the network
   * proxy: those are runtime/credential surfaces that the import either must not touch (plaintext)
   * or restores through the encrypted account path (userInfo).
   */
  static async reapplyFromStore(context: common.UIAbilityContext): Promise<void> {
    BlockedListSettings.setContext(context)
    let settingsStore: SettingsPreferencesStore | undefined = undefined
    try {
      settingsStore = await preferences.getPreferences(context, STORE_NAME_SETTINGS)
    } catch (_error) {
      // fall back to per-setting load(context) below
    }
    await SettingsBootstrap.restoreDiagnostics(context, settingsStore)
    await SettingsBootstrap.restoreApiDomain(context, settingsStore)
    await SettingsBootstrap.restoreLanguage(context, settingsStore)
    await SettingsBootstrap.restoreThemeColor(context, settingsStore)
    await SettingsBootstrap.restoreImmersiveMaterial(context, settingsStore)
    await SettingsBootstrap.restoreTheme(context, settingsStore)
    await SettingsBootstrap.restoreAvatarAppearance(context, settingsStore)
    await SettingsBootstrap.restoreMedia(context, settingsStore)
    await SettingsBootstrap.restoreImageUpload(context, settingsStore)
    await SettingsBootstrap.restoreRecentStickers(context)
    await SettingsBootstrap.restoreIgnoredNodes(context)
    await SettingsBootstrap.restoreReplyDisplay(context, settingsStore)
    await SettingsBootstrap.restoreHotReplies(context, settingsStore)
    await SettingsBootstrap.restoreReading(context, settingsStore)
    await SettingsBootstrap.restoreHomeTabs(context, settingsStore)
    await SettingsBootstrap.restoreTopicDetailReplyAction(context, settingsStore)
    await SettingsBootstrap.restoreFeedTabs(context)
    await SettingsBootstrap.restoreBlockedLists(context)
    await SettingsBootstrap.restoreUserMarks(context)
    await SettingsBootstrap.restoreAutoDailyCheckin(context, settingsStore)
    await SettingsBootstrap.restoreReplyCardStyle(context, settingsStore)
    await SettingsBootstrap.restoreReplyActionAlignment(context, settingsStore)
    await SettingsBootstrap.restoreCloudSync(context, settingsStore)
  }

  private static async restoreApiDomain(
    context: common.UIAbilityContext,
    settingsStore?: SettingsPreferencesStore,
  ): Promise<void> {
    await (
      settingsStore
        ? ApiDomainSettings.loadFromStore(settingsStore)
        : ApiDomainSettings.load(context)
    ).catch((error: Error) => {
      console.error('restore api domain failed: ' + error.message)
      ApiDomainSettings.apply('https://www.v2ex.com')
    })
  }

  private static async restoreDiagnostics(
    context: common.UIAbilityContext,
    settingsStore?: SettingsPreferencesStore,
  ): Promise<void> {
    await (
      settingsStore
        ? DiagnosticsSettings.loadFromStore(settingsStore)
        : DiagnosticsSettings.load(context)
    ).catch((_error: Error) => {
      DiagnosticsSettings.apply(
        DiagnosticsSettings.DEFAULT_ENABLED,
        DiagnosticsSettings.DEFAULT_MIN_LEVEL,
      )
    })
  }

  private static async restoreUserMarks(context: common.UIAbilityContext): Promise<void> {
    await UserMarkSettings.load(context).catch((error: Error) => {
      console.error('restore user marks failed: ' + error.message)
    })
  }

  private static async restoreLanguage(
    context: common.UIAbilityContext,
    settingsStore?: SettingsPreferencesStore,
  ): Promise<void> {
    await (
      settingsStore ? LanguageSettings.loadFromStore(settingsStore) : LanguageSettings.load(context)
    ).catch((error: Error) => {
      console.error('restore language settings failed: ' + error.message)
      LanguageSettings.apply(LanguageSettings.MODE_SYSTEM)
    })
  }

  private static async restoreTheme(
    context: common.UIAbilityContext,
    settingsStore?: SettingsPreferencesStore,
  ): Promise<void> {
    await (
      settingsStore
        ? ThemeSettings.loadFromStore(settingsStore, context)
        : ThemeSettings.load(context)
    ).catch((error: Error) => {
      console.error('restore theme settings failed: ' + error.message)
      ThemeSettings.apply(context, ThemeSettings.MODE_AUTO)
    })
  }

  private static async restoreThemeColor(
    context: common.UIAbilityContext,
    settingsStore?: SettingsPreferencesStore,
  ): Promise<void> {
    await (
      settingsStore
        ? ThemeColorSettings.loadFromStore(settingsStore)
        : ThemeColorSettings.load(context)
    ).catch((error: Error) => {
      console.error('restore theme color settings failed: ' + error.message)
      ThemeColorSettings.apply(ThemeColorSettings.DEFAULT_COLOR)
    })
  }

  private static async restoreImmersiveMaterial(
    context: common.UIAbilityContext,
    settingsStore?: SettingsPreferencesStore,
  ): Promise<void> {
    await (
      settingsStore
        ? ImmersiveMaterialSettings.loadFromStore(settingsStore)
        : ImmersiveMaterialSettings.load(context)
    ).catch((error: Error) => {
      console.error('restore immersive material settings failed: ' + error.message)
      ImmersiveMaterialSettings.apply(ImmersiveMaterialSettings.DEFAULT_LEVEL)
    })
  }

  private static async restoreAvatarAppearance(
    context: common.UIAbilityContext,
    settingsStore?: SettingsPreferencesStore,
  ): Promise<void> {
    await (
      settingsStore
        ? AvatarAppearanceSettings.loadFromStore(settingsStore)
        : AvatarAppearanceSettings.load(context)
    ).catch((error: Error) => {
      console.error('restore avatar appearance failed: ' + error.message)
      AvatarAppearanceSettings.apply(AvatarAppearanceSettings.APPEARANCE_SOFT)
    })
  }

  private static async restoreMedia(
    context: common.UIAbilityContext,
    settingsStore?: SettingsPreferencesStore,
  ): Promise<void> {
    await (
      settingsStore ? MediaSettings.loadFromStore(settingsStore) : MediaSettings.load(context)
    ).catch((error: Error) => {
      console.error('restore media settings failed: ' + error.message)
      MediaSettings.apply(true, false)
    })
  }

  private static async restoreImageUpload(
    context: common.UIAbilityContext,
    settingsStore?: SettingsPreferencesStore,
  ): Promise<void> {
    await (
      settingsStore
        ? ImageUploadSettings.loadFromStore(settingsStore)
        : ImageUploadSettings.load(context)
    ).catch((error: Error) => {
      console.error('restore image upload settings failed: ' + error.message)
      ImageUploadSettings.apply(ImageUploadSettings.defaultSnapshot())
    })
  }

  private static async restoreRecentStickers(context: common.UIAbilityContext): Promise<void> {
    await RecentStickerSettings.load(context).catch((error: Error) => {
      console.error('restore recent stickers failed: ' + error.message)
    })
  }

  private static async restoreIgnoredNodes(context: common.UIAbilityContext): Promise<void> {
    await IgnoredNodesSettings.load(context).catch((error: Error) => {
      console.error('restore ignored nodes failed: ' + error.message)
    })
  }

  private static async restoreNetworkProxy(
    context: common.UIAbilityContext,
    settingsStore?: SettingsPreferencesStore,
  ): Promise<void> {
    await (
      settingsStore
        ? NetworkProxySettings.loadFromStore(settingsStore)
        : NetworkProxySettings.load(context)
    ).catch((error: Error) => {
      console.error('restore network proxy settings failed: ' + error.message)
      NetworkProxySettings.apply(NetworkProxySettings.defaultSnapshot())
    })
  }

  private static async restoreReplyDisplay(
    context: common.UIAbilityContext,
    settingsStore?: SettingsPreferencesStore,
  ): Promise<void> {
    await (
      settingsStore
        ? ReplyDisplaySettings.loadFromStore(settingsStore)
        : ReplyDisplaySettings.load(context)
    ).catch((error: Error) => {
      console.error('restore reply display settings failed: ' + error.message)
      ReplyDisplaySettings.apply(ReplyDisplaySettings.MODE_THREAD)
    })
  }

  private static async restoreHotReplies(
    context: common.UIAbilityContext,
    settingsStore?: SettingsPreferencesStore,
  ): Promise<void> {
    await (
      settingsStore
        ? HotReplySettings.loadFromStore(settingsStore)
        : HotReplySettings.load(context)
    ).catch((error: Error) => {
      console.error('restore hot reply settings failed: ' + error.message)
      HotReplySettings.apply(
        HotReplySettings.DEFAULT_ENABLED,
        HotReplySettings.DEFAULT_MAX_COUNT,
        HotReplySettings.DEFAULT_MIN_THANKS,
        HotReplySettings.DEFAULT_CHILD_REPLIES_EXPANDED,
      )
    })
  }

  private static async restoreReading(
    context: common.UIAbilityContext,
    settingsStore?: SettingsPreferencesStore,
  ): Promise<void> {
    await (
      settingsStore ? ReadingSettings.loadFromStore(settingsStore) : ReadingSettings.load(context)
    ).catch((error: Error) => {
      console.error('restore reading settings failed: ' + error.message)
      ReadingSettings.apply(
        ReadingSettings.TEXT_SCALE_DEFAULT,
        20,
        ReadingSettings.DENSITY_STANDARD,
      )
    })
  }

  private static async restoreFeedTabs(context: common.UIAbilityContext): Promise<void> {
    await FeedTabSettings.load(context).catch((error: Error) => {
      console.error('restore feed tab settings failed: ' + error.message)
      FeedTabSettings.apply(FeedTabSettings.defaultKeysJson())
    })
  }

  private static async restoreHomeTabs(
    context: common.UIAbilityContext,
    settingsStore?: SettingsPreferencesStore,
  ): Promise<void> {
    await (
      settingsStore ? HomeTabSettings.loadFromStore(settingsStore) : HomeTabSettings.load(context)
    ).catch((error: Error) => {
      console.error('restore home tab settings failed: ' + error.message)
      HomeTabSettings.apply(HomeTabSettings.DEFAULT_AUTO_HIDE)
    })
  }

  private static async restoreTopicDetailReplyAction(
    context: common.UIAbilityContext,
    settingsStore?: SettingsPreferencesStore,
  ): Promise<void> {
    await (
      settingsStore
        ? TopicDetailReplyActionSettings.loadFromStore(settingsStore)
        : TopicDetailReplyActionSettings.load(context)
    ).catch((error: Error) => {
      console.error('restore topic detail reply action settings failed: ' + error.message)
      TopicDetailReplyActionSettings.apply(TopicDetailReplyActionSettings.DEFAULT_AUTO_HIDE)
    })
  }

  private static async restoreCookieJar(context: common.UIAbilityContext): Promise<void> {
    await CookieJarSettings.load(context).catch((error: Error) => {
      console.error('restore cookie jar failed: ' + error.message)
      CookieJarSettings.apply({
        cookiesByBaseUrl: {},
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

  private static async restoreBlockedLists(context: common.UIAbilityContext): Promise<void> {
    await BlockedListSettings.loadActive(context)
      .then((snapshot) => {
        BlockedListSettings.apply(snapshot)
      })
      .catch((error: Error) => {
        console.error('restore blocked lists failed: ' + error.message)
      })
  }

  private static async restoreAutoDailyCheckin(
    context: common.UIAbilityContext,
    settingsStore?: SettingsPreferencesStore,
  ): Promise<void> {
    await (
      settingsStore
        ? AutoDailyCheckinSettings.loadFromStore(settingsStore)
        : AutoDailyCheckinSettings.load(context)
    ).catch((error: Error) => {
      console.error('restore auto daily check-in setting failed: ' + error.message)
      AutoDailyCheckinSettings.apply(true)
    })
  }

  private static async restoreCloudSync(
    context: common.UIAbilityContext,
    settingsStore?: SettingsPreferencesStore,
  ): Promise<void> {
    await (
      settingsStore
        ? CloudSyncSettings.loadFromStore(settingsStore)
        : CloudSyncSettings.load(context)
    ).catch((error: Error) => {
      console.error('restore cloud sync setting failed: ' + error.message)
      CloudSyncSettings.apply(false)
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

  private static async restoreReplyCardStyle(
    context: common.UIAbilityContext,
    settingsStore?: SettingsPreferencesStore,
  ): Promise<void> {
    await (
      settingsStore
        ? ReplyCardStyleSettings.loadFromStore(settingsStore)
        : ReplyCardStyleSettings.load(context)
    ).catch((error: Error) => {
      console.error('restore reply card style failed: ' + error.message)
      ReplyCardStyleSettings.apply(ReplyCardStyleSettings.STYLE_STANDARD)
    })
  }

  private static async restoreReplyActionAlignment(
    context: common.UIAbilityContext,
    settingsStore?: SettingsPreferencesStore,
  ): Promise<void> {
    await (
      settingsStore
        ? ReplyActionAlignmentSettings.loadFromStore(settingsStore)
        : ReplyActionAlignmentSettings.load(context)
    ).catch((error: Error) => {
      console.error('restore reply action alignment failed: ' + error.message)
      ReplyActionAlignmentSettings.apply(ReplyActionAlignmentSettings.MODE_UNSET)
    })
  }
}
