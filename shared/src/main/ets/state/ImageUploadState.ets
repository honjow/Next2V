import { AppStorageV2 } from '@kit.ArkUI'

/**
 * V2 mirror of the image-upload configuration. `ImageUploadSettings.apply()` is the single imperative
 * writer; it dual-writes these `@Trace` fields so the `@ComponentV2` settings page (live config view),
 * the `SettingsPage` summary row, and the upload provider (which reads `imgurClientId` at upload time)
 * all stay in lockstep with the persisted `next2v_settings` keys.
 *
 * There is intentionally NO V1 AppStorage half: this setting is new, so nothing reads it via a V1
 * `@StorageLink`. The mirror is the only live channel.
 */
@ObservedV2
export class ImageUploadState {
  @Trace provider: string = 'imgur'
  @Trace imgurClientId: string = ''
}

const IMAGE_UPLOAD_V2_KEY: string = 'v2:imageUpload'

/** Returns the app-wide ImageUploadState singleton from AppStorageV2. */
export function connectImageUpload(): ImageUploadState {
  return AppStorageV2.connect(ImageUploadState, IMAGE_UPLOAD_V2_KEY, () => new ImageUploadState())!
}
