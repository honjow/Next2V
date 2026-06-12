import { AppStorageV2 } from '@kit.ArkUI'

@ObservedV2
export class HotReplySettingsState {
  @Trace enabled: boolean = true
  @Trace maxCount: number = 5
  @Trace minThanks: number = 3
  @Trace childRepliesExpanded: boolean = false
}

const HOT_REPLY_SETTINGS_V2_KEY: string = 'v2:hotReplySettings'

export function connectHotReplySettings(): HotReplySettingsState {
  return AppStorageV2.connect(
    HotReplySettingsState,
    HOT_REPLY_SETTINGS_V2_KEY,
    () => new HotReplySettingsState(),
  )!
}
