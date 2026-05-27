import { StorageKeys } from '../constants/StorageKeys'
import { AvatarAppearanceSettings } from '../settings/AvatarAppearanceSettings'
import { ImageUtils } from '../utils/ImageUtils'

@Component
export struct Avatar {
  @Prop url: string = ''
  @Prop avatarSize: number = 48
  @Prop placeholder: string = ''
  @StorageProp(StorageKeys.AVATAR_APPEARANCE) private avatarAppearance: string = AvatarAppearanceSettings.APPEARANCE_CIRCLE

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
    return AvatarAppearanceSettings.radiusForSize(this.avatarSize, this.avatarAppearance)
  }

  private placeholderInitial(): string {
    const text = (this.placeholder || '').trim()
    if (!text) {
      return '•'
    }
    return text.substring(0, 1).toUpperCase()
  }
}
