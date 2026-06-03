import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { STORE_NAME_SETTINGS, SettingsPreferencesStore } from './SettingsStorage'
import { connectImageUpload } from '../state/ImageUploadState'

const STORE_NAME: string = STORE_NAME_SETTINGS
const KEY_PROVIDER: string = 'imageUploadProvider'
const KEY_IMGUR_CLIENT_ID: string = 'imgurClientId'

export type ImageUploadProviderId = 'imgur' | 'v2ex'

export interface ImageUploadSettingsSnapshot {
  provider: ImageUploadProviderId
  imgurClientId: string
}

/**
 * Image-upload configuration, persisted in the unified `next2v_settings` store (so it rides the
 * whole-store backup). The anonymous Imgur Client-ID is a semi-public client-side identifier, so it is
 * deliberately left in the plaintext backup: its key name `imgurClientId` contains no
 * `token/secret/password/...` substring, so BackupSecretDenylist does NOT exclude it. If an OAuth access
 * token is ever added, name it `imgurAccessToken` so the existing `token` substring excludes it.
 *
 * `apply()` is the single writer of the `ImageUploadState` V2 mirror (no V1 AppStorage half — this is a
 * new setting with no V1 `@StorageLink` readers).
 */
export class ImageUploadSettings {
  static readonly PROVIDER_IMGUR: ImageUploadProviderId = 'imgur'
  static readonly PROVIDER_V2EX: ImageUploadProviderId = 'v2ex'

  static defaultSnapshot(): ImageUploadSettingsSnapshot {
    return { provider: 'imgur', imgurClientId: '' }
  }

  static apply(snapshot: ImageUploadSettingsSnapshot): void {
    const normalized = ImageUploadSettings.normalize(snapshot)
    const state = connectImageUpload()
    state.provider = normalized.provider
    state.imgurClientId = normalized.imgurClientId
  }

  /** The live config, read from the V2 mirror that apply() keeps in lockstep with the persisted keys. */
  static current(): ImageUploadSettingsSnapshot {
    const state = connectImageUpload()
    return ImageUploadSettings.normalize({
      provider: (state.provider || 'imgur') as ImageUploadProviderId,
      imgurClientId: state.imgurClientId || '',
    })
  }

  static normalize(snapshot: ImageUploadSettingsSnapshot): ImageUploadSettingsSnapshot {
    const provider: ImageUploadProviderId = snapshot.provider === 'v2ex' ? 'v2ex' : 'imgur'
    return { provider: provider, imgurClientId: (snapshot.imgurClientId || '').trim() }
  }

  static async load(context: common.UIAbilityContext): Promise<ImageUploadSettingsSnapshot> {
    const store = await preferences.getPreferences(context, STORE_NAME)
    return ImageUploadSettings.loadFromStore(store)
  }

  static async loadFromStore(store: SettingsPreferencesStore): Promise<ImageUploadSettingsSnapshot> {
    const provider = store.getSync(KEY_PROVIDER, 'imgur') as string
    const imgurClientId = store.getSync(KEY_IMGUR_CLIENT_ID, '') as string
    const snapshot = ImageUploadSettings.normalize({
      provider: provider as ImageUploadProviderId,
      imgurClientId: imgurClientId,
    })
    ImageUploadSettings.apply(snapshot)
    return snapshot
  }

  static async save(context: common.UIAbilityContext, snapshot: ImageUploadSettingsSnapshot): Promise<ImageUploadSettingsSnapshot> {
    const normalized = ImageUploadSettings.normalize(snapshot)
    ImageUploadSettings.apply(normalized)
    const store = await preferences.getPreferences(context, STORE_NAME)
    store.putSync(KEY_PROVIDER, normalized.provider)
    store.putSync(KEY_IMGUR_CLIENT_ID, normalized.imgurClientId)
    store.flushSync()
    return normalized
  }
}
