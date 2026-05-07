/**
 * 品牌和 UI 主题 Token
 * 优先使用系统色彩 Token（$r('sys.color.xxx')），此处定义品牌特有值
 */
export class ThemeConstants {
  // 品牌色
  static readonly BRAND_PRIMARY: ResourceColor = $r("sys.color.ohos_id_color_activated");
  static readonly BRAND_ACCENT: ResourceColor = $r("sys.color.font_secondary");

  // 文本色（系统 Token 的语义别名，避免各处重复写 $r）
  static readonly TEXT_PRIMARY: ResourceColor = $r("sys.color.font_primary");
  static readonly TEXT_SECONDARY: ResourceColor = $r("sys.color.font_secondary");
  static readonly TEXT_LINK: ResourceColor = $r("sys.color.ohos_id_color_activated");
  static readonly BG_SUB: ResourceColor = $r("sys.color.ohos_id_color_sub_background");

  // 间距
  static readonly SPACE_XS: number = 4;
  static readonly SPACE_SM: number = 8;
  static readonly SPACE_MD: number = 12;
  static readonly SPACE_LG: number = 16;
  static readonly SPACE_XL: number = 24;

  // 字号
  static readonly FONT_SIZE_TINY: number = 10;
  static readonly FONT_SIZE_TAG: number = 11;
  static readonly FONT_SIZE_CODE: number = 12;
  static readonly FONT_SIZE_CAPTION: number = 12;
  static readonly FONT_SIZE_META: number = 13;
  static readonly FONT_SIZE_BODY: number = 14;
  static readonly FONT_SIZE_TITLE: number = 16;
  static readonly FONT_SIZE_LIST_ITEM: number = 13;
  static readonly FONT_SIZE_SECTION_TITLE: number = 11;
  static readonly FONT_SIZE_HEADING: number = 18;
  static readonly FONT_SIZE_H3: number = 20;
  static readonly FONT_SIZE_H2: number = 22;
  static readonly FONT_SIZE_H1: number = 24;

  // 圆角
  static readonly RADIUS_SM: number = 4;
  static readonly RADIUS_MD: number = 22;
  static readonly RADIUS_CARD: number = 24;
  static readonly LIST_SECTION_INSET: number = 4;
  static readonly LIST_ROW_RADIUS: number = 19;
  static readonly LIST_ROW_TEXT_INDENT: number = 8;
  static readonly RADIUS_ROUND: number = 999;

  // 尺寸
  static readonly TITLE_BAR_HEIGHT: number = 56;
  static readonly FLOAT_BAR_HEIGHT: number = 76;
  static readonly LOADING_SIZE: number = 32;
  static readonly LOADING_SIZE_LARGE: number = 36;
  static readonly LOADING_SIZE_SMALL: number = 24;
  static readonly INDICATOR_SIZE: number = 28;
  static readonly AVATAR_SIZE_TOPIC: number = 40;
  static readonly AVATAR_SIZE_REPLY: number = 32;
  static readonly AVATAR_SIZE_DEFAULT: number = 48;
  static readonly MARGIN_LOADING_TOP: number = 100;
  static readonly FOOTER_HEIGHT: number = 48;
  static readonly LINE_HEIGHT_TITLE: number = 22;
  static readonly LINE_HEIGHT_BODY: number = 20;
  static readonly LINE_HEIGHT_CODE: number = 18;

  // 图标与触摸目标
  static readonly ICON_SIZE_SM: number = 16;
  static readonly TOUCH_TARGET_SM: number = 36;

  // 代码块颜色（非系统 Token，需自定义）
  static readonly CODE_BG: ResourceColor = "#303236";
  static readonly CODE_TEXT: ResourceColor = "#FFFFFF";
  static readonly CODE_ICON: ResourceColor = "#CCCCCC";
  static readonly PRESSED_OVERLAY: ResourceColor = "#40FFFFFF";

  // 动画
  static readonly ANIM_DURATION: number = 400;
  static readonly ANIM_STATE_RESET_MS: number = 420;
  static readonly ANIM_DONE_DELAY_MS: number = 200;
}
