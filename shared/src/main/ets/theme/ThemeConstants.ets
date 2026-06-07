import { ThemeColorSettings } from '../settings/ThemeColorSettings'

/**
 * Brand and UI theme tokens
 * Prefer system color tokens ($r('sys.color.xxx')), define brand-specific values here
 */
export class ThemeConstants {
  // Brand colors
  static get BRAND_PRIMARY(): ResourceColor { return ThemeColorSettings.currentColor() }
  static readonly BRAND_ACCENT: ResourceColor = $r('sys.color.font_secondary')
  // OP is an identity badge, not an app accent, so keep it stable across theme colors.
  static readonly OP_BADGE_BACKGROUND: ResourceColor = '#0A59F7'

  // Text colors (semantic aliases for system tokens, avoiding repeated $r calls)
  static readonly TEXT_PRIMARY: ResourceColor = $r('sys.color.font_primary')
  static readonly TEXT_SECONDARY: ResourceColor = $r('sys.color.font_secondary')
  static get TEXT_LINK(): ResourceColor { return ThemeColorSettings.currentColor() }
  static readonly BG_SUB: ResourceColor = $r('sys.color.ohos_id_color_sub_background')

  // Spacing
  static readonly SPACE_XS: number = 4
  static readonly SPACE_SM: number = 8
  static readonly SPACE_MD: number = 12
  static readonly SPACE_LG: number = 16
  static readonly SPACE_XL: number = 24
  static readonly SPACE_XXL: number = 32

  // Font sizes
  static readonly FONT_SIZE_TINY: number = 10
  static readonly FONT_SIZE_TAG: number = 11
  static readonly FONT_SIZE_CODE: number = 12
  static readonly FONT_SIZE_CAPTION: number = 12
  static readonly FONT_SIZE_META: number = 13
  static readonly FONT_SIZE_BODY: number = 14
  static readonly FONT_SIZE_TITLE: number = 16
  static readonly FONT_SIZE_LIST_ITEM: number = 13
  static readonly FONT_SIZE_SECTION_TITLE: number = 11
  static readonly FONT_SIZE_HEADING: number = 18
  static readonly FONT_SIZE_H3: number = 20
  static readonly FONT_SIZE_H2: number = 22
  static readonly FONT_SIZE_H1: number = 24

  // Border radius
  static readonly RADIUS_SM: number = 4
  static readonly RADIUS_MD: number = 22
  static readonly RADIUS_CARD: number = 24
  static readonly LIST_SECTION_INSET: number = 4
  static readonly LIST_ROW_RADIUS: number = 19
  static readonly LIST_ROW_TEXT_INDENT: number = 8
  static readonly RADIUS_ROUND: number = 999

  // Dimensions
  static readonly TITLE_BAR_HEIGHT: number = 56
  static readonly FLOAT_BAR_HEIGHT: number = 76
  static readonly LOADING_SIZE: number = 32
  static readonly LOADING_SIZE_LARGE: number = 36
  static readonly LOADING_SIZE_SMALL: number = 24
  static readonly INDICATOR_SIZE: number = 28
  static readonly AVATAR_SIZE_TOPIC: number = 40
  static readonly AVATAR_SIZE_REPLY: number = 32
  static readonly AVATAR_SIZE_DEFAULT: number = 48
  // Topic-detail "resume reading" floating button: same 56pt material circle as the
  // reply FAB so the icon centers identically; it reads as secondary via its smaller
  // glyph (fontSize 24 vs 28) rather than a smaller circle. HdsTabs' floating material
  // mis-centers its glyph at small bar sizes, so matching the reply size is what keeps
  // the chevron concentric.
  static readonly TOPIC_DETAIL_RESUME_BUTTON_SIZE: number = 56
  static readonly MARGIN_LOADING_TOP: number = 100
  static readonly FOOTER_HEIGHT: number = 48
  static readonly LINE_HEIGHT_TITLE: number = 22
  static readonly LINE_HEIGHT_BODY: number = 20
  static readonly LINE_HEIGHT_CODE: number = 18
  // Compact width for two-item segmented controls that should keep the old
  // SegmentButton intrinsic-size look after moving to TabSegmentButtonV2.
  static readonly COMPACT_SEGMENT_BUTTON_WIDTH: number = 216

  // Icons and touch targets
  static readonly ICON_SIZE_SM: number = 16
  // Decorative placeholder glyph centered in an empty pane (e.g. the editor's empty preview).
  static readonly ICON_SIZE_PLACEHOLDER: number = 48
  static readonly TOUCH_TARGET_SM: number = 36

  // Code block colors (not system tokens, must be custom defined)
  static readonly CODE_BG: ResourceColor = '#303236'
  static readonly CODE_TEXT: ResourceColor = '#FFFFFF'
  static readonly CODE_ICON: ResourceColor = '#CCCCCC'
  static readonly PRESSED_OVERLAY: ResourceColor = '#40FFFFFF'

  // Animations
  static readonly ANIM_DURATION: number = 400
  static readonly ANIM_STATE_RESET_MS: number = 420
  static readonly ANIM_DONE_DELAY_MS: number = 200
}
