export interface ReplyComposerEditResult {
  content: string
  selectionStart: number
  selectionEnd: number
  caret: number
}

export type ReplyComposerToolbarCommand = 'bold' | 'italic' | 'code' | 'quote' | 'list' | 'link' | 'image'

export type ReplySubmitBlockReason = '' | 'busy' | 'invalidTopic' | 'empty' | 'loginRequired'

export interface ReplySubmitCheckResult {
  allowed: boolean
  reason: ReplySubmitBlockReason
  content: string
  message: string
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

  static applyToolbarCommand(
    command: ReplyComposerToolbarCommand,
    content: string,
    selectionStart: number,
    selectionEnd: number,
  ): ReplyComposerEditResult {
    if (command === 'bold') {
      return ReplyComposerCoordinator.insertInlineMarkdown(content, selectionStart, selectionEnd, '**', '**', '文字')
    }
    if (command === 'italic') {
      return ReplyComposerCoordinator.insertInlineMarkdown(content, selectionStart, selectionEnd, '*', '*', '文字')
    }
    if (command === 'code') {
      return ReplyComposerCoordinator.insertInlineMarkdown(content, selectionStart, selectionEnd, '`', '`', '代码')
    }
    if (command === 'quote') {
      return ReplyComposerCoordinator.insertLinePrefix(content, selectionStart, selectionEnd, '> ')
    }
    if (command === 'list') {
      return ReplyComposerCoordinator.insertLinePrefix(content, selectionStart, selectionEnd, '- ')
    }
    if (command === 'link') {
      return ReplyComposerCoordinator.insertInlineMarkdown(
        content,
        selectionStart,
        selectionEnd,
        '[',
        '](https://)',
        '文字',
        '[文字](https://'.length,
      )
    }
    return ReplyComposerCoordinator.insertInlineMarkdown(
      content,
      selectionStart,
      selectionEnd,
      '![',
      '](https://)',
      '图片',
      '![图片](https://'.length,
    )
  }

  static canSubmit(
    isSubmitting: boolean,
    isSubmitDialogShown: boolean,
    topicId: number,
    content: string,
  ): boolean {
    return !isSubmitting && !isSubmitDialogShown && topicId > 0 && content.trim().length > 0
  }

  static canSubmitWithCookie(
    isSubmitting: boolean,
    isSubmitDialogShown: boolean,
    topicId: number,
    content: string,
    cookie: string,
  ): boolean {
    return ReplyComposerCoordinator.canSubmit(
      isSubmitting,
      isSubmitDialogShown,
      topicId,
      content,
    ) && !!cookie
  }

  static checkSubmit(
    isSubmitting: boolean,
    isSubmitDialogShown: boolean,
    topicId: number,
    content: string,
    cookie: string,
  ): ReplySubmitCheckResult {
    if (isSubmitting || isSubmitDialogShown) {
      return { allowed: false, reason: 'busy', content: '', message: '' }
    }
    if (topicId <= 0) {
      return { allowed: false, reason: 'invalidTopic', content: '', message: '' }
    }
    const cleanContent = content.trim()
    if (!cleanContent) {
      return { allowed: false, reason: 'empty', content: '', message: '回复内容不能为空' }
    }
    if (!cookie) {
      return { allowed: false, reason: 'loginRequired', content: cleanContent, message: '请先登录' }
    }
    return { allowed: true, reason: '', content: cleanContent, message: '' }
  }

  static sheetSubmitConfirmMessage(): string {
    return '确定提交这条回复吗？'
  }

  static pageSubmitConfirmMessage(topicTitle: string): string {
    const title = (topicTitle || '').trim()
    const target = title ? `《${title}》` : '当前主题'
    return `确定向${target}提交回复吗？\n\n` +
      'V2EX 回复通常至少消耗 5 铜币，提交后会修改你的账号状态。'
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
