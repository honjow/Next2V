import { AppStorageV2 } from '@kit.ArkUI'

@ObservedV2
export class ImmersiveMaterialSettingsState {
  @Trace level: string = 'adaptive'
}

const IMMERSIVE_MATERIAL_SETTINGS_V2_KEY: string = 'v2:immersiveMaterialSettings'

export function connectImmersiveMaterialSettings(): ImmersiveMaterialSettingsState {
  return AppStorageV2.connect(
    ImmersiveMaterialSettingsState,
    IMMERSIVE_MATERIAL_SETTINGS_V2_KEY,
    () => new ImmersiveMaterialSettingsState(),
  )!
}
