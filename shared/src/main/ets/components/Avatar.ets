import { AvatarAppearanceSettings } from '../settings/AvatarAppearanceSettings'
import { connectAvatarAppearance, AvatarAppearanceState } from '../state/AvatarAppearanceState'
import { ImageUtils } from '../utils/ImageUtils'

@ComponentV2
export struct Avatar {
  @Param url: string = ''
  @Param avatarSize: number = 48
  @Param placeholder: string = ''
  // Avatar appearance mirrored into AppStorageV2 by AvatarAppearanceSettings.apply()
  // (was @StorageProp(StorageKeys.AVATAR_APPEARANCE)); reading the @Trace field keeps
  // the shape reactive to the settings dropdown.
  private appearanceState: AvatarAppearanceState = connectAvatarAppearance()

  build() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.url) {
        Image(ImageUtils.avatarUrl(this.url))
          .objectFit(ImageFit.Cover)
          .width(this.avatarSize)
          .height(this.avatarSize)
          .borderRadius(this.avatarRadius())
      } else {
        Text(this.placeholderInitial())
          .fontSize(Math.max(11, this.avatarSize / 3))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_secondary'))
      }
    }
    .width(this.avatarSize)
    .height(this.avatarSize)
    .borderRadius(this.avatarRadius())
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }

  private avatarRadius(): number {
    return AvatarAppearanceSettings.radiusForSize(this.avatarSize, this.appearanceState.appearance)
  }

  private placeholderInitial(): string {
    const text = (this.placeholder || '').trim()
    if (!text) {
      return '•'
    }
    return text.substring(0, 1).toUpperCase()
  }
}
