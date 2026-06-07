import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import type { BackupPreferencesSection } from './BackupTypes'
import { BackupSecretDenylist } from './BackupSecretDenylist'
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
import { SettingsBootstrap } from '../settings/SettingsBootstrap'
import { STORE_NAME_SETTINGS } from '../settings/SettingsStorage'
import { ThemeColorSettings } from '../settings/ThemeColorSettings'
import { ThemeSettings } from '../settings/ThemeSettings'

type SettingsValue = string | number | boolean
type SettingsMap = Record<string, SettingsValue>

/**
 * Preferences (settings) backup adapter — plaintext path, credential-free per the secret-exclusion
 * contract.
 *
 * Export dumps the ENTIRE unified `next2v_settings` store (minus the secret/runtime denylist) so any
 * setting persisted there is backed up automatically; feed-tab visibility lives in its own store and
 * is carried as a typed field. Import writes the dump back, then re-hydrates AppStorage / live state
 * so changes apply without a restart. Backups created before the whole-store dump are restored via
 * the legacy per-field path.
 */
export class BackupPreferencesAdapter {
  static async exportSection(context: common.UIAbilityContext): Promise<BackupPreferencesSection> {
    const settings = await BackupPreferencesAdapter.dumpSettingsStore(context)
    const feedTabs = await FeedTabSettings.load(context)
    return {
      settings: settings,
      feedTabs: { visibleKeys: feedTabs },
    }
  }

  // Read every key in the unified store and keep the JSON-safe scalars that are not denylisted.
  private static async dumpSettingsStore(context: common.UIAbilityContext): Promise<SettingsMap> {
    const result: SettingsMap = JSON.parse('{}') as SettingsMap
    const store = await preferences.getPreferences(context, STORE_NAME_SETTINGS)
    const all = store.getAllSync() as Record<string, preferences.ValueType>
    const keys = Object.keys(all)
    for (const key of keys) {
      if (BackupSecretDenylist.isExcluded(key)) {
        continue
      }
      const value = all[key]
      // next2v_settings only ever stores string/number/boolean (composite settings are JSON
      // strings). Skip anything else so the dump stays JSON-clean.
      if (typeof value === 'string' || typeof value === 'number' || typeof value === 'boolean') {
        result[key] = value
      }
    }
    return result
  }

  static async restoreSection(
    context: common.UIAbilityContext,
    section: BackupPreferencesSection,
  ): Promise<void> {
    // feedTabs lives in its own store and is carried as a typed field by both new and legacy
    // backups, so restore it the same way regardless of which path the rest takes.
    if (section.feedTabs && section.feedTabs.visibleKeys) {
      await FeedTabSettings.save(context, section.feedTabs.visibleKeys)
    }
    if (section.settings) {
      await BackupPreferencesAdapter.restoreSettingsStore(context, section.settings)
    } else {
      await BackupPreferencesAdapter.restoreLegacyTypedSection(context, section)
    }
    // Re-apply the freshly written store into AppStorage / state holders so theme, language, reading
    // density, etc. take effect immediately instead of only after the next launch.
    await SettingsBootstrap.reapplyFromStore(context)
  }

  // Whole-store restore: write back every backed-up key, re-checking the denylist so a tampered
  // backup can never smuggle a credential key into the store. Additive (does not delete keys absent
  // from the backup), matching the rest of the import's overwrite-what-is-present semantics.
  private static async restoreSettingsStore(
    context: common.UIAbilityContext,
    settings: SettingsMap,
  ): Promise<void> {
    const store = await preferences.getPreferences(context, STORE_NAME_SETTINGS)
    const keys = Object.keys(settings)
    for (const key of keys) {
      if (BackupSecretDenylist.isExcluded(key)) {
        continue
      }
      store.putSync(key, settings[key])
    }
    store.flushSync()
  }

  // Legacy import path for backups created before the whole-store dump (typed per-setting fields).
  private static async restoreLegacyTypedSection(
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
    if (section.theme) {
      if (section.theme.mode) {
        await ThemeSettings.save(context, section.theme.mode)
      }
      if (section.theme.color) {
        await ThemeColorSettings.save(context, section.theme.color)
      }
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
    if (section.settings) {
      return Object.keys(section.settings).length + (section.feedTabs ? 1 : 0)
    }
    return Object.keys(section).length
  }
}
