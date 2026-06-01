import { AppStorageV2 } from '@kit.ArkUI'

/**
 * V2 command bus for the image-preview appbar (`'v2:imagePreviewAction'`).
 *
 * The command is a one-directional bus: the `@ComponentV2` `Index.ets` title-bar "save" action writes a
 * `<token>:<action>` string (`Index.sendImagePreviewAction`, the single writer), and
 * `ImagePreviewPage` reacts to run the matching action. There is no writeback.
 *
 * A `@ComponentV2` consumer holds the singleton and runs the action via
 * `@Monitor('<member>.command')` when it changes. The legacy V1 `AppStorage` (`imagePreviewAction`)
 * key + its dual-write were retired once no reader read the V1 half.
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
