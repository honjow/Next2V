// V2EX content blocks (topic_content / reply_content) may nest divs — notably
// the embedded_video_wrapper around provider iframes. Lazy ([\s\S]*?)</div>
// regex extraction truncates at the first close tag, leaving an unclosed
// wrapper that downstream parsing strips, silently dropping the embed. Block
// extraction must walk div nesting instead.
export class HtmlBlockUtils {
  /** Inner HTML of the first <div> whose class attribute contains className. */
  static extractDivInnerByClass(html: string, className: string): string {
    const source = html || ''
    const openRe = new RegExp(`<div[^>]*class=['"][^'"]*\\b${className}\\b[^'"]*['"][^>]*>`, 'i')
    const open = openRe.exec(source)
    if (!open) {
      return ''
    }
    const start = open.index + open[0].length
    const divRe = new RegExp('</?div\\b[^>]*>', 'gi')
    divRe.lastIndex = start
    let depth = 1
    let tag: RegExpExecArray | null = divRe.exec(source)
    while (tag) {
      depth += tag[0].charAt(1) === '/' ? -1 : 1
      if (depth === 0) {
        return source.slice(start, tag.index)
      }
      tag = divRe.exec(source)
    }
    // Unbalanced markup: keep the tail rather than dropping content.
    return source.slice(start)
  }
}
