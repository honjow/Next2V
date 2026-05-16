import { common } from '@kit.AbilityKit'
import { ApiDomainSettings } from './ApiDomainSettings'
import { AutoDailyCheckinSettings } from './AutoDailyCheckinSettings'
import { CookieJarSettings } from './CookieJarSettings'
import { FeedTabSettings } from './FeedTabSettings'
import { MediaSettings } from './MediaSettings'
import { ReadingSettings } from './ReadingSettings'
import { ReplyActionAlignmentSettings } from './ReplyActionAlignmentSettings'
import { ReplyCardStyleSettings } from './ReplyCardStyleSettings'
import { ReplyDisplaySettings } from './ReplyDisplaySettings'
import { ThemeSettings } from './ThemeSettings'
import { AutoDailyCheckinService } from '../services/AutoDailyCheckinService'

export class SettingsBootstrap {
  static async loadAll(context: common.UIAbilityContext): Promise<void> {
    await SettingsBootstrap.restoreApiDomain(context)
    await SettingsBootstrap.restoreTheme(context)
    await SettingsBootstrap.restoreMedia(context)
    await SettingsBootstrap.restoreReplyDisplay(context)
    await SettingsBootstrap.restoreReading(context)
    await SettingsBootstrap.restoreFeedTabs(context)
    await SettingsBootstrap.restoreCookieJar(context)
    await SettingsBootstrap.restoreAutoDailyCheckin(context)
    SettingsBootstrap.triggerStartupCheckin(context)
    await SettingsBootstrap.restoreReplyCardStyle(context)
    await SettingsBootstrap.restoreReplyActionAlignment(context)
  }

  private static async restoreApiDomain(context: common.UIAbilityContext): Promise<void> {
    await ApiDomainSettings.load(context).catch((error: Error) => {
      console.error('restore api domain failed: ' + error.message)
      ApiDomainSettings.apply(false)
    })
  }

  private static async restoreTheme(context: common.UIAbilityContext): Promise<void> {
    await ThemeSettings.load(context).catch((error: Error) => {
      console.error('restore theme settings failed: ' + error.message)
      ThemeSettings.apply(context, ThemeSettings.MODE_AUTO)
    })
  }

  private static async restoreMedia(context: common.UIAbilityContext): Promise<void> {
    await MediaSettings.load(context).catch((error: Error) => {
      console.error('restore media settings failed: ' + error.message)
      MediaSettings.apply(true, false)
    })
  }

  private static async restoreReplyDisplay(context: common.UIAbilityContext): Promise<void> {
    await ReplyDisplaySettings.load(context).catch((error: Error) => {
      console.error('restore reply display settings failed: ' + error.message)
      ReplyDisplaySettings.apply(ReplyDisplaySettings.MODE_THREAD)
    })
  }

  private static async restoreReading(context: common.UIAbilityContext): Promise<void> {
    await ReadingSettings.load(context).catch((error: Error) => {
      console.error('restore reading settings failed: ' + error.message)
      ReadingSettings.apply(14, 20, ReadingSettings.DENSITY_STANDARD)
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

  private static async restoreAutoDailyCheckin(context: common.UIAbilityContext): Promise<void> {
    await AutoDailyCheckinSettings.load(context).catch((error: Error) => {
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

  private static async restoreReplyCardStyle(context: common.UIAbilityContext): Promise<void> {
    await ReplyCardStyleSettings.load(context).catch((error: Error) => {
      console.error('restore reply card style failed: ' + error.message)
      ReplyCardStyleSettings.apply(ReplyCardStyleSettings.STYLE_STANDARD)
    })
  }

  private static async restoreReplyActionAlignment(context: common.UIAbilityContext): Promise<void> {
    await ReplyActionAlignmentSettings.load(context).catch((error: Error) => {
      console.error('restore reply action alignment failed: ' + error.message)
      ReplyActionAlignmentSettings.apply(ReplyActionAlignmentSettings.MODE_UNSET)
    })
  }
}
