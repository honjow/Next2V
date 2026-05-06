export interface V2exSigninForm {
  usernameField: string
  passwordField: string
  captchaField: string
  captchaUrl: string
  once: string
  next: string
}

interface V2exSigninInput {
  type: string
  name: string
  value: string
  placeholder: string
}

/**
 * V2EX /signin 表单解析器
 * - 用于原生用户名/密码登录原型
 */
export class V2exSigninParser {
  static extractForm(html: string): V2exSigninForm | null {
    if (!html) {
      return null
    }

    const inputs = V2exSigninParser.extractInputs(html)
    const once = V2exSigninParser.inputValue(inputs, 'once')
    const next = V2exSigninParser.inputValue(inputs, 'next')
    const usernameField = V2exSigninParser.findUsernameField(inputs)
    const passwordField = V2exSigninParser.findInputNameByType(inputs, 'password')
    const captchaField = V2exSigninParser.findCaptchaField(inputs)
    const captchaUrl = V2exSigninParser.extractCaptchaUrl(html)

    if (!once || !next || !usernameField || !passwordField) {
      return null
    }

    return { usernameField, passwordField, captchaField, captchaUrl, once, next }
  }

  static extractProblemMessage(html: string): string {
    if (!html) {
      return ''
    }
    const problemRe = /<div[^>]*class=['"][^'"]*problem[^'"]*['"][^>]*>([\s\S]*?)<\/div>/i
    const problem = html.match(problemRe)
    if (problem && problem[1]) {
      return V2exSigninParser.compactText(problem[1])
    }
    return ''
  }

  private static extractInputs(html: string): V2exSigninInput[] {
    const inputs: V2exSigninInput[] = []
    const re = /<input\b[^>]*>/gi
    let m: RegExpExecArray | null = re.exec(html)
    while (m) {
      const tag = m[0]
      inputs.push({
        type: V2exSigninParser.extractAttr(tag, 'type') || 'text',
        name: V2exSigninParser.extractAttr(tag, 'name'),
        value: V2exSigninParser.extractAttr(tag, 'value'),
        placeholder: V2exSigninParser.extractAttr(tag, 'placeholder')
      })
      m = re.exec(html)
    }
    return inputs
  }

  private static extractAttr(tag: string, attrName: string): string {
    const re = new RegExp(`${attrName}\\s*=\\s*(['"])(.*?)\\1`, 'i')
    const m = tag.match(re)
    return m && m[2] ? V2exSigninParser.decodeHtml(m[2]) : ''
  }

  private static inputValue(inputs: V2exSigninInput[], name: string): string {
    const found = inputs.find((input: V2exSigninInput) => input.name === name)
    return found ? found.value : ''
  }

  private static findInputNameByType(inputs: V2exSigninInput[], inputType: string): string {
    const found = inputs.find((input: V2exSigninInput) => input.type.toLowerCase() === inputType && input.name)
    return found ? found.name : ''
  }

  private static findUsernameField(inputs: V2exSigninInput[]): string {
    const namedTextInputs = inputs.filter((input: V2exSigninInput) => input.type.toLowerCase() === 'text' && input.name)
    const preferred = namedTextInputs.find((input: V2exSigninInput) => {
      const placeholder = input.placeholder.toLowerCase()
      return placeholder.indexOf('username') >= 0 || placeholder.indexOf('email') >= 0
    })
    return preferred ? preferred.name : (namedTextInputs.length > 0 ? namedTextInputs[0].name : '')
  }

  private static findCaptchaField(inputs: V2exSigninInput[]): string {
    const found = inputs.find((input: V2exSigninInput) => {
      const placeholder = input.placeholder.toLowerCase()
      return input.type.toLowerCase() === 'text' && input.name &&
        (placeholder.indexOf('captcha') >= 0 || placeholder.indexOf('code') >= 0)
    })
    return found ? found.name : ''
  }

  private static extractCaptchaUrl(html: string): string {
    const imageRe = /<img\b[^>]*>/gi
    let m: RegExpExecArray | null = imageRe.exec(html)
    while (m) {
      const tag = m[0]
      const alt = V2exSigninParser.extractAttr(tag, 'alt').toLowerCase()
      const src = V2exSigninParser.extractAttr(tag, 'src')
      if (src && (alt.indexOf('captcha') >= 0 || src.indexOf('captcha') >= 0)) {
        return src
      }
      m = imageRe.exec(html)
    }
    return ''
  }

  private static decodeHtml(value: string): string {
    return value
      .replace(/&amp;/g, '&')
      .replace(/&quot;/g, '"')
      .replace(/&#39;/g, "'")
      .replace(/&lt;/g, '<')
      .replace(/&gt;/g, '>')
  }

  private static compactText(html: string): string {
    return V2exSigninParser.decodeHtml(html.replace(/<[^>]+>/g, ' '))
      .replace(/\s+/g, ' ')
      .trim()
  }
}
