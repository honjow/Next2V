import {
  DateUtils,
  ReadingSettings,
  ReplyActionAlignmentSettings,
  ReplyCardStyleSettings,
  ReplyDisplaySettings,
  ThemeSettings,
  type CacheStats,
} from 'shared'

export interface SettingsOption {
  label: string
  value: string
}

export class SettingsPageCoordinator {
  static readonly MENU_OPEN_DELAY_MS: number = 20

  static themeModeOptions(): SettingsOption[] {
    return [
      { label: '自动', value: ThemeSettings.MODE_AUTO },
      { label: '浅色', value: ThemeSettings.MODE_LIGHT },
      { label: '深色', value: ThemeSettings.MODE_DARK },
    ]
  }

  static replyDisplayModeOptions(): SettingsOption[] {
    return [
      { label: '楼中楼', value: ReplyDisplaySettings.MODE_THREAD },
      { label: '楼中楼(@)', value: ReplyDisplaySettings.MODE_THREAD_WITH_MENTION },
      { label: '冗余楼中楼', value: ReplyDisplaySettings.MODE_THREAD_REDUNDANT },
      { label: '只看楼主', value: ReplyDisplaySettings.MODE_OP },
      { label: '原版', value: ReplyDisplaySettings.MODE_ORIGIN },
    ]
  }

  static replyCardStyleOptions(): SettingsOption[] {
    return [
      { label: '标准', value: ReplyCardStyleSettings.STYLE_STANDARD },
      { label: '紧凑', value: ReplyCardStyleSettings.STYLE_COMPACT },
    ]
  }

  static replyActionAlignmentOptions(motionHoldingHandSupported: boolean): SettingsOption[] {
    const options: SettingsOption[] = []
    if (motionHoldingHandSupported) {
      options.push({
        label: '智感握姿',
        value: ReplyActionAlignmentSettings.MODE_SMART_GRIP,
      })
    }
    options.push(
      {
        label: '跟随操作',
        value: ReplyActionAlignmentSettings.MODE_FOLLOW_OPERATION,
      },
      { label: '固定左侧', value: ReplyActionAlignmentSettings.MODE_FIXED_LEFT },
      { label: '固定右侧', value: ReplyActionAlignmentSettings.MODE_FIXED_RIGHT },
    )
    return options
  }

  static base64DecodeModeOptions(): SettingsOption[] {
    return [
      { label: '关闭', value: ReadingSettings.BASE64_MODE_OFF },
      { label: '点击查看', value: ReadingSettings.BASE64_MODE_BADGE },
      { label: '文内显示', value: ReadingSettings.BASE64_MODE_INLINE },
    ]
  }

  static apiDomainOptions(): SettingsOption[] {
    return [
      { label: 'v2ex.com', value: 'false' },
      { label: 'v2ex.co', value: 'true' },
    ]
  }

  static base64DecodeModeLabel(mode: string): string {
    if (mode === ReadingSettings.BASE64_MODE_OFF) {
      return '关闭'
    }
    if (mode === ReadingSettings.BASE64_MODE_INLINE) {
      return '文内显示'
    }
    return '点击查看'
  }

  static apiDomainLabel(useCoDomain: boolean): string {
    return useCoDomain ? 'v2ex.co' : 'v2ex.com'
  }

  static cacheSubtitle(stats: CacheStats): string {
    let text = `列表 ${stats.topicListCount} 组 · 详情 ${stats.topicDetailCount} 篇`
    if (stats.updatedAt > 0) {
      text += ` · 更新于 ${DateUtils.toDateString(stats.updatedAt)}`
    }
    return text
  }
}
