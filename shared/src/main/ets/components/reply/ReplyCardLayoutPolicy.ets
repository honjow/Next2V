export class ReplyCardLayoutPolicy {
  // Top-level reply card padding.
  static readonly PADDING_TOP: number = 12;
  static readonly PADDING_BOTTOM: number = 12;
  static readonly PADDING_LEFT: number = 16;
  static readonly PADDING_RIGHT: number = 16;

  // Embedded reply cards only keep left padding for thread indentation.
  static readonly PADDING_LEFT_EMBEDDED: number = 12;
  static readonly PADDING_LEFT_DEEP: number = 16;

  static readonly CONTENT_GAP: number = 8;
  static readonly ACTIONS_GAP: number = 0;
  static readonly CHILD_DIVIDER_MARGIN: number = 8;

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
