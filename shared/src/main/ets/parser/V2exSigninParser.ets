export interface V2exSigninForm {
  usernameField: string
  passwordField: string
  once: string
  next: string
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

    const once = V2exSigninParser.extractHiddenValue(html, 'once')
    const next = V2exSigninParser.extractHiddenValue(html, 'next')
    const usernameField = V2exSigninParser.extractInputNameByType(html, 'text')
    const passwordField = V2exSigninParser.extractInputNameByType(html, 'password')

    if (!once || !next || !usernameField || !passwordField) {
      return null
    }

    return { usernameField, passwordField, once, next }
  }

  private static extractHiddenValue(html: string, name: string): string {
    const re1 = new RegExp(`name=['"]${name}['"][^>]*value=['"]([^'"]+)['"]`, 'i')
    const m1 = html.match(re1)
    if (m1 && m1[1]) {
      return m1[1]
    }
    const re2 = new RegExp(`value=['"]([^'"]+)['"][^>]*name=['"]${name}['"]`, 'i')
    const m2 = html.match(re2)
    return m2 && m2[1] ? m2[1] : ''
  }

  private static extractInputNameByType(html: string, inputType: string): string {
    const re = new RegExp(`<input[^>]*type=['"]${inputType}['"][^>]*name=['"]([^'"]+)['"]`, 'i')
    const m = html.match(re)
    return m && m[1] ? m[1] : ''
  }
}

