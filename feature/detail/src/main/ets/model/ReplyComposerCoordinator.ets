export interface ReplyComposerEditResult {
  content: string
  selectionStart: number
  selectionEnd: number
  caret: number
}

export class ReplyComposerCoordinator {
  static normalizeInitialContent(value: string): string {
    const clean = (value || '').trim()
    return clean ? `${clean} ` : ''
  }

  static mergeInitialContent(draftContent: string, seed: string): string {
    const draft = draftContent || ''
    if (!seed) {
      return draft
    }
    if (draft.trim().length === 0) {
      return seed
    }
    if (ReplyComposerCoordinator.startsWithInitialSeed(draft, seed)) {
      return draft
    }
    return seed
  }

  static insertInlineMarkdown(
    content: string,
    selectionStart: number,
    selectionEnd: number,
    prefix: string,
    suffix: string,
    placeholder: string,
    caretOffset: number = -1,
  ): ReplyComposerEditResult {
    const contentLength = content.length
    const start = ReplyComposerCoordinator.clampSelection(selectionStart, contentLength)
    const rawEnd = ReplyComposerCoordinator.clampSelection(selectionEnd, contentLength)
    const end = rawEnd >= start ? rawEnd : start
    const selected = content.substring(start, end)
    const middle = selected || placeholder
    const insertion = `${prefix}${middle}${suffix}`
    const nextContent = `${content.substring(0, start)}${insertion}${content.substring(end)}`
    const caret =
      start + (caretOffset >= 0 ? caretOffset : prefix.length + middle.length + suffix.length)
    return {
      content: nextContent,
      selectionStart: caret,
      selectionEnd: caret,
      caret: caret,
    }
  }

  static insertLinePrefix(
    content: string,
    selectionStart: number,
    selectionEnd: number,
    prefix: string,
  ): ReplyComposerEditResult {
    const contentLength = content.length
    const start = ReplyComposerCoordinator.clampSelection(selectionStart, contentLength)
    const lineStart = content.lastIndexOf('\n', Math.max(0, start - 1)) + 1
    const nextContent = `${content.substring(0, lineStart)}${prefix}${content.substring(lineStart)}`
    const caret = start + prefix.length
    return {
      content: nextContent,
      selectionStart: caret,
      selectionEnd: caret,
      caret: caret,
    }
  }

  static canSubmit(
    isSubmitting: boolean,
    isSubmitDialogShown: boolean,
    topicId: number,
    content: string,
  ): boolean {
    return !isSubmitting && !isSubmitDialogShown && topicId > 0 && content.trim().length > 0
  }

  static composerBodyHeight(keyboardHeight: number): number {
    if (keyboardHeight > 0) {
      return 120
    }
    return 176
  }

  private static startsWithInitialSeed(content: string, seed: string): boolean {
    const target = seed.trim()
    if (!target) {
      return false
    }
    const text = (content || '').trimStart()
    return text.trim() === target || text.startsWith(`${target} `) || text.startsWith(`${target}\n`)
  }

  private static clampSelection(value: number, contentLength: number): number {
    return Math.min(Math.max(value, 0), contentLength)
  }
}
