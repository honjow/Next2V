import { ImageUtils } from '../utils/ImageUtils'

@Component
export struct Avatar {
  @Prop url: string = ''
  @Prop avatarSize: number = 48

  build() {
    Image(ImageUtils.avatarUrl(this.url))
      .objectFit(ImageFit.Cover)
      .width(this.avatarSize)
      .height(this.avatarSize)
      .borderRadius(this.avatarSize / 2)
      .backgroundColor('#E8E8E8')
  }
}
