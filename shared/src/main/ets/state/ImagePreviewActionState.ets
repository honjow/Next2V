import { AppStorageV2 } from '@kit.ArkUI'

/**
 * V2 mirror of the image-preview appbar command (`StorageKeys.IMAGE_PREVIEW_ACTION`).
 *
 * The command is a one-directional bus: the V1 `Index.ets` title-bar "save" action writes a
 * `<token>:<action>` string (`Index.sendImagePreviewAction`, the single writer), and
 * `ImagePreviewPage` reacts to run the matching action. There is no writeback. During the
 * State Management V1->V2 migration the command lives in BOTH stores at once: nothing else
 * reads the V1 key today, but the writer dual-writes the V1 `AppStorage` key AND this
 * `@Trace` field so the bridge stays uniform and reversible.
 *
 * A `@ComponentV2` consumer holds the singleton and runs the action via
 * `@Monitor('<member>.command')` when it changes.
 *
 * Transitional: drop the `AppStorage` half once the writer no longer needs it.
 */
@ObservedV2
export class ImagePreviewActionState {
  @Trace command: string = ''
}

const IMAGE_PREVIEW_ACTION_V2_KEY: string = 'v2:imagePreviewAction'

/** Returns the app-wide ImagePreviewActionState singleton from AppStorageV2. */
export function connectImagePreviewAction(): ImagePreviewActionState {
  return AppStorageV2.connect(ImagePreviewActionState, IMAGE_PREVIEW_ACTION_V2_KEY, () => new ImagePreviewActionState())!
}
