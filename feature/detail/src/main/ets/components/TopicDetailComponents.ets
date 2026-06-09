import {
  AppModalScaffold,
  AppStrings,
  Avatar,
  ImageUtils,
  ThemeConstants,
  TimeAgo,
  UserName,
  V2exReply,
  V2exTopic,
} from 'shared'
import {
  TopicDetailReplyDisplayCoordinator,
  type ReplyDisplayModeOption,
} from '../model/TopicDetailReplyDisplayCoordinator'
import { SymbolGlyphModifier } from '@kit.ArkUI'

@ComponentV2
export struct TopicDetailHeader {
  @Require @Param topic: V2exTopic
  @Event onUserClick?: () => void
  @Event onNodeClick?: () => void
  @Event onTitleAreaChange?: (oldValue: Area, newValue: Area) => void

  build() {
    Column() {
      Row({ space: ThemeConstants.SPACE_SM }) {
        Avatar({
          url: ImageUtils.memberAvatarUrl(this.topic.member),
          avatarSize: ThemeConstants.AVATAR_SIZE_REPLY,
        })
          .onClick(() => {
            if (this.onUserClick) {
              this.onUserClick()
            }
          })
        UserName({
          username: this.topic.member.username,
          fontSize: ThemeConstants.FONT_SIZE_META,
          fontWeight: FontWeight.Medium,
          isPro: (this.topic.member.pro || 0) > 0,
          isMod: (this.topic.member.mod || 0) > 0,
          markMaxWidth: 76,
          onUserClick: () => {
            if (this.onUserClick) {
              this.onUserClick()
            }
          },
        })
          .flexShrink(1)
        Text('·')
          .fontSize(ThemeConstants.FONT_SIZE_META)
          .fontColor($r('sys.color.font_secondary'))
        TimeAgo({ timestamp: this.topic.created })
        Blank()
        Text(this.topic.node.title)
          .fontSize(ThemeConstants.FONT_SIZE_TAG)
          .fontColor($r('sys.color.font_secondary'))
          .padding({
            left: ThemeConstants.SPACE_SM,
            right: ThemeConstants.SPACE_SM,
            top: 2,
            bottom: 2,
          })
          .borderRadius(ThemeConstants.RADIUS_SM)
          .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
          .onClick(() => {
            if (this.onNodeClick) {
              this.onNodeClick()
            }
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      Text(this.topic.title)
        .fontSize(ThemeConstants.FONT_SIZE_HEADING)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
        .lineHeight(28)
        .width('100%')
        .margin({ top: ThemeConstants.SPACE_MD })
        .onAreaChange((oldValue: Area, newValue: Area) => {
          if (this.onTitleAreaChange) {
            this.onTitleAreaChange(oldValue, newValue)
          }
        })
    }
    .width('100%')
  }
}

@ComponentV2
export struct TopicRepliesPreloadIndicator {
  @Param text: string = ''

  build() {
    Row({ space: ThemeConstants.SPACE_SM }) {
      LoadingProgress()
        .width(20)
        .height(20)
      Text(this.text)
        .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
        .fontColor($r('sys.color.font_secondary'))
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .padding(ThemeConstants.SPACE_MD)
  }
}

@ComponentV2
export struct TopicDetailReplyDivider {
  // Two-way menu-visibility lives in the V1 parent (TopicDetailPage). Under V2 the value
  // flows down as @Param and the child writes the dismissal back up through @Event
  // (the V2 replacement for the former @Link).
  @Param replyDisplayMenuShown: boolean = false
  @Event onReplyDisplayMenuShownChange?: (value: boolean) => void
  @Param replyCountText: string = ''
  @Param replyDisplayMode: string = 'origin'
  @Param replyDisplayModeText: string = AppStrings.text($r('app.string.reply_display_mode_origin'), 'Original')
  @Event onJumpToFloor?: () => void
  @Event onLatest?: () => void
  @Event onShowDisplayMenu?: () => void
  @Event onDisplayModeChange?: (mode: string) => void

  build() {
    Row({ space: ThemeConstants.SPACE_SM }) {
      Text(this.replyCountText)
        .fontSize(ThemeConstants.FONT_SIZE_META)
        .fontColor($r('sys.color.font_secondary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
      Row({ space: ThemeConstants.SPACE_XS }) {
        this.ToolButton(AppStrings.text($r('app.string.topic_detail_tool_floor'), 'Floor'), false, () => {
          if (this.onJumpToFloor) {
            this.onJumpToFloor()
          }
        })
        this.DisplayModeButton()
        this.ToolButton(AppStrings.text($r('app.string.topic_detail_tool_latest'), 'Latest'), false, () => {
          if (this.onLatest) {
            this.onLatest()
          }
        })
      }.alignItems(VerticalAlign.Center)
    }
    .alignItems(VerticalAlign.Center)
    .width('100%')
    .padding({
      left: ThemeConstants.SPACE_SM,
      right: ThemeConstants.SPACE_SM,
      top: ThemeConstants.SPACE_SM,
      bottom: ThemeConstants.SPACE_XS,
    })
  }

  @Builder ToolButton(label: string, active: boolean, action: () => void) {
    Text(label)
      .fontSize(ThemeConstants.FONT_SIZE_TINY)
      .fontColor(active ? Color.White : $r('sys.color.font_secondary'))
      .padding({ left: ThemeConstants.SPACE_SM, right: ThemeConstants.SPACE_SM, top: 5, bottom: 5 })
      .borderRadius(ThemeConstants.RADIUS_ROUND)
      .backgroundColor(
        active ? ThemeConstants.BRAND_PRIMARY : $r('sys.color.ohos_id_color_button_normal'),
      )
      .onClick(action)
  }

  @Builder DisplayModeButton() {
    Text(this.replyDisplayModeText)
      .fontSize(ThemeConstants.FONT_SIZE_TINY)
      .fontColor(
        this.replyDisplayMode === 'origin' ? $r('sys.color.font_secondary') : Color.White,
      )
      .padding({ left: ThemeConstants.SPACE_SM, right: ThemeConstants.SPACE_SM, top: 5, bottom: 5 })
      .borderRadius(ThemeConstants.RADIUS_ROUND)
      .backgroundColor(
        this.replyDisplayMode === 'origin'
          ? $r('sys.color.ohos_id_color_button_normal')
          : ThemeConstants.BRAND_PRIMARY,
      )
      .onClick(() => {
        if (this.onShowDisplayMenu) {
          this.onShowDisplayMenu()
        }
      })
      .bindMenu(this.replyDisplayMenuShown, this.DisplayModeMenu, {
        placement: Placement.BottomRight,
        aboutToDisappear: () => {
          if (this.onReplyDisplayMenuShownChange) {
            this.onReplyDisplayMenuShownChange(false)
          }
        },
      })
  }

  @Builder DisplayModeMenu() {
    Menu() {
      ForEach(
        TopicDetailReplyDisplayCoordinator.modeOptions(),
        (option: ReplyDisplayModeOption) => {
          this.DisplayModeMenuItem(option)
        },
        (option: ReplyDisplayModeOption) => option.mode,
      )
    }
  }

  @Builder DisplayModeMenuItem(option: ReplyDisplayModeOption) {
    MenuItem({
      content: option.label,
      symbolEndIcon:
        this.replyDisplayMode === option.mode
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
    }).onClick(() => {
      if (this.onDisplayModeChange) {
        this.onDisplayModeChange(option.mode)
      }
    })
  }
}

@ComponentV2
export struct ReplyContextSheetContent {
  @BuilderParam content: () => void
  @Param title: string = AppStrings.text($r('app.string.reply_context_title'), 'Reply context')
  @Event closeAction?: () => void

  build() {
    AppModalScaffold({
      title: this.title,
      closeAction: () => {
        if (this.closeAction) {
          this.closeAction()
        }
      },
    }) {
      this.content()
    }
  }
}

@ComponentV2
export struct ReplyContextListItem {
  @Require @Param reply: V2exReply
  @Param floor: number = 0
  @Param label: string = ''
  @Param selected: boolean = false
  @Param snippet: string = ''
  @Param bodyFontSize: number = ThemeConstants.FONT_SIZE_BODY
  @Param bodyLineHeight: number = ThemeConstants.LINE_HEIGHT_BODY
  @Event onSelect?: () => void

  build() {
    Column({ space: ThemeConstants.SPACE_SM }) {
      Row({ space: ThemeConstants.SPACE_SM }) {
        Text(this.label)
          .fontSize(ThemeConstants.FONT_SIZE_TAG)
          .fontColor(
            this.selected
              ? ThemeConstants.BRAND_PRIMARY
              : $r('sys.color.font_secondary'),
          )
          .padding({
            left: ThemeConstants.SPACE_SM,
            right: ThemeConstants.SPACE_SM,
            top: 2,
            bottom: 2,
          })
          .borderRadius(ThemeConstants.RADIUS_SM)
          .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
        Text(`#${this.floor}`)
          .fontSize(ThemeConstants.FONT_SIZE_TAG)
          .fontColor($r('sys.color.font_secondary'))
        Text(this.reply.member.username)
          .fontSize(ThemeConstants.FONT_SIZE_META)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Blank()
        TimeAgo({ timestamp: this.reply.created })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      Text(this.snippet)
        .fontSize(this.bodyFontSize)
        .lineHeight(this.bodyLineHeight)
        .fontColor($r('sys.color.font_primary'))
        .maxLines(4)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
    }
    .width('100%')
    .padding(ThemeConstants.SPACE_MD)
    .borderRadius(ThemeConstants.RADIUS_MD)
    .backgroundColor(
      this.selected
        ? $r('sys.color.ohos_id_color_button_normal')
        : $r('sys.color.ohos_id_color_sub_background'),
    )
    .onClick(() => {
      if (this.onSelect) {
        this.onSelect()
      }
    })
  }
}
