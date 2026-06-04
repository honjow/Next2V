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

  // Below this measured card width the compact reply header can no longer fit avatar + username +
  // timestamp + the three action buttons + floor on one line (a long username gets squeezed,
  // worst inside deeply-threaded 楼中楼 replies). At/under it the header stacks the timestamp under
  // the username and collapses the actions into a single overflow menu. ~480vp cleanly separates
  // phones (which stack) from tablets / wide foldables (which keep the roomy inline header).
  static readonly COMPACT_HEADER_STACK_WIDTH: number = 480;

  static compactHeaderStacked(cardWidth: number): boolean {
    return cardWidth > 0 && cardWidth < ReplyCardLayoutPolicy.COMPACT_HEADER_STACK_WIDTH
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
