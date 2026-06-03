export interface V2exReplyWriteForm {
  actionPath: string
  contentField: string
  hiddenFields: Record<string, string>
}

export interface V2exTopicWriteForm {
  actionPath: string
  titleField: string
  contentField: string
  hiddenFields: Record<string, string>
  // Value of the syntax <select> option labelled "Markdown" (the option VALUE differs from its visible
  // text — it may be "markdown" or a numeric "1"). Empty when the compose form has no syntax select.
  markdownSyntaxValue: string
}

interface V2exInputTag {
  type: string
  name: string
  value: string
  placeholder: string
  id: string
}

interface V2exTextareaTag {
  name: string
  id: string
}

/**
 * Cookie 写入表单解析器
 * - 从 HTML 中提取回复/发帖表单的 action 与隐藏字段（once 等）
 */
export class V2exWriteFormParser {
  static extractReplyForm(html: string): V2exReplyWriteForm | null {
    const formHtml = V2exWriteFormParser.extractFormHtml(html, [
      /id=['"]reply_content['"]/i,
      /<textarea[^>]*name=['"]content['"][^>]*>/i
    ])
    if (!formHtml) {
      return null
    }

    const actionPath = V2exWriteFormParser.extractFormAction(formHtml)
    const hiddenFields = V2exWriteFormParser.extractHiddenFields(formHtml)
    const contentField = V2exWriteFormParser.findTextareaName(formHtml, 'reply_content') || 'content'

    if (!actionPath || !contentField) {
      return null
    }
    return { actionPath, contentField, hiddenFields }
  }

  static extractTopicCreateForm(html: string): V2exTopicWriteForm | null {
    const formHtml = V2exWriteFormParser.extractFormHtml(html, [
      /id=['"]topic_content['"]/i,
      /<textarea[^>]*name=['"]content['"][^>]*>/i
    ])
    if (!formHtml) {
      return null
    }

    const actionPath = V2exWriteFormParser.extractFormAction(formHtml)
    const hiddenFields = V2exWriteFormParser.extractHiddenFields(formHtml)
    const titleField = V2exWriteFormParser.findTitleField(formHtml) || 'title'
    const contentField = V2exWriteFormParser.findTextareaName(formHtml, 'topic_content') || 'content'
    const markdownSyntaxValue = V2exWriteFormParser.extractSyntaxMarkdownValue(formHtml)

    if (!actionPath || !titleField || !contentField) {
      return null
    }
    return { actionPath, titleField, contentField, hiddenFields, markdownSyntaxValue }
  }

  /**
   * The compose form's syntax control is a `<select name="syntax" id="select_syntax">` whose Markdown
   * option's VALUE (not its visible "Markdown" text) is what the server expects. Return that value, or ''
   * if the form has no syntax select (then Markdown is only honoured via the /write endpoint).
   */
  static extractSyntaxMarkdownValue(formHtml: string): string {
    const select = V2exWriteFormParser.extractSyntaxSelect(formHtml)
    if (!select) {
      return ''
    }
    const re = /<option\b([^>]*)>([\s\S]*?)<\/option>/gi
    let m: RegExpExecArray | null = re.exec(select)
    while (m) {
      const optionText = m[2].replace(/<[^>]*>/g, '').trim()
      if (/markdown/i.test(optionText)) {
        return V2exWriteFormParser.extractAttr(`<option ${m[1]}>`, 'value')
      }
      m = re.exec(select)
    }
    return ''
  }

  private static extractSyntaxSelect(formHtml: string): string {
    const re = /<select\b[^>]*(?:name=['"]syntax['"]|id=['"]select_syntax['"])[^>]*>[\s\S]*?<\/select>/i
    const m = formHtml.match(re)
    return m ? m[0] : ''
  }

  private static extractFormHtml(html: string, markers: RegExp[]): string {
    if (!html) {
      return ''
    }
    for (const marker of markers) {
      const pos = html.search(marker)
      if (pos < 0) {
        continue
      }
      const open = html.lastIndexOf('<form', pos)
      if (open < 0) {
        continue
      }
      const close = html.indexOf('</form>', pos)
      if (close < 0) {
        continue
      }
      return html.substring(open, close + '</form>'.length)
    }
    return ''
  }

  private static extractFormAction(formHtml: string): string {
    const openEnd = formHtml.indexOf('>')
    if (openEnd < 0) {
      return ''
    }
    const openTag = formHtml.slice(0, openEnd + 1)
    return V2exWriteFormParser.extractAttr(openTag, 'action')
  }

  private static extractHiddenFields(formHtml: string): Record<string, string> {
    const fields: Record<string, string> = {}
    const inputs = V2exWriteFormParser.extractInputs(formHtml)
    for (const input of inputs) {
      if (input.type.toLowerCase() !== 'hidden') {
        continue
      }
      if (!input.name) {
        continue
      }
      fields[input.name] = input.value || ''
    }
    return fields
  }

  private static findTitleField(formHtml: string): string {
    const inputs = V2exWriteFormParser.extractInputs(formHtml)
    const namedTextInputs = inputs.filter((input: V2exInputTag) => input.type.toLowerCase() === 'text' && input.name)
    const preferred = namedTextInputs.find((input: V2exInputTag) => {
      const name = input.name.toLowerCase()
      const placeholder = (input.placeholder || '').toLowerCase()
      return name === 'title' || placeholder.indexOf('title') >= 0 || placeholder.indexOf('标题') >= 0
    })
    return preferred ? preferred.name : (namedTextInputs.length > 0 ? namedTextInputs[0].name : '')
  }

  private static findTextareaName(formHtml: string, preferredId: string): string {
    const areas = V2exWriteFormParser.extractTextareas(formHtml)
    const preferred = areas.find((t: V2exTextareaTag) => t.id === preferredId && t.name)
    if (preferred) {
      return preferred.name
    }
    const named = areas.find((t: V2exTextareaTag) => t.name)
    return named ? named.name : ''
  }

  private static extractInputs(html: string): V2exInputTag[] {
    const inputs: V2exInputTag[] = []
    const re = /<input\b[^>]*>/gi
    let m: RegExpExecArray | null = re.exec(html)
    while (m) {
      const tag = m[0]
      inputs.push({
        type: V2exWriteFormParser.extractAttr(tag, 'type') || 'text',
        name: V2exWriteFormParser.extractAttr(tag, 'name'),
        value: V2exWriteFormParser.extractAttr(tag, 'value'),
        placeholder: V2exWriteFormParser.extractAttr(tag, 'placeholder'),
        id: V2exWriteFormParser.extractAttr(tag, 'id')
      })
      m = re.exec(html)
    }
    return inputs
  }

  private static extractTextareas(html: string): V2exTextareaTag[] {
    const areas: V2exTextareaTag[] = []
    const re = /<textarea\b[^>]*>/gi
    let m: RegExpExecArray | null = re.exec(html)
    while (m) {
      const tag = m[0]
      areas.push({
        name: V2exWriteFormParser.extractAttr(tag, 'name'),
        id: V2exWriteFormParser.extractAttr(tag, 'id')
      })
      m = re.exec(html)
    }
    return areas
  }

  private static extractAttr(tag: string, attrName: string): string {
    const re = new RegExp(`${attrName}\\s*=\\s*(['\"])(.*?)\\1`, 'i')
    const m = tag.match(re)
    return m && m[2] ? V2exWriteFormParser.decodeHtml(m[2]) : ''
  }

  private static decodeHtml(value: string): string {
    return (value || '')
      .replace(/&amp;/g, '&')
      .replace(/&quot;/g, '"')
      .replace(/&#39;/g, "'")
      .replace(/&lt;/g, '<')
      .replace(/&gt;/g, '>')
  }
}
