export class ReplyCardLayoutPolicy {
  // Top-level reply card padding.
  static readonly PADDING_TOP: number = 12;
  static readonly PADDING_BOTTOM: number = 12;
  static readonly PADDING_LEFT: number = 16;
  static readonly PADDING_RIGHT: number = 16;

  // Embedded reply cards only keep left padding for thread indentation.
  static readonly PADDING_LEFT_EMBEDDED: number = 8;
  static readonly PADDING_LEFT_DEEP: number = 8;

  static readonly CONTENT_GAP: number = 8;
  static readonly ACTIONS_GAP: number = 0;
  static readonly CHILD_DIVIDER_MARGIN: number = 8;
  static readonly COMPACT_CHILD_REPLY_GAP: number = 8;
  static readonly THREAD_GUIDE_LINE_WIDTH: number = 0.5;
  static readonly THREAD_GUIDE_CONTENT_GAP: number = 6;
  static readonly THREAD_GUIDE_END_INSET: number = 8;

  // Inline-compact-header fit budget. The compact meta column already wraps and its username can
  // shrink/ellipsis, so long names should not by themselves force all actions into the overflow menu.
  // Fold only when the measured header cannot fit the fixed chrome plus a usable meta column.
  static readonly HEADER_ACTION_BUTTON_VP: number = 36;
  static readonly HEADER_AVATAR_VP: number = 32;
  static readonly HEADER_ROW_GAP_VP: number = 8;
  static readonly HEADER_MIN_META_VP: number = 96;
  static readonly HEADER_INLINE_SAFETY_VP: number = 8;
  static readonly HEADER_THANK_ICON_VP: number = 16;
  static readonly HEADER_THANK_BUTTON_PADDING_VP: number = 8;
  static readonly HEADER_THANK_ICON_TEXT_GAP_VP: number = 4;
  static readonly HEADER_THANK_TEXT_FONT_VP: number = 12;
  static readonly HEADER_FLOOR_FONT_VP: number = 11;

  // Rough rendered width of a string: CJK / full-width glyphs ~= the font size, Latin/ASCII ~= 0.56x.
  // Approximate by design — it only needs to decide a layout fit, and the username's
  // flexShrink + ellipsis is the safety net when a borderline row is kept inline.
  static estTextWidth(text: string, fontSizeVp: number): number {
    let width = 0
    for (let i = 0; i < text.length; i++) {
      width += text.charCodeAt(i) > 0x2e7f ? fontSizeVp : fontSizeVp * 0.56
    }
    return width
  }

  static thankButtonExtraWidth(thanks: number): number {
    if (thanks <= 0) {
      return 0
    }
    const rendered =
      ReplyCardLayoutPolicy.HEADER_THANK_ICON_VP +
      ReplyCardLayoutPolicy.HEADER_THANK_ICON_TEXT_GAP_VP +
      ReplyCardLayoutPolicy.estTextWidth(`${thanks}`, ReplyCardLayoutPolicy.HEADER_THANK_TEXT_FONT_VP) +
      ReplyCardLayoutPolicy.HEADER_THANK_BUTTON_PADDING_VP
    return Math.max(0, rendered - ReplyCardLayoutPolicy.HEADER_ACTION_BUTTON_VP)
  }

  static compactHeaderStacked(
    availableWidth: number,
    floor: number,
    showAvatar: boolean,
    thanks: number,
  ): boolean {
    if (availableWidth <= 0) {
      return false
    }
    const visibleColumns = showAvatar ? 4 : 3
    const required =
      (showAvatar ? ReplyCardLayoutPolicy.HEADER_AVATAR_VP : 0) +
      (visibleColumns - 1) * ReplyCardLayoutPolicy.HEADER_ROW_GAP_VP +
      ReplyCardLayoutPolicy.HEADER_MIN_META_VP +
      ReplyCardLayoutPolicy.HEADER_ACTION_BUTTON_VP * 3 +
      ReplyCardLayoutPolicy.thankButtonExtraWidth(thanks) +
      ReplyCardLayoutPolicy.estTextWidth(`#${floor}`, ReplyCardLayoutPolicy.HEADER_FLOOR_FONT_VP) +
      ReplyCardLayoutPolicy.HEADER_INLINE_SAFETY_VP
    return required > availableWidth
  }

  static leftPadding(embedded: boolean, threadLevel: number): number {
    if (!embedded) {
      return ReplyCardLayoutPolicy.PADDING_LEFT
    }
    return threadLevel > 1
      ? ReplyCardLayoutPolicy.PADDING_LEFT_DEEP
      : ReplyCardLayoutPolicy.PADDING_LEFT_EMBEDDED
  }

  static rightPadding(embedded: boolean): number {
    return embedded ? 0 : ReplyCardLayoutPolicy.PADDING_RIGHT
  }

  static topPadding(embedded: boolean): number {
    return embedded ? 0 : ReplyCardLayoutPolicy.PADDING_TOP
  }

  static bottomPadding(embedded: boolean): number {
    return embedded ? 0 : ReplyCardLayoutPolicy.PADDING_BOTTOM
  }

  static threadIndent(threadLevel: number, cardWidth: number): number {
    if (threadLevel <= 0) return 0
    const availableWidth = cardWidth > 0 ? cardWidth : 360
    const indentUnit = Math.max(12, Math.min(20, availableWidth * 0.045))
    const minContentWidth = 240
    const maxByWidth = Math.max(
      1,
      Math.min(3, Math.floor((availableWidth - minContentWidth) / indentUnit)),
    )
    return Math.min(threadLevel, maxByWidth) * indentUnit
  }
}
