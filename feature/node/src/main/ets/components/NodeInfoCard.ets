import { AppStrings, Avatar, CollectionSettings, ThemeConstants, V2exNode } from 'shared'

/**
 * Node header card shown as the first list item on NodeTopicPage. Mirrors the user-profile card
 * (icon + name + meta) and reports its name Text's bottom global Y up via onNodeNameAreaChange so the
 * page can fade the title bar in once the name scrolls under the overlaid app bar.
 *
 * V2EX's node JSON optionally carries a `header` (a short description); it is only rendered when present
 * so login-gated/empty nodes fall back to icon + name + topic count.
 */
@ComponentV2
export struct NodeInfoCard {
  @Param detail: V2exNode | null = null;
  @Param fallbackName: string = '';
  @Param fallbackTitle: string = '';
  @Event onNodeNameAreaChange?: (bottom: number) => void;

  build() {
    Column({ space: ThemeConstants.SPACE_MD }) {
      Row({ space: ThemeConstants.SPACE_MD }) {
        Avatar({
          url: this.avatarUrl(),
          avatarSize: 64,
          placeholder: this.displayName(),
        })
        Column({ space: ThemeConstants.SPACE_XS }) {
          Text(this.displayName())
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .onAreaChange((_oldValue: Area, newValue: Area) => {
              if (this.onNodeNameAreaChange) {
                this.onNodeNameAreaChange(
                  this.areaY(newValue?.globalPosition?.y) + this.areaY(newValue?.height),
                )
              }
            })
          if (this.topicCount() > 0) {
            Text(
              AppStrings.format(AppStrings.text(AppStrings.R_NODE_TOPICS_COUNT, '{0} topics'), [
                String(this.topicCount()),
              ]),
            )
              .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
              .fontColor($r('sys.color.font_secondary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      if (this.headerText()) {
        Text(this.headerText())
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .fontColor($r('sys.color.font_primary'))
          .lineHeight(ThemeConstants.LINE_HEIGHT_BODY + 2)
          .width('100%')
      }
    }
    .padding(ThemeConstants.SPACE_LG)
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .borderRadius(ThemeConstants.RADIUS_MD)
    .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
  }

  private avatarUrl(): string {
    return (this.detail?.avatar_large || this.detail?.avatar_normal || '').trim()
  }

  private displayName(): string {
    const raw =
      this.detail?.title || this.fallbackTitle || this.detail?.name || this.fallbackName || ''
    return CollectionSettings.cleanNodeTitle(raw.trim(), this.topicCount())
  }

  private topicCount(): number {
    return this.detail?.topics || 0
  }

  private headerText(): string {
    return (this.detail?.header || '').trim()
  }

  private areaY(value: Length | undefined): number {
    if (typeof value === 'number') {
      return value
    }
    if (typeof value === 'string') {
      const parsed = Number.parseFloat(value)
      return Number.isNaN(parsed) ? 0 : parsed
    }
    return 0
  }
}
