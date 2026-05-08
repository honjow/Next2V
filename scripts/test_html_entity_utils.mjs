#!/usr/bin/env node

function decodeHtmlEntities(value) {
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

const cases = [
  ['他说 &quot;可以&quot;，然后继续', '他说 "可以"，然后继续'],
  ['Tom &amp; Jerry', 'Tom & Jerry'],
  ['&amp;quot;double encoded&amp;quot;', '"double encoded"'],
  ['1 &lt; 2 &amp;&amp; 3 &gt; 2', '1 < 2 && 3 > 2'],
  ['A&nbsp;B&#160;C', 'A B C'],
  ['It&#39;s &apos;fine&apos;', "It's 'fine'"]
]

for (const [input, expected] of cases) {
  const actual = decodeHtmlEntities(input)
  if (actual !== expected) {
    console.error(`FAIL: ${input}\n  expected: ${expected}\n  actual:   ${actual}`)
    process.exit(1)
  }
}
console.log(`PASS: ${cases.length} HTML entity decode cases`)
