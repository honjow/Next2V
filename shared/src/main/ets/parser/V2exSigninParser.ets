export interface V2exSigninForm {
  usernameField: string
  passwordField: string
  captchaField: string
  captchaUrl: string
  once: string
  next: string
}

export interface V2exTwoFactorForm {
  action: string
  codeField: string
  hiddenFields: Record<string, string>
}

export interface V2exLoginRestriction {
  restrictedIp: string
  message: string
}

interface V2exSigninInput {
  type: string
  name: string
  value: string
  placeholder: string
  context: string
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

  static extractLoginRestriction(html: string): V2exLoginRestriction | null {
    if (!html) {
      return null
    }
    const text = V2exSigninParser.compactText(html)
    if (text.indexOf('登录受限') < 0 && text.indexOf('login restricted') < 0) {
      return null
    }
    const ipMatch = text.match(/(?:受限的 IP 地址|restricted IP address)\s*›?\s*((?:\d{1,3}\.){3}\d{1,3})/i)
    return {
      restrictedIp: ipMatch && ipMatch[1] ? ipMatch[1] : '',
      message: text
    }
  }

  static extractProblemMessage(html: string): string {
    if (!html) {
      return ''
    }
    const problemRe = /<div[^>]*class=['"][^'"]*problem[^'"]*['"][^>]*>([\s\S]*?)<\/div>/gi
    let problem: RegExpExecArray | null = problemRe.exec(html)
    while (problem) {
      const message = problem[1] ? V2exSigninParser.compactText(problem[1]) : ''
      if (message) {
        return message
      }
      problem = problemRe.exec(html)
    }
    return ''
  }

  static hasSigninForm(html: string): boolean {
    if (!html) {
      return false
    }
    const forms = V2exSigninParser.extractForms(html)
    return forms.some((form: string) => V2exSigninParser.locationPath(V2exSigninParser.extractFormAction(form)) === '/signin') ||
      V2exSigninParser.extractForm(html) !== null
  }

  static extractTwoFactorForm(html: string): V2exTwoFactorForm | null {
    if (!html) {
      return null
    }
    const forms = V2exSigninParser.extractForms(html)
    const preferred = forms.find((form: string) => V2exSigninParser.looksLikeTwoFactorForm(form)) ||
      forms.find((form: string) => V2exSigninParser.looksLikeTwoFactorFormByActionOrInputs(form)) ||
      (V2exSigninParser.looksLikeTwoFactorForm(html) || V2exSigninParser.looksLikeTwoFactorFormByActionOrInputs(html) ? html : '')
    if (!preferred) {
      return null
    }

    const inputs = V2exSigninParser.extractInputs(preferred)
    const codeField = V2exSigninParser.findTwoFactorCodeField(inputs)
    if (!codeField) {
      return null
    }

    const hiddenFields: Record<string, string> = {}
    inputs
      .filter((input: V2exSigninInput) => {
        const type = input.type.toLowerCase()
        return input.name && (type === 'hidden' || type === 'submit' || type === 'button')
      })
      .forEach((input: V2exSigninInput) => {
        hiddenFields[input.name] = input.value
      })

    return {
      action: V2exSigninParser.extractFormAction(preferred),
      codeField,
      hiddenFields
    }
  }

  private static extractForms(html: string): string[] {
    const forms: string[] = []
    const re = /<form\b[^>]*>[\s\S]*?<\/form>/gi
    let m: RegExpExecArray | null = re.exec(html)
    while (m) {
      forms.push(m[0])
      m = re.exec(html)
    }
    return forms
  }

  private static looksLikeTwoFactorForm(html: string): boolean {
    const text = V2exSigninParser.compactText(html).toLowerCase()
    return text.indexOf('2fa') >= 0 ||
      text.indexOf('two-factor') >= 0 ||
      text.indexOf('two factor') >= 0 ||
      text.indexOf('authentication code') >= 0 ||
      text.indexOf('one-time') >= 0 ||
      text.indexOf('totp') >= 0 ||
      text.indexOf('两步') >= 0 ||
      text.indexOf('二步') >= 0 ||
      text.indexOf('动态验证码') >= 0 ||
      text.indexOf('安全码') >= 0
  }

  private static looksLikeTwoFactorFormByActionOrInputs(html: string): boolean {
    const actionPath = V2exSigninParser.locationPath(V2exSigninParser.extractFormAction(html))
    if (actionPath === '/2fa' || actionPath.indexOf('/2fa?') === 0) {
      return true
    }
    const inputs = V2exSigninParser.extractInputs(html)
    return V2exSigninParser.findTwoFactorCodeField(inputs) === 'code'
  }

  private static extractFormAction(formHtml: string): string {
    const formTag = formHtml.match(/<form\b[^>]*>/i)
    return formTag ? V2exSigninParser.extractAttr(formTag[0], 'action') : ''
  }

  private static locationPath(location: string): string {
    const trimmed = (location || '').trim()
    if (!trimmed) {
      return ''
    }
    const schemeIdx = trimmed.indexOf('://')
    if (schemeIdx >= 0) {
      const pathStart = trimmed.indexOf('/', schemeIdx + 3)
      return pathStart >= 0 ? trimmed.slice(pathStart) : '/'
    }
    return trimmed.indexOf('/') === 0 ? trimmed : `/${trimmed}`
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
        placeholder: V2exSigninParser.extractAttr(tag, 'placeholder'),
        context: V2exSigninParser.inputContext(html, m.index, tag.length)
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
      const name = input.name.toLowerCase()
      const context = input.context.toLowerCase()
      return input.type.toLowerCase() === 'text' && input.name &&
        (placeholder.indexOf('captcha') >= 0 ||
          placeholder.indexOf('code') >= 0 ||
          placeholder.indexOf('验证码') >= 0 ||
          name.indexOf('captcha') >= 0 ||
          context.indexOf('captcha') >= 0 ||
          context.indexOf('验证码') >= 0)
    })
    return found ? found.name : ''
  }

  private static findTwoFactorCodeField(inputs: V2exSigninInput[]): string {
    const candidates = inputs.filter((input: V2exSigninInput) => {
      const type = input.type.toLowerCase()
      return input.name && (type === 'text' || type === 'tel' || type === 'number' || type === 'password' || type === '')
    })
    const preferred = candidates.find((input: V2exSigninInput) => {
      const name = input.name.toLowerCase()
      const placeholder = input.placeholder.toLowerCase()
      return name.indexOf('2fa') >= 0 ||
        name.indexOf('otp') >= 0 ||
        name.indexOf('code') >= 0 ||
        placeholder.indexOf('2fa') >= 0 ||
        placeholder.indexOf('otp') >= 0 ||
        placeholder.indexOf('code') >= 0 ||
        placeholder.indexOf('验证码') >= 0 ||
        placeholder.indexOf('动态') >= 0 ||
        placeholder.indexOf('安全码') >= 0
    })
    // Only a field that POSITIVELY identifies as a 2FA code field counts. The former
    // "any single text input" fallback misclassified a node page's create-topic form (whose lone `title`
    // input became a fake code field) as a 2FA challenge, so logged-in users saw a spurious 2FA error
    // on nodes whose topics mention 2fa/两步/totp (e.g. Codex, 站点状态). Every real V2EX 2FA form names
    // its field `code`/`otp`, which the preferred check above already catches.
    return preferred ? preferred.name : ''
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

  private static inputContext(html: string, index: number, length: number): string {
    const start = V2exSigninParser.nearestContextStart(html, index)
    const end = V2exSigninParser.nearestContextEnd(html, index + length)
    if (start >= 0 && end > index) {
      return V2exSigninParser.compactText(html.slice(start, end))
    }
    const before = html.slice(Math.max(0, index - 64), index)
    const after = html.slice(index + length, Math.min(html.length, index + length + 64))
    return V2exSigninParser.compactText(`${before} ${after}`)
  }

  private static nearestContextStart(html: string, index: number): number {
    const prefix = html.slice(0, index)
    const matches = prefix.match(/<(tr|div|p|label)\b[^>]*>/gi)
    if (!matches || matches.length === 0) {
      return -1
    }
    return prefix.lastIndexOf(matches[matches.length - 1])
  }

  private static nearestContextEnd(html: string, index: number): number {
    const suffix = html.slice(index)
    const m = suffix.match(/<\/(tr|div|p|label)>/i)
    return m && typeof m.index === 'number' ? index + m.index + m[0].length : -1
  }

  private static compactText(html: string): string {
    return V2exSigninParser.decodeHtml(html.replace(/<[^>]+>/g, ' '))
      .replace(/\s+/g, ' ')
      .trim()
  }
}
