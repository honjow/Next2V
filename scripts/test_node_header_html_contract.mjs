// Contract for V2EX node-header HTML parsing (NodeHeaderHtml) and its rendering in NodeInfoCard.
//
// Two layers:
//   1. LOGIC MIRROR — a JS port of NodeHeaderHtml.parse() exercised on the real V2EX samples
//      (design / qna / a link node). If you change the .ets algorithm, mirror it here.
//   2. STATIC — assert the .ets files actually implement that algorithm and render runs as styled
//      Span()s with tappable links, instead of dumping raw header markup as plain text.

import { readFileSync } from 'node:fs'

let failures = 0
function check(name, cond) {
  console.log(`${cond ? 'ok  ' : 'FAIL'} ${name}`)
  if (!cond) failures++
}

// ---- LOGIC MIRROR (kept in lockstep with NodeHeaderHtml.ets) ----
function decode(value) {
  let d = value
  for (let i = 0; i < 2; i++) {
    const n = d
      .replace(/&quot;/g, '"').replace(/&#39;/g, "'").replace(/&apos;/g, "'")
      .replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&nbsp;/g, ' ').replace(/&amp;/g, '&')
    if (n === d) break
    d = n
  }
  return d
}
function parse(raw) {
  const html = (raw || '').replace(/<!--[\s\S]*?-->/g, '')
  if (html.trim().length === 0) return []
  const runs = []
  let bold = 0, italic = 0, mono = 0, href = '', buffer = '', i = 0
  const push = () => {
    if (buffer.length === 0) return
    const t = decode(buffer)
    if (t.length === 0) { buffer = ''; return }
    runs.push({ text: t, bold: bold > 0, italic: italic > 0, mono: mono > 0, href })
    buffer = ''
  }
  while (i < html.length) {
    const lt = html.indexOf('<', i)
    if (lt < 0) { buffer += html.substring(i); break }
    buffer += html.substring(i, lt)
    const gt = html.indexOf('>', lt)
    if (gt < 0) { buffer += html.substring(lt); break }
    push()
    const tag = html.substring(lt, gt + 1)
    const lower = tag.toLowerCase()
    const isClose = lower.startsWith('</')
    const nm = (lower.match(/^<\/?\s*([a-z0-9]+)/) || [])[1] || ''
    if (nm === 'strong' || nm === 'b') bold = isClose ? Math.max(0, bold - 1) : bold + 1
    else if (nm === 'em' || nm === 'i') italic = isClose ? Math.max(0, italic - 1) : italic + 1
    else if (nm === 'code') mono = isClose ? Math.max(0, mono - 1) : mono + 1
    else if (nm === 'a') href = isClose ? '' : ((tag.match(/href\s*=\s*["']([^"']*)["']/i) || [])[1] || '')
    else if (nm === 'br') buffer += ' '
    i = gt + 1
  }
  push()
  return runs
}
function plain(raw) { return parse(raw).map((r) => r.text).join('').trim() }

// design node: inline strong / code / em
const design = '<strong>Beautiful</strong> <code>adj.</code> <em>Pleasing the senses or mind aesthetically.</em>'
const dRuns = parse(design)
check('design: strong → bold run "Beautiful"', dRuns.some((r) => r.text === 'Beautiful' && r.bold))
check('design: code → mono run "adj."', dRuns.some((r) => r.text === 'adj.' && r.mono))
check('design: em → italic run', dRuns.some((r) => r.italic && r.text.includes('Pleasing')))
check('design: no run carries a tag character', dRuns.every((r) => !r.text.includes('<') && !r.text.includes('>')))

// qna node: the whole description is an HTML comment → nothing to show
const qna = '<!--\n一个更好的世界需要你持续地提出好问题。\n-->'
check('qna: commented-out header → no runs', parse(qna).length === 0)
check('qna: commented-out header → empty plain text', plain(qna) === '')

// a link node: <a href> becomes a tappable run carrying the href
const link = 'See <a href="https://example.com/docs">docs</a> here'
const lRuns = parse(link)
const linkRun = lRuns.find((r) => r.text === 'docs')
check('link: anchor text becomes its own run', !!linkRun)
check('link: run carries the href', !!linkRun && linkRun.href === 'https://example.com/docs')
check('link: plain text outside the anchor has no href', lRuns.some((r) => r.text.includes('See') && r.href === ''))

// entity decoding still applies
check('entities decoded (&amp; → &)', plain('Tips &amp; tricks') === 'Tips & tricks')

// ---- STATIC: the .ets implementation matches the mirrored algorithm ----
const parser = readFileSync('shared/src/main/ets/utils/NodeHeaderHtml.ets', 'utf8')
check('ets: strips HTML comments', parser.includes('<!--[\\s\\S]*?-->'))
check('ets: handles strong/b', parser.includes("'strong'") && parser.includes("'b'"))
check('ets: handles em/i', parser.includes("'em'") && parser.includes("'i'"))
check('ets: handles code', parser.includes("'code'"))
check('ets: handles a + extractHref', parser.includes("'a'") && parser.includes('extractHref'))
check('ets: decodes entities via HtmlEntityUtils', parser.includes('HtmlEntityUtils.decode'))
check('ets: exports parse() and NodeHeaderRun', parser.includes('static parse(') && parser.includes('interface NodeHeaderRun'))

const card = readFileSync('feature/node/src/main/ets/components/NodeInfoCard.ets', 'utf8')
check('card: no longer dumps raw header as plain text', !card.includes('Text(this.headerText())'))
check('card: parses header via NodeHeaderHtml', card.includes('NodeHeaderHtml.parse'))
check('card: renders styled Span runs', card.includes('Span(run.text)') && card.includes('ForEach(') && card.includes('this.headerRuns()'))
check('card: link runs are tappable → openHeaderLink', card.includes('.onClick(') && card.includes('openHeaderLink'))
check('card: opens link externally or via override', card.includes('startAbility') && card.includes('onHeaderLinkClick'))

const barrel = readFileSync('shared/src/main/ets/Index.ets', 'utf8')
check('barrel: exports NodeHeaderHtml + NodeHeaderRun', barrel.includes('NodeHeaderHtml') && barrel.includes('NodeHeaderRun'))

console.log(`\nnode-header-html contract: ${failures} failure(s)`)
process.exit(failures === 0 ? 0 : 1)
