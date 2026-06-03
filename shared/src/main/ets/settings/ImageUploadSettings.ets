import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { STORE_NAME_SETTINGS, SettingsPreferencesStore } from './SettingsStorage'
import { connectImageUpload } from '../state/ImageUploadState'

const STORE_NAME: string = STORE_NAME_SETTINGS
const KEY_PROVIDER: string = 'imageUploadProvider'
const KEY_IMGBB_API_KEY: string = 'imgbbApiKey'
const KEY_SMMS_TOKEN: string = 'smmsToken'
const KEY_IMGUR_CLIENT_ID: string = 'imgurClientId'

export type ImageUploadProviderId = 'imgbb' | 'smms' | 'imgur'

export interface ImageUploadSettingsSnapshot {
  provider: ImageUploadProviderId
  imgbbApiKey: string
  smmsToken: string
  imgurClientId: string
}

/**
 * Image-upload configuration, persisted in the unified `next2v_settings` store (so it rides the
 * whole-store backup). Each host's credential (ImgBB API key / sm.ms token / Imgur Client-ID) is an
 * end-user-owned, semi-public API identifier, so they deliberately ride the plaintext backup: none of the
 * key names contain a `token/secret/password/...` substring that BackupSecretDenylist excludes — EXCEPT
 * `smmsToken`, which DOES contain `token` and is therefore excluded from the backup by design (a sm.ms
 * token is account-scoped and grants gallery management, so keeping it out of an exported plaintext file is
 * the safer default; the user re-enters it after a restore).
 *
 * `apply()` is the single writer of the `ImageUploadState` V2 mirror (no V1 AppStorage half — this is a
 * new setting with no V1 `@StorageLink` readers).
 */
export class ImageUploadSettings {
  static readonly PROVIDER_IMGBB: ImageUploadProviderId = 'imgbb'
  static readonly PROVIDER_SMMS: ImageUploadProviderId = 'smms'
  static readonly PROVIDER_IMGUR: ImageUploadProviderId = 'imgur'

  static defaultSnapshot(): ImageUploadSettingsSnapshot {
    return { provider: 'imgbb', imgbbApiKey: '', smmsToken: '', imgurClientId: '' }
  }

  static apply(snapshot: ImageUploadSettingsSnapshot): void {
    const normalized = ImageUploadSettings.normalize(snapshot)
    const state = connectImageUpload()
    state.provider = normalized.provider
    state.imgbbApiKey = normalized.imgbbApiKey
    state.smmsToken = normalized.smmsToken
    state.imgurClientId = normalized.imgurClientId
  }

  /** The live config, read from the V2 mirror that apply() keeps in lockstep with the persisted keys. */
  static current(): ImageUploadSettingsSnapshot {
    const state = connectImageUpload()
    return ImageUploadSettings.normalize({
      provider: (state.provider || 'imgbb') as ImageUploadProviderId,
      imgbbApiKey: state.imgbbApiKey || '',
      smmsToken: state.smmsToken || '',
      imgurClientId: state.imgurClientId || '',
    })
  }

  static normalize(snapshot: ImageUploadSettingsSnapshot): ImageUploadSettingsSnapshot {
    return {
      provider: ImageUploadSettings.normalizeProvider(snapshot.provider),
      imgbbApiKey: (snapshot.imgbbApiKey || '').trim(),
      smmsToken: (snapshot.smmsToken || '').trim(),
      imgurClientId: (snapshot.imgurClientId || '').trim(),
    }
  }

  static normalizeProvider(provider: string): ImageUploadProviderId {
    if (provider === 'smms') {
      return 'smms'
    }
    if (provider === 'imgur') {
      return 'imgur'
    }
    return 'imgbb'
  }

  /** The credential string for a given provider in the snapshot. */
  static credentialFor(snapshot: ImageUploadSettingsSnapshot, provider: ImageUploadProviderId): string {
    if (provider === 'smms') {
      return snapshot.smmsToken
    }
    if (provider === 'imgur') {
      return snapshot.imgurClientId
    }
    return snapshot.imgbbApiKey
  }

  /** Whether the snapshot's ACTIVE provider has its credential set (gates the editor's upload action). */
  static isConfigured(snapshot: ImageUploadSettingsSnapshot): boolean {
    const normalized = ImageUploadSettings.normalize(snapshot)
    return ImageUploadSettings.credentialFor(normalized, normalized.provider).length > 0
  }

  static async load(context: common.UIAbilityContext): Promise<ImageUploadSettingsSnapshot> {
    const store = await preferences.getPreferences(context, STORE_NAME)
    return ImageUploadSettings.loadFromStore(store)
  }

  static async loadFromStore(store: SettingsPreferencesStore): Promise<ImageUploadSettingsSnapshot> {
    const provider = store.getSync(KEY_PROVIDER, 'imgbb') as string
    const imgbbApiKey = store.getSync(KEY_IMGBB_API_KEY, '') as string
    const smmsToken = store.getSync(KEY_SMMS_TOKEN, '') as string
    const imgurClientId = store.getSync(KEY_IMGUR_CLIENT_ID, '') as string
    const snapshot = ImageUploadSettings.normalize({
      provider: provider as ImageUploadProviderId,
      imgbbApiKey: imgbbApiKey,
      smmsToken: smmsToken,
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
    store.putSync(KEY_IMGBB_API_KEY, normalized.imgbbApiKey)
    store.putSync(KEY_SMMS_TOKEN, normalized.smmsToken)
    store.putSync(KEY_IMGUR_CLIENT_ID, normalized.imgurClientId)
    store.flushSync()
    return normalized
  }
}
