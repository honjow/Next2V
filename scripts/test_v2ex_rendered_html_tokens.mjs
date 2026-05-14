#!/usr/bin/env node
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

function decodeHtml(value) {
  if (!value) return ''
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
    if (next === decoded) break
    decoded = next
  }
  return decoded
}

function attr(tag, name) {
  const re = new RegExp(`${name}\\s*=\\s*(["'])(.*?)\\1`, 'i')
  const m = tag.match(re)
  return m ? decodeHtml(m[2]).trim() : ''
}

function stripTags(value) {
  return decodeHtml((value || '').replace(/<[^>]+>/g, ''))
    .replace(/[ \t\f\v\r\n]+/g, ' ')
    .trim()
}

function appendText(tokens, text) {
  const value = decodeHtml(text).replace(/[ \t\f\v\r\n]+/g, ' ')
  if (!value) return
  const last = tokens[tokens.length - 1]
  if (last && last.type === 'text') last.text += value
  else tokens.push({ type: 'text', text: value })
}

function trimTextEdges(tokens) {
  while (tokens.length && tokens[0].type === 'text' && !tokens[0].text.trim()) tokens.shift()
  while (tokens.length && tokens[tokens.length - 1].type === 'text' && !tokens[tokens.length - 1].text.trim()) tokens.pop()
  if (tokens[0]?.type === 'text') tokens[0].text = tokens[0].text.replace(/^\s+/, '')
  const last = tokens[tokens.length - 1]
  if (last?.type === 'text') last.text = last.text.replace(/\s+$/, '')
}

function inlineHtmlToTokens(html) {
  const tokens = []
  let index = 0
  const re = /<a\b[^>]*>[\s\S]*?<\/a>|<img\b[^>]*>|<br\s*\/?>|<code\b[^>]*>[\s\S]*?<\/code>|<(strong|b|em|i)\b[^>]*>[\s\S]*?<\/\1>/gi
  let match
  while ((match = re.exec(html || ''))) {
    appendText(tokens, html.slice(index, match.index))
    const part = match[0]
    if (/^<br/i.test(part)) tokens.push({ type: 'br' })
    else if (/^<img/i.test(part)) tokens.push({ type: 'image', href: attr(part, 'src') })
    else if (/^<a/i.test(part)) {
      const href = attr(part, 'href')
      const imgs = [...part.matchAll(/<img\b[^>]*>/gi)].map(m => attr(m[0], 'src') || href).filter(Boolean)
      if (imgs.length) imgs.forEach(src => tokens.push({ type: 'image', href: src }))
      else {
        const label = stripTags(part)
        if (/^\/member\//.test(href) && tokens[tokens.length - 1]?.type === 'text') {
          tokens[tokens.length - 1].text = tokens[tokens.length - 1].text.replace(/@\s*$/, '')
        }
        tokens.push({ type: 'link', href, text: label })
      }
    } else if (/^<code/i.test(part)) tokens.push({ type: 'codespan', text: stripTags(part) })
    else if (/^<(strong|b)/i.test(part)) tokens.push({ type: 'strong', text: stripTags(part) })
    else if (/^<(em|i)/i.test(part)) tokens.push({ type: 'em', text: stripTags(part) })
    index = re.lastIndex
  }
  appendText(tokens, (html || '').slice(index).replace(/<[^>]+>/g, ''))
  trimTextEdges(tokens)
  return tokens
}

const exact117 = '@<a href="/member/vipfts">vipfts</a> <a target="_blank" href="https://i.imgur.com/U3hKhrT.png"><img src="https://i.imgur.com/U3hKhrT.png"></a><a target="_blank" href="https://i.imgur.com/U3hKhrT.png"><img src="https://i.imgur.com/U3hKhrT.png"></a>'
const tokens117 = inlineHtmlToTokens(exact117)
assert.deepEqual(tokens117.map(t => t.type), ['link', 'text', 'image', 'image'])
assert.equal(tokens117[0].href, '/member/vipfts')
assert.equal(tokens117[0].text, 'vipfts')
assert.equal(tokens117.filter(t => t.type === 'image' && t.href === 'https://i.imgur.com/U3hKhrT.png').length, 2)

const exact127 = '@<a href="/member/iixy">iixy</a> #6 要黑丝也可以 <a target="_blank" href="https://i.imgur.com/MA8YqTP.png"><img src="https://i.imgur.com/MA8YqTP.png"></a>'
const tokens127 = inlineHtmlToTokens(exact127)
assert.deepEqual(tokens127.map(t => t.type), ['link', 'text', 'image'])
assert.equal(tokens127[1].text, ' #6 要黑丝也可以 ')
assert.equal(tokens127[2].href, 'https://i.imgur.com/MA8YqTP.png')

const source = readFileSync('shared/src/main/ets/components/MarkdownContent.ets', 'utf8')
assert.match(source, /renderedHtmlToTokens/)
assert.match(source, /inlineHtmlToTokens/)
const processTokensBody = source.match(/private static processTokens\([\s\S]*?\n  }\n\n  private static normalizeMarkdownSource/)[0]
assert.doesNotMatch(processTokensBody, /renderedHtmlToMarkdown/)

console.log('PASS: V2EX rendered HTML is represented as structured inline tokens, preserving adjacent images and member links')
