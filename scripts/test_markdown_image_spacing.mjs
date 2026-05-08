#!/usr/bin/env node

const IMAGE_BLOCK_MONO = 'customImageBlock'

function normalizeMarkdownSource(md) {
  return (md || '').replace(/!\[([^\]]*)\]\(\s+(https?:\/\/[^\s)]+)\s*\)/gi, '![$1]($2)')
}

function promoteStandaloneImageParagraphs(tokens) {
  for (let i = 0; i < tokens.length; i++) {
    const token = tokens[i]
    if (token.type === 'paragraph') {
      const inlineTokens = token.tokens || []
      const meaningful = inlineTokens.filter((t) => t && t.type !== 'br')
      if (meaningful.length > 0 && meaningful.every((t) => t.type === 'image')) {
        for (const imageToken of meaningful) imageToken.type = IMAGE_BLOCK_MONO
        tokens.splice(i, 1, ...meaningful)
        i += meaningful.length - 1
      }
    }
  }
}

const fixture = [
  '![pic_7.png]( https://iili.io/BtYjJwP.png)',
  '![pic_8.png]( https://iili.io/BtYjKPa.png)',
  '![pic_10.png]( https://iili.io/BtYglEB.png)',
  '',
  'normal text should stay unchanged',
  '![already_ok](https://example.com/a.png)'
].join('\n')

const actual = normalizeMarkdownSource(fixture)
const expected = [
  '![pic_7.png](https://iili.io/BtYjJwP.png)',
  '![pic_8.png](https://iili.io/BtYjKPa.png)',
  '![pic_10.png](https://iili.io/BtYglEB.png)',
  '',
  'normal text should stay unchanged',
  '![already_ok](https://example.com/a.png)'
].join('\n')

if (actual !== expected) {
  console.error('FAIL markdown image spacing normalization')
  console.error('expected:\n' + expected)
  console.error('actual:\n' + actual)
  process.exit(1)
}

const tokens = [{
  type: 'paragraph',
  tokens: [
    { type: 'image', href: 'https://iili.io/BtYjJwP.png', text: 'pic_7.png' },
    { type: 'br' },
    { type: 'image', href: 'https://iili.io/BtYjKPa.png', text: 'pic_8.png' },
    { type: 'br' },
    { type: 'image', href: 'https://iili.io/BtYglEB.png', text: 'pic_10.png' }
  ]
}]
promoteStandaloneImageParagraphs(tokens)
if (tokens.length !== 3 || !tokens.every((t) => t.type === IMAGE_BLOCK_MONO)) {
  console.error('FAIL multiple standalone image paragraph promotion')
  console.error(JSON.stringify(tokens, null, 2))
  process.exit(1)
}

console.log('PASS: markdown image destination spacing and multi-image promotion')
