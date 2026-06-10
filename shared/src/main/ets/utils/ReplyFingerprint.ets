import { HtmlEntityUtils } from './HtmlEntityUtils'

// Content fingerprint for matching "the reply a notification points at" against the
// replies actually loaded in a topic. V2EX's thanks/mention notifications carry a
// #reply{N} anchor that is sometimes WRONG (it can point at an unrelated floor), so we
// fall back to matching the reply text itself. The two sides reach us in different
// shapes — a notification's reply_content is already plain text (tags collapsed to
// spaces, images turned into a placeholder word), while a topic reply is raw Markdown
// or rendered HTML — so normalize aggressively to a shape that survives both:
// strip tags, decode entities, drop image/link markup and bare URLs, then remove ALL
// whitespace (so "@ Justin13" and "@Justin13" collapse to the same token) and lowercase.
export class ReplyFingerprint {
  private static readonly MIN_FINGERPRINT_LENGTH: number = 4

  static normalize(value: string): string {
    let s = value || ''
    s = s.replace(/<[^>]+>/g, ' ')
    s = HtmlEntityUtils.decode(s)
    s = s.replace(/!\[[^\]]*\]\([^)]*\)/g, ' ') // markdown image -> gone
    s = s.replace(/\[([^\]]*)\]\([^)]*\)/g, '$1') // markdown link -> its label
    s = s.replace(/https?:\/\/[^\s)]+/gi, ' ') // bare urls -> gone
    s = s.replace(/\s+/g, '') // drop every whitespace run (incl. decoded &nbsp;)
    return s.toLowerCase()
  }

  // True when the two texts describe the same reply. Uses bidirectional containment so a
  // trailing image placeholder on one side (e.g. notification "…能力了图片" vs reply
  // "…能力了") still matches on the shared body. Very short fingerprints require equality
  // to avoid a stray token matching everything.
  static matches(a: string, b: string): boolean {
    const na = ReplyFingerprint.normalize(a)
    const nb = ReplyFingerprint.normalize(b)
    if (!na || !nb) {
      return false
    }
    if (
      na.length < ReplyFingerprint.MIN_FINGERPRINT_LENGTH ||
      nb.length < ReplyFingerprint.MIN_FINGERPRINT_LENGTH
    ) {
      return na === nb
    }
    return na.indexOf(nb) >= 0 || nb.indexOf(na) >= 0
  }
}
