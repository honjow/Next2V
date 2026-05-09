#!/usr/bin/env node

const BASE_URL_COM = 'https://www.v2ex.com';

function preferLargeAvatar(path, size = 'xlarge') {
  return (path || '')
    .replace(/_(?:mini|normal)(\.\w+)([?#].*)?$/, `_${size}$1$2`)
    .replace(/\/(?:mini|normal)(\.\w+)([?#].*)?$/, '/large$1$2');
}

function avatarUrl(path, size = 'xlarge') {
  if (!path) {
    return '';
  }
  const source = preferLargeAvatar(path, size);
  if (source.startsWith('//')) {
    return `https:${source}`;
  }
  if (source.startsWith('http')) {
    return source;
  }
  return `${BASE_URL_COM}${source}`;
}

const cases = [
  ['', ''],
  ['//cdn.v2ex.com/avatar/4_mini.png?m=1', 'https://cdn.v2ex.com/avatar/4_xlarge.png?m=1'],
  ['//cdn.v2ex.com/avatar/4_normal.png?m=1#avatar', 'https://cdn.v2ex.com/avatar/4_xlarge.png?m=1#avatar'],
  ['https://cdn.v2ex.com/avatar/4_mini.webp#m=1', 'https://cdn.v2ex.com/avatar/4_xlarge.webp#m=1'],
  ['https://cdn.v2ex.com/avatar/4_mini.png', 'https://cdn.v2ex.com/avatar/4_xlarge.png'],
  ['/avatar/4_normal.png?m=1776071517', 'https://www.v2ex.com/avatar/4_xlarge.png?m=1776071517'],
  ['//cdn.v2ex.com/avatar/mini.png?m=1', 'https://cdn.v2ex.com/avatar/large.png?m=1'],
  ['//cdn.v2ex.com/avatar/normal.png#m=1', 'https://cdn.v2ex.com/avatar/large.png#m=1'],
  ['/avatar/normal.jpg?m=1#avatar', 'https://www.v2ex.com/avatar/large.jpg?m=1#avatar'],
  ['https://cdn.v2ex.com/avatar/4_xlarge.png?m=1', 'https://cdn.v2ex.com/avatar/4_xlarge.png?m=1'],
];

let failed = 0;
for (const [input, expected] of cases) {
  const actual = avatarUrl(input);
  if (actual !== expected) {
    failed += 1;
    console.error(`FAIL ${input}`);
    console.error(`  expected ${expected}`);
    console.error(`  actual   ${actual}`);
  }
}

if (failed > 0) {
  process.exit(1);
}
console.log(`Avatar URL rules OK (${cases.length} cases)`);
