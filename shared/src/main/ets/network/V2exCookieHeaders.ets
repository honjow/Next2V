// Header-only session handling for the existing first-party Cookie transport.
// Preserve response order: A -> B -> A must finish at A, even across redirects.
export class V2exCookieHeaders {
  static extract(headers: Object): string[] {
    const bag = headers as Record<string, Object>
    const key = Object.keys(bag).find((name: string) => name.toLowerCase() === 'set-cookie')
    if (!key) { return [] }
    const value = bag[key]
    const values: string[] = typeof value === 'string' ? [value] :
      (Array.isArray(value) ? value.filter((item: Object) => typeof item === 'string') as string[] : [])
    const lines: string[] = []
    for (const item of values) {
      lines.push(...item.split(/,(?=\s*[^;,=\s]+=[^;]*)/g).map((line: string) => line.trim()).filter((line: string) => !!line))
    }
    return lines
  }

  static merge(existing: string, lines: string[], now: number = Date.now()): string {
    const jar: Map<string, string> = new Map<string, string>()
    for (const part of existing.split(';')) {
      const index = part.indexOf('=')
      if (index > 0) { jar.set(part.slice(0, index).trim(), part.slice(index + 1).trim()) }
    }
    for (const line of lines) {
      const parts = line.split(';')
      const index = parts[0].indexOf('=')
      if (index <= 0) { continue }
      const name = parts[0].slice(0, index).trim()
      const value = parts[0].slice(index + 1).trim()
      let maxAge: number | undefined = undefined
      let expires: number = NaN
      for (const attribute of parts.slice(1)) {
        const separator = attribute.indexOf('=')
        if (separator < 0) { continue }
        const key = attribute.slice(0, separator).trim().toLowerCase()
        const content = attribute.slice(separator + 1).trim()
        if (key === 'max-age' && /^-?\d+$/.test(content)) { maxAge = Number(content) }
        if (key === 'expires') { expires = Date.parse(content) }
      }
      // Max-Age takes precedence over Expires, including a positive Max-Age.
      if (maxAge !== undefined ? maxAge <= 0 : Number.isFinite(expires) && expires <= now) {
        jar.delete(name)
      } else {
        jar.set(name, value)
      }
    }
    const result: string[] = []
    jar.forEach((value: string, name: string) => result.push(`${name}=${value}`))
    return result.join('; ')
  }
}
