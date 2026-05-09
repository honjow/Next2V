#!/usr/bin/env node

const BASE_URL_COM = 'https://www.v2ex.com';

function preferLargeAvatar(path, size = 'large') {
  return (path || '')
    .replace(/_(?:mini|normal)(\.\w+)([?#].*)?$/, `_${size}$1$2`)
    .replace(/\/(?:mini|normal)(\.\w+)([?#].*)?$/, '/large$1$2');
}

function avatarUrl(path, size = 'large') {
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

function memberAvatarSource(member, preferred = 'xlarge') {
  if (preferred === 'xxxlarge' && member.avatar_xxxlarge) {
    return member.avatar_xxxlarge;
  }
  if ((preferred === 'xxxlarge' || preferred === 'xxlarge') && member.avatar_xxlarge) {
    return member.avatar_xxlarge;
  }
  if (preferred !== 'large' && member.avatar_xlarge) {
    return member.avatar_xlarge;
  }
  return member.avatar_large || member.avatar_normal || member.avatar_mini || '';
}

function memberAvatarUrl(member, preferred = 'xlarge') {
  if (!member) {
    return '';
  }
  return avatarUrl(memberAvatarSource(member, preferred));
}

const cases = [
  ['empty path', () => avatarUrl(''), ''],
  [
    'API member with xlarge selects API-provided xlarge',
    () => memberAvatarUrl({
      avatar_mini: '//cdn.v2ex.com/avatar/4_mini.png?m=1',
      avatar_normal: '//cdn.v2ex.com/avatar/4_normal.png?m=1',
      avatar_large: '//cdn.v2ex.com/avatar/4_large.png?m=1',
      avatar_xlarge: '//cdn.v2ex.com/avatar/4_xlarge.png?m=1',
    }),
    'https://cdn.v2ex.com/avatar/4_xlarge.png?m=1',
  ],
  [
    'API member without xlarge selects large, not guessed xlarge',
    () => memberAvatarUrl({
      avatar_mini: '//cdn.v2ex.com/avatar/43242_mini.png?m=1',
      avatar_normal: '//cdn.v2ex.com/avatar/43242_normal.png?m=1',
      avatar_large: '//cdn.v2ex.com/avatar/43242_large.png?m=1',
    }),
    'https://cdn.v2ex.com/avatar/43242_large.png?m=1',
  ],
  [
    'reply-style member only mini/normal/large selects large',
    () => memberAvatarUrl({
      avatar_mini: '/avatar/4_mini.png',
      avatar_normal: '/avatar/4_normal.png',
      avatar_large: '/avatar/4_large.png',
    }),
    'https://www.v2ex.com/avatar/4_large.png',
  ],
  [
    'generic avatarUrl no longer produces xlarge by default for normal input',
    () => avatarUrl('//cdn.v2ex.com/avatar/4_normal.png?m=1#avatar'),
    'https://cdn.v2ex.com/avatar/4_large.png?m=1#avatar',
  ],
  [
    'query/hash preserved for safe large upgrade',
    () => avatarUrl('/avatar/4_normal.png?m=1776071517#avatar'),
    'https://www.v2ex.com/avatar/4_large.png?m=1776071517#avatar',
  ],
  [
    'generic explicit xlarge opt-in still works',
    () => avatarUrl('//cdn.v2ex.com/avatar/4_normal.png?m=1', 'xlarge'),
    'https://cdn.v2ex.com/avatar/4_xlarge.png?m=1',
  ],
  [
    'gravatar large URL and s query preserved',
    () => avatarUrl('https://secure.gravatar.com/avatar/abc123?s=73&d=retro'),
    'https://secure.gravatar.com/avatar/abc123?s=73&d=retro',
  ],
  [
    'directory-style mini safely upgrades to large and preserves query',
    () => avatarUrl('//cdn.v2ex.com/avatar/mini.png?m=1'),
    'https://cdn.v2ex.com/avatar/large.png?m=1',
  ],
];

let failed = 0;
for (const [name, run, expected] of cases) {
  const actual = run();
  if (actual !== expected) {
    failed += 1;
    console.error(`FAIL ${name}`);
    console.error(`  expected ${expected}`);
    console.error(`  actual   ${actual}`);
  }
}

if (failed > 0) {
  process.exit(1);
}
console.log(`Avatar URL rules OK (${cases.length} cases)`);
