import { common } from '@kit.AbilityKit'
import type { BackupPreferencesSection } from './BackupTypes'
import { ApiDomainSettings } from '../settings/ApiDomainSettings'
import { AutoDailyCheckinSettings } from '../settings/AutoDailyCheckinSettings'
import { AvatarAppearanceSettings } from '../settings/AvatarAppearanceSettings'
import { DiagnosticsSettings } from '../settings/DiagnosticsSettings'
import { FeedTabSettings } from '../settings/FeedTabSettings'
import { HomeTabSettings } from '../settings/HomeTabSettings'
import { TopicDetailReplyActionSettings } from '../settings/TopicDetailReplyActionSettings'
import { LanguageSettings } from '../settings/LanguageSettings'
import { MediaSettings } from '../settings/MediaSettings'
import { ReadingSettings } from '../settings/ReadingSettings'
import { ReplyActionAlignmentSettings } from '../settings/ReplyActionAlignmentSettings'
import { ReplyCardStyleSettings } from '../settings/ReplyCardStyleSettings'
import { ReplyDisplaySettings } from '../settings/ReplyDisplaySettings'
import { ThemeSettings } from '../settings/ThemeSettings'

export class BackupPreferencesAdapter {
  static async exportSection(context: common.UIAbilityContext): Promise<BackupPreferencesSection> {
    const language = await LanguageSettings.load(context)
    const theme = await ThemeSettings.load(context)
    const media = await MediaSettings.load(context)
    const reading = await ReadingSettings.load(context)
    const checkin = await AutoDailyCheckinSettings.load(context)
    const avatarAppearance = await AvatarAppearanceSettings.load(context)
    const homeTab = await HomeTabSettings.load(context)
    const replyAction = await TopicDetailReplyActionSettings.load(context)
    const diagnostics = await DiagnosticsSettings.load(context)
    return {
      apiDomain: { baseUrl: await ApiDomainSettings.load(context) },
      language: { mode: language.mode },
      theme: { mode: theme.mode },
      appearance: { avatarAppearance: avatarAppearance },
      media: {
        autoLoadImages: media.autoLoadImages,
        onlyLoadImagesOnWifi: media.onlyLoadImagesOnWifi,
      },
      reading: {
        textScale: reading.textScale,
        lineHeight: reading.lineHeight,
        density: reading.density,
        restorePosition: reading.restorePosition,
        base64DecodeMode: reading.base64DecodeMode,
      },
      reply: {
        displayMode: await ReplyDisplaySettings.load(context),
        cardStyle: await ReplyCardStyleSettings.load(context),
        actionAlignmentMode: await ReplyActionAlignmentSettings.load(context),
      },
      feedTabs: { visibleKeys: await FeedTabSettings.load(context) },
      autoDailyCheckin: { enabled: checkin.enabled },
      homeTab: { autoHide: homeTab.autoHide },
      topicDetailReplyAction: { autoHide: replyAction.autoHide },
      diagnostics: { enabled: diagnostics.enabled, minLevel: diagnostics.minLevel },
    }
  }

  static async restoreSection(
    context: common.UIAbilityContext,
    section: BackupPreferencesSection,
  ): Promise<void> {
    if (section.apiDomain && section.apiDomain.baseUrl) {
      await ApiDomainSettings.save(context, section.apiDomain.baseUrl)
    } else if (section.apiDomain && typeof section.apiDomain.useCoDomain === 'boolean') {
      await ApiDomainSettings.save(
        context,
        section.apiDomain.useCoDomain ? 'https://www.v2ex.co' : 'https://www.v2ex.com',
      )
    }
    if (section.language && section.language.mode) {
      await LanguageSettings.save(context, section.language.mode)
    }
    if (section.theme && section.theme.mode) {
      await ThemeSettings.save(context, section.theme.mode)
    }
    if (section.appearance) {
      await AvatarAppearanceSettings.save(
        context,
        section.appearance.avatarAppearance || AvatarAppearanceSettings.APPEARANCE_SOFT,
      )
    }
    if (section.media) {
      await MediaSettings.save(
        context,
        section.media.autoLoadImages === true,
        section.media.onlyLoadImagesOnWifi === true,
      )
    }
    if (section.reading) {
      await ReadingSettings.save(
        context,
        Number(section.reading.textScale || 1),
        Number(section.reading.lineHeight || 1.55),
        String(section.reading.density || 'comfortable'),
      )
      await ReadingSettings.saveRestorePosition(context, section.reading.restorePosition === true)
      await ReadingSettings.saveBase64DecodeMode(
        context,
        String(section.reading.base64DecodeMode || 'off'),
      )
    }
    if (section.reply) {
      await ReplyDisplaySettings.save(context, section.reply.displayMode || '')
      await ReplyCardStyleSettings.save(context, section.reply.cardStyle || '')
      await ReplyActionAlignmentSettings.save(context, section.reply.actionAlignmentMode || '')
    }
    if (section.feedTabs && section.feedTabs.visibleKeys) {
      await FeedTabSettings.save(context, section.feedTabs.visibleKeys)
    }
    if (section.autoDailyCheckin && typeof section.autoDailyCheckin.enabled === 'boolean') {
      await AutoDailyCheckinSettings.save(context, section.autoDailyCheckin.enabled)
    }
    if (section.homeTab && typeof section.homeTab.autoHide === 'boolean') {
      await HomeTabSettings.save(context, section.homeTab.autoHide)
    }
    if (
      section.topicDetailReplyAction &&
      typeof section.topicDetailReplyAction.autoHide === 'boolean'
    ) {
      await TopicDetailReplyActionSettings.save(context, section.topicDetailReplyAction.autoHide)
    }
    if (section.diagnostics && typeof section.diagnostics.enabled === 'boolean') {
      await DiagnosticsSettings.save(
        context,
        section.diagnostics.enabled,
        section.diagnostics.minLevel || DiagnosticsSettings.LEVEL_INFO,
      )
    }
  }

  static count(section: BackupPreferencesSection): number {
    return Object.keys(section).length
  }
}
