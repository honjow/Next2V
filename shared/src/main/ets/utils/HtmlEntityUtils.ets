export class HtmlEntityUtils {
  static decode(value: string): string {
    if (!value) {
      return ''
    }
    let decoded = value
    for (let i = 0; i < 2; i++) {
      const next = decoded
        .replace(/&quot;/g, '"')
        .replace(/&#34;/g, '"')
        .replace(/&#x22;/gi, '"')
        .replace(/&#39;/g, "'")
        .replace(/&#x27;/gi, "'")
        .replace(/&apos;/g, "'")
        .replace(/&lt;/g, '<')
        .replace(/&#60;/g, '<')
        .replace(/&#x3c;/gi, '<')
        .replace(/&gt;/g, '>')
        .replace(/&#62;/g, '>')
        .replace(/&#x3e;/gi, '>')
        .replace(/&nbsp;/g, ' ')
        .replace(/&#160;/g, ' ')
        .replace(/&#xa0;/gi, ' ')
        .replace(/&amp;/g, '&')
      if (next === decoded) {
        break
      }
      decoded = next
    }
    return decoded
  }
}
