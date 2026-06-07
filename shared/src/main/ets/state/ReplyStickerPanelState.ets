import { AppStorageV2 } from '@kit.ArkUI'

/**
 * Bridges the reply composer's sticker-panel open state to the nav-shell back handler. The panel lives
 * inside ReplyComposerBar (deep in TopicDetailPage), but the system back press is intercepted at the
 * HdsNavDestination (Index). So the composer publishes `open`, and Index's onBackPressed reads it: if the
 * panel is open it sets `open = false` (the composer reacts via @Monitor and hides the panel) and consumes
 * the back press, instead of popping the whole topic page. Single-writer-ish: the composer owns true/false
 * during normal use; the back handler only ever flips it to false.
 */
@ObservedV2
export class ReplyStickerPanelState {
  @Trace open: boolean = false
}

const REPLY_STICKER_PANEL_KEY: string = 'v2:replyStickerPanel'

export function connectReplyStickerPanel(): ReplyStickerPanelState {
  return AppStorageV2.connect(
    ReplyStickerPanelState,
    REPLY_STICKER_PANEL_KEY,
    () => new ReplyStickerPanelState(),
  )!
}
