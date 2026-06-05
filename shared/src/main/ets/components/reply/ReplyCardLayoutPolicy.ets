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

  // Inline-compact-header fit budget. The header stacks the timestamp under the username + folds the
  // actions into a menu ONLY when its single row would not actually fit — decided from THIS reply's
  // content, not a fixed width threshold (a fixed cut is really a phone/tablet switch: every phone
  // card is "narrow", every tablet card is "wide", which is not adaptive). The dominant variable is
  // the username length, so estimate the row's required width from it and compare to the measured
  // space; a short-name reply stays inline even on a phone, a long-name / genuinely-narrow card folds.
  static readonly HEADER_INLINE_FIXED_VP: number = 280; // avatar + timestamp + 3 buttons + floor + gaps
  static readonly HEADER_OP_BADGE_VP: number = 28;
  static readonly HEADER_DUP_BADGE_VP: number = 34;
  static readonly HEADER_THANKS_EXTRA_VP: number = 18;
  static readonly HEADER_USERNAME_FONT_VP: number = 13; // mirrors ThemeConstants.FONT_SIZE_META
  static readonly HEADER_MARK_FONT_VP: number = 10;
  static readonly HEADER_MARK_BADGE_PADDING_VP: number = 12;
  static readonly HEADER_MARK_BADGE_MAX_VP: number = 76;
  static readonly HEADER_MARK_OVERFLOW_MAX_VP: number = 34;
  static readonly HEADER_MARK_ROW_GAP_VP: number = 4;
  static readonly HEADER_USERNAME_MARK_GAP_VP: number = 4;

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

  static compactHeaderStacked(
    availableWidth: number,
    username: string,
    isOp: boolean,
    isDuplicate: boolean,
    hasThanks: boolean,
    markWidth: number,
  ): boolean {
    if (availableWidth <= 0) {
      return false
    }
    const required =
      ReplyCardLayoutPolicy.HEADER_INLINE_FIXED_VP +
      ReplyCardLayoutPolicy.estTextWidth(username, ReplyCardLayoutPolicy.HEADER_USERNAME_FONT_VP) +
      markWidth +
      (isOp ? ReplyCardLayoutPolicy.HEADER_OP_BADGE_VP : 0) +
      (isDuplicate ? ReplyCardLayoutPolicy.HEADER_DUP_BADGE_VP : 0) +
      (hasThanks ? ReplyCardLayoutPolicy.HEADER_THANKS_EXTRA_VP : 0)
    return required > availableWidth
  }

  static compactHeaderMarkWidth(labelName: string, totalCount: number, showOverflow: boolean): number {
    if (totalCount <= 0 || !(labelName || '').trim()) {
      return 0
    }
    let width =
      ReplyCardLayoutPolicy.HEADER_USERNAME_MARK_GAP_VP +
      ReplyCardLayoutPolicy.markBadgeWidth(
        labelName,
        ReplyCardLayoutPolicy.HEADER_MARK_BADGE_MAX_VP,
      )
    if (showOverflow && totalCount > 1) {
      width +=
        ReplyCardLayoutPolicy.HEADER_MARK_ROW_GAP_VP +
        ReplyCardLayoutPolicy.markBadgeWidth(
          `+${totalCount - 1}`,
          ReplyCardLayoutPolicy.HEADER_MARK_OVERFLOW_MAX_VP,
        )
    }
    return width
  }

  private static markBadgeWidth(text: string, maxWidth: number): number {
    return Math.min(
      maxWidth,
      ReplyCardLayoutPolicy.estTextWidth(text, ReplyCardLayoutPolicy.HEADER_MARK_FONT_VP) +
        ReplyCardLayoutPolicy.HEADER_MARK_BADGE_PADDING_VP,
    )
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
