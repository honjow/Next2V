import { HtmlEntityUtils } from './HtmlEntityUtils'

/**
 * One styled text run parsed from a V2EX node `header`. A node header is a tiny HTML snippet, not
 * plain text: it may carry inline tags (<strong>/<em>/<code>), an <a> link, or be entirely an HTML
 * comment. Parsing it into runs lets NodeInfoCard render real bold/italic/mono styling and a tappable
 * link via Text { Span... } instead of dumping raw markup on screen.
 */
export interface NodeHeaderRun {
  text: string
  bold: boolean
  italic: boolean
  mono: boolean
  href: string
}

/**
 * Minimal inline-HTML parser for V2EX node headers. It is deliberately small (no DOM library, like
 * the rest of shared/parser): it strips comments, walks tag boundaries tracking <strong>/<em>/<code>
 * nesting and the current <a href>, decodes entities, and drops every other tag while keeping its
 * text. Observed inputs this handles:
 *  - 设计:   `<strong>Beautiful</strong> <code>adj.</code> <em>...</em>`  → bold / mono / italic runs
 *  - 问与答: `<!-- ... -->`                                              → comment only → no runs
 *  - link nodes: `... <a href="https://...">text</a> ...`               → a tappable link run
 */
export class NodeHeaderHtml {
  static parse(rawHtml: string): NodeHeaderRun[] {
    // HTML comments are not content: V2EX uses them to "comment out" a node description entirely
    // (问与答 hides its line this way). Stripping them first makes such headers resolve to empty,
    // so the card hides the description row instead of printing the comment text.
    const html = (rawHtml || '').replace(/<!--[\s\S]*?-->/g, '')
    if (html.trim().length === 0) {
      return []
    }
    const runs: NodeHeaderRun[] = []
    let bold = 0
    let italic = 0
    let mono = 0
    let href = ''
    let buffer = ''
    let i = 0
    const len = html.length
    while (i < len) {
      const lt = html.indexOf('<', i)
      if (lt < 0) {
        buffer += html.substring(i)
        break
      }
      buffer += html.substring(i, lt)
      const gt = html.indexOf('>', lt)
      if (gt < 0) {
        // Unterminated '<': treat the remainder as literal text.
        buffer += html.substring(lt)
        break
      }
      // A tag boundary ends the current run, so emit what we have under the current style first.
      NodeHeaderHtml.pushRun(runs, buffer, bold, italic, mono, href)
      buffer = ''
      const tag = html.substring(lt, gt + 1)
      const lower = tag.toLowerCase()
      const isClose = lower.startsWith('</')
      const name = NodeHeaderHtml.tagName(lower)
      if (name === 'strong' || name === 'b') {
        bold = isClose ? Math.max(0, bold - 1) : bold + 1
      } else if (name === 'em' || name === 'i') {
        italic = isClose ? Math.max(0, italic - 1) : italic + 1
      } else if (name === 'code') {
        mono = isClose ? Math.max(0, mono - 1) : mono + 1
      } else if (name === 'a') {
        href = isClose ? '' : NodeHeaderHtml.extractHref(tag)
      } else if (name === 'br') {
        // Collapse a line break into a space; the header renders as a short flowing line.
        buffer += ' '
      }
      // Any other tag is dropped while its text content is preserved.
      i = gt + 1
    }
    NodeHeaderHtml.pushRun(runs, buffer, bold, italic, mono, href)
    return runs
  }

  // Concatenated decoded text with surrounding whitespace trimmed; '' means "nothing to show".
  static plainText(rawHtml: string): string {
    const runs = NodeHeaderHtml.parse(rawHtml)
    let text = ''
    for (const run of runs) {
      text += run.text
    }
    return text.trim()
  }

  private static pushRun(
    runs: NodeHeaderRun[],
    buffer: string,
    bold: number,
    italic: number,
    mono: number,
    href: string,
  ): void {
    if (buffer.length === 0) {
      return
    }
    const text = HtmlEntityUtils.decode(buffer)
    if (text.length === 0) {
      return
    }
    runs.push({ text: text, bold: bold > 0, italic: italic > 0, mono: mono > 0, href: href })
  }

  private static tagName(lowerTag: string): string {
    const matched = lowerTag.match(/^<\/?\s*([a-z0-9]+)/)
    return matched && matched[1] ? matched[1] : ''
  }

  private static extractHref(tag: string): string {
    const matched = tag.match(/href\s*=\s*["']([^"']*)["']/i)
    if (!matched || !matched[1]) {
      return ''
    }
    return HtmlEntityUtils.decode(matched[1]).trim()
  }
}
