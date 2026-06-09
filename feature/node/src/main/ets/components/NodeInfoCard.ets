import { common, Want } from '@kit.AbilityKit'
import {
  AppStrings,
  Avatar,
  CollectionSettings,
  MediaUrlUtils,
  NodeHeaderHtml,
  NodeHeaderRun,
  ThemeConstants,
  V2exNode,
} from 'shared'

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
  // Optional override for header link taps; when unset the URL opens externally via the system.
  @Event onHeaderLinkClick?: (url: string) => void;

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
              AppStrings.format(AppStrings.text($r('app.string.node_topics_count'), '{0} topics'), [
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

      if (this.headerRuns().length > 0) {
        Text() {
          ForEach(
            this.headerRuns(),
            (run: NodeHeaderRun, index: number) => {
              Span(run.text)
                .fontSize(ThemeConstants.FONT_SIZE_BODY)
                .fontWeight(run.bold ? FontWeight.Bold : FontWeight.Normal)
                .fontStyle(run.italic ? FontStyle.Italic : FontStyle.Normal)
                .fontFamily(run.mono ? 'Noto Sans Mono' : 'HarmonyOS Sans')
                .fontColor(
                  run.href.length > 0 ? ThemeConstants.TEXT_LINK : $r('sys.color.font_primary'),
                )
                .decoration(
                  run.href.length > 0
                    ? { type: TextDecorationType.Underline, color: ThemeConstants.TEXT_LINK }
                    : { type: TextDecorationType.None },
                )
                .textBackgroundStyle(
                  run.mono
                    ? { color: ThemeConstants.BG_SUB, radius: ThemeConstants.RADIUS_SM }
                    : { color: Color.Transparent, radius: 0 },
                )
                .onClick(() => {
                  this.openHeaderLink(run.href)
                })
            },
            (run: NodeHeaderRun, index: number) => `${index}-${run.href}-${run.text}`,
          )
        }
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

  private headerRuns(): NodeHeaderRun[] {
    return NodeHeaderHtml.parse(this.detail?.header || '')
  }

  private openHeaderLink(href: string): void {
    const url = (href || '').trim()
    if (url.length === 0) {
      return
    }
    const normalized = MediaUrlUtils.normalizeUrl(url)
    if (!normalized) {
      return
    }
    if (this.onHeaderLinkClick) {
      this.onHeaderLinkClick(normalized)
      return
    }
    // Default: hand the link to the system (browser / matching app), mirroring how reply content
    // links open when no in-app handler is provided.
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext
      const want: Want = { action: 'ohos.want.action.viewData', uri: normalized }
      context.startAbility(want).catch((_error: Error) => {})
    } catch (_error) {
      // Opening an external link is best-effort; ignore failures.
    }
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
