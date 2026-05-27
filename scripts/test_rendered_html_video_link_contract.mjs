#!/usr/bin/env node

import { readFileSync } from 'node:fs';

const source = readFileSync('shared/src/main/ets/components/MarkdownContent.ets', 'utf8');
const rewriteLinkBody = source.match(/private static rewriteInlineImageToken\(token: Token\): Token\[] \{([\s\S]*?)\n  \}\n\n  private static firstNestedImage/)?.[1] || '';
if (!/buildVideoToken\(/.test(rewriteLinkBody) || !/MediaUrlUtils\.videoUrlForRender/.test(rewriteLinkBody)) {
  console.error('FAIL rendered-html link rewrite must convert direct video href tokens before standalone image rewriting');
  process.exit(1);
}
if (!/struct MarkdownVideoPlayer/.test(source) || !/Video\(\{/.test(source)) {
  console.error('FAIL video tokens must render through a playback-capable Video component');
  process.exit(1);
}
if (!/markdown_video_load_failed/.test(source) || !/R_COMMON_OPEN_EXTERNAL/.test(source) || !/R_COMMON_RETRY/.test(source)) {
  console.error('FAIL video player must diagnose failures and expose retry/open-external fallback');
  process.exit(1);
}

const IMAGE_EXT_REGEX = /\.(jpe?g|png|gif|webp|bmp|svg|avif|heic|heif)(?:[?#].*)?$/i;
const VIDEO_EXT_REGEX = /\.(mp4|webm|mov|m4v|m3u8)(?:[?#].*)?$/i;
const MEDIA_QUERY_EXT_REGEX = /[?&](?:format|fm|ext|type|output)=([a-z0-9/]+)/i;
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
  return url.startsWith('//') ? `https:${url}` : url;
}

function normalizeImageExtension(raw) {
  let ext = (raw || '').toLowerCase().trim();
  if (ext.includes('/')) ext = ext.split('/').pop() || '';
  if (ext === 'jpeg' || ext === 'jpg') return 'jpg';
  return ['png', 'gif', 'webp', 'bmp', 'svg', 'avif', 'heic', 'heif'].includes(ext) ? ext : '';
}

function normalizeVideoExtension(raw) {
  let ext = (raw || '').toLowerCase().trim();
  if (ext.includes('/')) ext = ext.split('/').pop() || '';
  return ['mp4', 'webm', 'mov', 'm4v', 'm3u8'].includes(ext) ? ext : '';
}

function imageExtensionFromUrl(raw) {
  const clean = normalizeUrl(raw).split('#')[0];
  const queryMatch = clean.match(MEDIA_QUERY_EXT_REGEX);
  const queryExt = normalizeImageExtension(queryMatch?.[1] || '');
  if (queryExt) return queryExt;
  const match = clean.split('?')[0].match(/\.([a-z0-9]+)$/i);
  return normalizeImageExtension(match?.[1] || '');
}

function videoExtensionFromUrl(raw) {
  const clean = normalizeUrl(raw).split('#')[0];
  const queryMatch = clean.match(MEDIA_QUERY_EXT_REGEX);
  const queryExt = normalizeVideoExtension(queryMatch?.[1] || '');
  if (queryExt) return queryExt;
  const match = clean.split('?')[0].match(/\.([a-z0-9]+)$/i);
  return normalizeVideoExtension(match?.[1] || '');
}

function videoUrlForRender(raw) {
  const url = normalizeUrl(raw);
  if (!/^https?:\/\//i.test(url)) return '';
  if (VIDEO_EXT_REGEX.test(url) || videoExtensionFromUrl(url)) return url;
  return '';
}

function imageUrlForRender(raw) {
  const url = normalizeUrl(raw);
  if (!/^https?:\/\//i.test(url)) return '';
  if (VIDEO_EXT_REGEX.test(url) || videoExtensionFromUrl(url)) return '';
  if (IMAGE_EXT_REGEX.test(url) || imageExtensionFromUrl(url)) return url;
  if (IMAGE_HOST_PREFIXES.some((prefix) => url.startsWith(prefix))) return url;
  return '';
}

function htmlAttr(html, name) {
  const re = new RegExp(`${name}\\s*=\\s*(["'])([\\s\\S]*?)\\1`, 'i');
  return html.match(re)?.[2] || '';
}

function stripHtmlTags(html) {
  return (html || '').replace(/<[^>]+>/g, '');
}

function htmlAnchorToToken(part) {
  const href = htmlAttr(part, 'href');
  const label = stripHtmlTags(part);
  if (!href) return { type: 'text', text: label };
  return { type: 'link', raw: part, href, text: label, tokens: [{ type: 'text', text: label }] };
}

function rewriteLinkMediaToken(token) {
  if (token.type !== 'link') return [token];
  const text = (token.text || '').trim();
  const normalizedText = normalizeUrl(text);
  const href = normalizeUrl(token.href || '');
  if (text && normalizedText !== href) return [token];

  const videoUrl = videoUrlForRender(href);
  if (videoUrl) return [{ type: 'video', href: videoUrl, text: token.text || videoUrl }];

  const renderUrl = imageUrlForRender(href);
  if (renderUrl) return [{ type: 'image', href: renderUrl, text: '' }];

  return [token];
}

function rewriteInlineMediaLinks(tokens) {
  const rewritten = [];
  for (const token of tokens) rewritten.push(...rewriteLinkMediaToken(token));
  return rewritten;
}

const exactFloor4Tokens = [
  { type: 'text', text: '这是 AI 写的代码和你可以做的事' },
  { type: 'br', text: '\n' },
  { type: 'br', text: '\n' },
  htmlAnchorToToken('<a target="_blank" href="https://i.imgur.com/HUuMBP5.mp4" rel="nofollow noopener">https://i.imgur.com/HUuMBP5.mp4</a>'),
];
const exactFloor4Rewritten = rewriteInlineMediaLinks(exactFloor4Tokens);
const exactVideo = exactFloor4Rewritten.find((token) => token.type === 'video');
if (!exactVideo || exactVideo.href !== 'https://i.imgur.com/HUuMBP5.mp4') {
  console.error('FAIL exact topic 1215936 floor 4 rendered-html mp4 link must become playable video media even after preceding text/br tokens');
  console.error(exactFloor4Rewritten);
  process.exit(1);
}
if (exactFloor4Rewritten.some((token) => token.type === 'image' && token.href === 'https://i.imgur.com/HUuMBP5.mp4')) {
  console.error('FAIL mp4 must not be rendered as Image');
  console.error(exactFloor4Rewritten);
  process.exit(1);
}

const pngToken = rewriteInlineMediaLinks([htmlAnchorToToken('<a href="https://i.imgur.com/abc123.png">https://i.imgur.com/abc123.png</a>')])[0];
if (pngToken.type !== 'image' || pngToken.href !== 'https://i.imgur.com/abc123.png') {
  console.error('FAIL imgur png host link must still become an image');
  console.error(pngToken);
  process.exit(1);
}

const jpgNoExtKnownHost = rewriteInlineMediaLinks([htmlAnchorToToken('<a href="https://i.imgur.com/abc123">https://i.imgur.com/abc123</a>')])[0];
if (jpgNoExtKnownHost.type !== 'image' || jpgNoExtKnownHost.href !== 'https://i.imgur.com/abc123') {
  console.error('FAIL existing known image-host direct behavior must be preserved');
  console.error(jpgNoExtKnownHost);
  process.exit(1);
}

const normalLink = rewriteInlineMediaLinks([htmlAnchorToToken('<a href="https://example.com/post/42">example</a>')])[0];
if (normalLink.type !== 'link' || normalLink.href !== 'https://example.com/post/42') {
  console.error('FAIL normal text link must remain clickable');
  console.error(normalLink);
  process.exit(1);
}

console.log('Rendered HTML video/image/link contract OK (4 cases)');
