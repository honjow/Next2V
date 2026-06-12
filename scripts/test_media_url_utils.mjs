#!/usr/bin/env node

const IMAGE_EXT_REGEX = /\.(jpe?g|png|gif|webp|bmp|svg|avif|heic|heif)(?:[?#].*)?$/i;
const VIDEO_EXT_REGEX = /\.(mp4|webm|mov|m4v|m3u8)(?:[?#].*)?$/i;
const MEDIA_QUERY_EXT_REGEX = /(?:[?&]|&amp;)(?:format|fm|ext|type|output|wx_fmt)=([a-z0-9/]+)/i;
const GITHUB_FILE_IMAGE_PAGE_REGEX = /^https?:\/\/(?:www\.)?github\.com\/([^/?#]+)\/([^/?#]+)\/(?:blob|raw)\/([^?#]+)(?:[?#].*)?$/i;
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
  const queryMatch = clean.match(MEDIA_QUERY_EXT_REGEX);
  const queryExt = normalizeImageExtension(queryMatch?.[1] || '');
  if (queryExt) {
    return queryExt;
  }
  const path = clean.split('?')[0];
  const match = path.match(/\.([a-z0-9]+)$/i);
  return normalizeImageExtension(match?.[1] || '');
}

function normalizeVideoExtension(raw) {
  let ext = (raw || '').toLowerCase().trim();
  if (ext.includes('/')) {
    ext = ext.split('/').pop() || '';
  }
  return ['mp4', 'webm', 'mov', 'm4v', 'm3u8'].includes(ext) ? ext : '';
}

function videoExtensionFromUrl(raw) {
  const clean = normalizeUrl(raw).split('#')[0];
  const queryMatch = clean.match(MEDIA_QUERY_EXT_REGEX);
  const queryExt = normalizeVideoExtension(queryMatch?.[1] || '');
  if (queryExt) {
    return queryExt;
  }
  const path = clean.split('?')[0];
  const match = path.match(/\.([a-z0-9]+)$/i);
  return normalizeVideoExtension(match?.[1] || '');
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

function resolveGithubImagePage(url) {
  const match = url.match(GITHUB_FILE_IMAGE_PAGE_REGEX);
  if (!match?.[1] || !match?.[2] || !match?.[3]) {
    return '';
  }
  const filePath = match[3];
  if (!imageExtensionFromUrl(filePath)) {
    return '';
  }
  return `https://raw.githubusercontent.com/${match[1]}/${match[2]}/${filePath}`;
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
    return { kind: 'unsupported', renderUrl: normalizedUrl, isImage: false, isVideo: false, shouldProbe: false };
  }
  if (VIDEO_EXT_REGEX.test(normalizedUrl) || videoExtensionFromUrl(normalizedUrl)) {
    return { kind: 'directVideo', renderUrl: normalizedUrl, isImage: false, isVideo: true, shouldProbe: false };
  }
  const githubImageDirect = resolveGithubImagePage(normalizedUrl);
  if (githubImageDirect) {
    return { kind: 'imageHostPageResolved', renderUrl: githubImageDirect, isImage: true, isVideo: false, shouldProbe: false };
  }
  if (IMAGE_EXT_REGEX.test(normalizedUrl) || imageExtensionFromUrl(normalizedUrl)) {
    return { kind: 'directImage', renderUrl: normalizedUrl, isImage: true, isVideo: false, shouldProbe: false };
  }
  if (IMAGE_HOST_PREFIXES.some((prefix) => normalizedUrl.startsWith(prefix))) {
    return { kind: 'knownImageHostDirect', renderUrl: normalizedUrl, isImage: true, isVideo: false, shouldProbe: false };
  }
  const imgurDirect = resolveImgurSingleImagePage(normalizedUrl);
  if (imgurDirect) {
    return { kind: 'imageHostPageResolved', renderUrl: imgurDirect, isImage: true, isVideo: false, shouldProbe: false };
  }
  if (IMGUR_COLLECTION_PAGE_REGEX.test(normalizedUrl)) {
    return { kind: 'nonImageLink', renderUrl: normalizedUrl, isImage: false, isVideo: false, shouldProbe: false };
  }
  if (isProbeCandidate(normalizedUrl)) {
    return { kind: 'probeRequired', renderUrl: normalizedUrl, isImage: false, isVideo: false, shouldProbe: true };
  }
  return { kind: 'nonImageLink', renderUrl: normalizedUrl, isImage: false, isVideo: false, shouldProbe: false };
}

const cases = [
  ['https://i.imgur.com/HUuMBP5.mp4', 'directVideo', 'https://i.imgur.com/HUuMBP5.mp4', false, true, false],
  ['https://example.com/cdn?id=7&type=video/mp4', 'directVideo', 'https://example.com/cdn?id=7&type=video/mp4', false, true, false],
  ['https://example.com/a.jpg', 'directImage', 'https://example.com/a.jpg', true, false, false],
  ['https://example.com/a?format=webp', 'directImage', 'https://example.com/a?format=webp', true, false, false],
  ['https://mmbiz.qpic.cn/sz_mmbiz_png/Z6sTV0qrAlQob38vhxI4MHRbnrf4xETXAk2WYMCBBqSQWGRdPl8EibUuict4YfKzFcekQAZjiasMDhGVUICSb6WvcBnRG1AQdibXLSiaA3dPcd0s/0?wx_fmt=png&from=appmsg', 'directImage', 'https://mmbiz.qpic.cn/sz_mmbiz_png/Z6sTV0qrAlQob38vhxI4MHRbnrf4xETXAk2WYMCBBqSQWGRdPl8EibUuict4YfKzFcekQAZjiasMDhGVUICSb6WvcBnRG1AQdibXLSiaA3dPcd0s/0?wx_fmt=png&from=appmsg', true, false, false],
  ['https://mmbiz.qpic.cn/mmbiz_png/Z6sTV0qrAlSeIu71LpLFfVVeXHckHXWicQJg4SggDGRzXRLDVFibYjxQtXEOFTh0P3XtCRf6qvy5ibG1ibKFZ4WmS6LuCua0p37530Vhufg6how/0?from=appmsg&amp;wx_fmt=png', 'directImage', 'https://mmbiz.qpic.cn/mmbiz_png/Z6sTV0qrAlSeIu71LpLFfVVeXHckHXWicQJg4SggDGRzXRLDVFibYjxQtXEOFTh0P3XtCRf6qvy5ibG1ibKFZ4WmS6LuCua0p37530Vhufg6how/0?from=appmsg&amp;wx_fmt=png', true, false, false],
  ['https://i.imgur.com/abc123.jpg', 'directImage', 'https://i.imgur.com/abc123.jpg', true, false, false],
  ['https://imgur.com/abc123', 'imageHostPageResolved', 'https://i.imgur.com/abc123.png', true, false, false],
  ['https://imgur.com/a/abc123', 'nonImageLink', 'https://imgur.com/a/abc123', false, false, false],
  ['https://github.com/org/repo', 'nonImageLink', 'https://github.com/org/repo', false, false, false],
  ['https://github.com/alfredxw/nova/blob/master/img/ide.png', 'imageHostPageResolved', 'https://raw.githubusercontent.com/alfredxw/nova/master/img/ide.png', true, false, false],
  ['https://github.com/org/repo/raw/main/assets/pic.webp?raw=1', 'imageHostPageResolved', 'https://raw.githubusercontent.com/org/repo/main/assets/pic.webp', true, false, false],
  ['https://github.com/org/repo/blob/main/README.md', 'nonImageLink', 'https://github.com/org/repo/blob/main/README.md', false, false, false],
  ['https://raw.githubusercontent.com/org/repo/main/image', 'knownImageHostDirect', 'https://raw.githubusercontent.com/org/repo/main/image', true, false, false],
  ['https://example.com/download/123', 'probeRequired', 'https://example.com/download/123', false, false, true],
];

let failed = 0;
for (const [url, kind, renderUrl, isImage, isVideo, shouldProbe] of cases) {
  const actual = resolveMediaUrl(url);
  const ok = actual.kind === kind &&
    actual.renderUrl === renderUrl &&
    actual.isImage === isImage &&
    actual.isVideo === isVideo &&
    actual.shouldProbe === shouldProbe;
  if (!ok) {
    failed += 1;
    console.error(`FAIL ${url}`);
    console.error(`  expected ${JSON.stringify({ kind, renderUrl, isImage, isVideo, shouldProbe })}`);
    console.error(`  actual   ${JSON.stringify(actual)}`);
  }
}

if (failed > 0) {
  process.exit(1);
}
console.log(`Media URL rules OK (${cases.length} cases)`);
