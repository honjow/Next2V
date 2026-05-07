#!/usr/bin/env node

const IMAGE_EXT_REGEX = /\.(jpe?g|png|gif|webp|bmp|svg|avif|heic|heif)(?:[?#].*)?$/i;
const IMAGE_QUERY_EXT_REGEX = /[?&](?:format|fm|ext|type|output)=([a-z0-9/]+)/i;
const IMGUR_SINGLE_IMAGE_PAGE_REGEX = /^https?:\/\/(?:www\.)?imgur\.com\/([A-Za-z0-9]{5,12})(?:[?#].*)?$/i;
const IMGUR_COLLECTION_PAGE_REGEX = /^https?:\/\/(?:www\.)?imgur\.com\/(?:gallery|a)\//i;

const IMAGE_HOST_PREFIXES = [
  'https://i.imgur.com/',
  'http://i.imgur.com/',
  'https://sm.ms/',
  'http://sm.ms/',
  'https://s2.loli.net/',
  'http://s2.loli.net/',
  'https://v2ex.assets.uxengine.net/',
  'http://v2ex.assets.uxengine.net/',
  'https://i.v2ex.co/',
  'http://i.v2ex.co/',
  'https://i.v2ex.com/',
  'http://i.v2ex.com/',
  'https://raw.githubusercontent.com/',
  'http://raw.githubusercontent.com/',
  'https://pbs.twimg.com/media/',
  'http://pbs.twimg.com/media/',
  'https://github.com/user-attachments/assets/',
  'http://github.com/user-attachments/assets/',
];

function normalizeUrl(raw) {
  const url = (raw ?? '').trim();
  if (!url) {
    return '';
  }
  if (url.startsWith('//')) {
    return `https:${url}`;
  }
  return url;
}

function normalizeImageExtension(raw) {
  let ext = (raw || '').toLowerCase().trim();
  if (ext.includes('/')) {
    ext = ext.split('/').pop() || '';
  }
  if (ext === 'jpeg' || ext === 'jpg') {
    return 'jpg';
  }
  return ['png', 'gif', 'webp', 'bmp', 'svg', 'avif', 'heic', 'heif'].includes(ext) ? ext : '';
}

function imageExtensionFromUrl(raw) {
  const clean = normalizeUrl(raw).split('#')[0];
  const queryMatch = clean.match(IMAGE_QUERY_EXT_REGEX);
  const queryExt = normalizeImageExtension(queryMatch?.[1] || '');
  if (queryExt) {
    return queryExt;
  }
  const path = clean.split('?')[0];
  const match = path.match(/\.([a-z0-9]+)$/i);
  return normalizeImageExtension(match?.[1] || '');
}

function isHttpUrl(raw) {
  const url = normalizeUrl(raw);
  return url.startsWith('http://') || url.startsWith('https://');
}

function hostFromUrl(raw) {
  const match = normalizeUrl(raw).match(/^https?:\/\/([^/?#]+)/i);
  return (match?.[1] || '').toLowerCase();
}

function isHostOrSubdomain(host, domain) {
  return host === domain || host.endsWith(`.${domain}`);
}

function resolveImgurSingleImagePage(url) {
  if (IMGUR_COLLECTION_PAGE_REGEX.test(url)) {
    return '';
  }
  const match = url.match(IMGUR_SINGLE_IMAGE_PAGE_REGEX);
  return match?.[1] ? `https://i.imgur.com/${match[1]}.png` : '';
}

function isProbeCandidate(url) {
  const host = hostFromUrl(url);
  return Boolean(host) &&
    !isHostOrSubdomain(host, 'github.com') &&
    !isHostOrSubdomain(host, 'youtube.com') &&
    !isHostOrSubdomain(host, 'youtu.be') &&
    !isHostOrSubdomain(host, 'vimeo.com') &&
    !isHostOrSubdomain(host, 'v2ex.com') &&
    !isHostOrSubdomain(host, 'v2ex.co');
}

function resolveMediaUrl(raw) {
  const originalUrl = (raw ?? '').trim();
  const normalizedUrl = normalizeUrl(originalUrl);
  if (!normalizedUrl || !isHttpUrl(normalizedUrl)) {
    return { kind: 'unsupported', renderUrl: normalizedUrl, isImage: false, shouldProbe: false };
  }
  if (IMAGE_EXT_REGEX.test(normalizedUrl) || imageExtensionFromUrl(normalizedUrl)) {
    return { kind: 'directImage', renderUrl: normalizedUrl, isImage: true, shouldProbe: false };
  }
  if (IMAGE_HOST_PREFIXES.some((prefix) => normalizedUrl.startsWith(prefix))) {
    return { kind: 'knownImageHostDirect', renderUrl: normalizedUrl, isImage: true, shouldProbe: false };
  }
  const imgurDirect = resolveImgurSingleImagePage(normalizedUrl);
  if (imgurDirect) {
    return { kind: 'imageHostPageResolved', renderUrl: imgurDirect, isImage: true, shouldProbe: false };
  }
  if (IMGUR_COLLECTION_PAGE_REGEX.test(normalizedUrl)) {
    return { kind: 'nonImageLink', renderUrl: normalizedUrl, isImage: false, shouldProbe: false };
  }
  if (isProbeCandidate(normalizedUrl)) {
    return { kind: 'probeRequired', renderUrl: normalizedUrl, isImage: false, shouldProbe: true };
  }
  return { kind: 'nonImageLink', renderUrl: normalizedUrl, isImage: false, shouldProbe: false };
}

const cases = [
  ['https://example.com/a.jpg', 'directImage', 'https://example.com/a.jpg', true, false],
  ['https://example.com/a?format=webp', 'directImage', 'https://example.com/a?format=webp', true, false],
  ['https://i.imgur.com/abc123.jpg', 'directImage', 'https://i.imgur.com/abc123.jpg', true, false],
  ['https://imgur.com/abc123', 'imageHostPageResolved', 'https://i.imgur.com/abc123.png', true, false],
  ['https://imgur.com/a/abc123', 'nonImageLink', 'https://imgur.com/a/abc123', false, false],
  ['https://github.com/org/repo', 'nonImageLink', 'https://github.com/org/repo', false, false],
  ['https://raw.githubusercontent.com/org/repo/main/image', 'knownImageHostDirect', 'https://raw.githubusercontent.com/org/repo/main/image', true, false],
  ['https://example.com/download/123', 'probeRequired', 'https://example.com/download/123', false, true],
];

let failed = 0;
for (const [url, kind, renderUrl, isImage, shouldProbe] of cases) {
  const actual = resolveMediaUrl(url);
  const ok = actual.kind === kind &&
    actual.renderUrl === renderUrl &&
    actual.isImage === isImage &&
    actual.shouldProbe === shouldProbe;
  if (!ok) {
    failed += 1;
    console.error(`FAIL ${url}`);
    console.error(`  expected ${JSON.stringify({ kind, renderUrl, isImage, shouldProbe })}`);
    console.error(`  actual   ${JSON.stringify(actual)}`);
  }
}

if (failed > 0) {
  process.exit(1);
}
console.log(`Media URL rules OK (${cases.length} cases)`);
