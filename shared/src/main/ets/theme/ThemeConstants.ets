/**
 * 品牌和 UI 主题 Token
 * 优先使用系统色彩 Token（$r('sys.color.xxx')），此处定义品牌特有值
 */
export class ThemeConstants {
  // 品牌色
  static readonly BRAND_PRIMARY: ResourceColor = $r('sys.color.ohos_id_color_activated')
  static readonly BRAND_ACCENT: ResourceColor = $r('sys.color.font_secondary')

  // 间距
  static readonly SPACE_XS: number = 4
  static readonly SPACE_SM: number = 8
  static readonly SPACE_MD: number = 12
  static readonly SPACE_LG: number = 16
  static readonly SPACE_XL: number = 24

  // 字号
  static readonly FONT_SIZE_CAPTION: number = 12
  static readonly FONT_SIZE_BODY: number = 14
  static readonly FONT_SIZE_TITLE: number = 16
  static readonly FONT_SIZE_HEADING: number = 18

  // 圆角
  static readonly RADIUS_SM: number = 4
  static readonly RADIUS_MD: number = 8
  static readonly RADIUS_ROUND: number = 999
}
