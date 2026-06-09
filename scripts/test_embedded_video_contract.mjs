#!/usr/bin/env node
// Contract: V2EX embedded provider videos (YouTube/Vimeo) restored from
// content_rendered must surface as embeddedVideo cover-card tokens instead of
// being silently dropped. Covers the three frozen markup eras V2EX still
// serves (wrapper iframe in both attribute orders, protocol-relative Vimeo
// player src, pre-2014 Flash <object>), the parameter-residue text, the
// degrade-to-link path for non-whitelisted iframes, and the pure-video-reply
// "judged empty" pitfall.

import { readFileSync } from 'node:fs';

const markdownSource = readFileSync('shared/src/main/ets/components/MarkdownContent.ets', 'utf8');
const mediaUtilsSource = readFileSync('shared/src/main/ets/utils/MediaUrlUtils.ets', 'utf8');
const htmlBlockUtilsSource = readFileSync('shared/src/main/ets/utils/HtmlBlockUtils.ets', 'utf8');
const repliesParserSource = readFileSync('shared/src/main/ets/parser/V2exTopicRepliesParser.ets', 'utf8');
const apiServiceSource = readFileSync('shared/src/main/ets/network/ApiService.ets', 'utf8');

function fail(message, detail) {
  console.error(`FAIL ${message}`);
  if (detail !== undefined) {
    console.error(detail);
  }
  process.exit(1);
}

// ---------- source-anchored static checks ----------

if (!/static embeddedVideoFromSrc\(raw: string\): EmbeddedVideoInfo \| null/.test(mediaUtilsSource)) {
  fail('MediaUrlUtils must expose embeddedVideoFromSrc returning EmbeddedVideoInfo | null');
}
const youtubeSrcRegexLiteral = mediaUtilsSource.match(/const YOUTUBE_EMBED_SRC_REGEX: RegExp = \/(.*)\/i\n/)?.[1] || '';
const vimeoSrcRegexLiteral = mediaUtilsSource.match(/const VIMEO_PLAYER_SRC_REGEX: RegExp = \/(.*)\/i\n/)?.[1] || '';
if (!youtubeSrcRegexLiteral || !vimeoSrcRegexLiteral) {
  fail('MediaUrlUtils must declare YOUTUBE_EMBED_SRC_REGEX and VIMEO_PLAYER_SRC_REGEX');
}
if (!youtubeSrcRegexLiteral.includes('(?:embed|v)')) {
  fail('YouTube embed-src regex must accept both /embed/<id> (current) and /v/<id> (Flash-era)', youtubeSrcRegexLiteral);
}
if (!/https:\/\/i\.ytimg\.com\/vi\//.test(mediaUtilsSource)) {
  fail('YouTube embeds must carry a static i.ytimg.com cover URL');
}

if (!markdownSource.includes('(table|h[1-6]|p|ul|ol|blockquote|pre|div|object)')) {
  fail('renderedHtmlToTokens blockRe must capture <object> blocks for Flash-era embeds');
}
if (!/embeddedVideoTokensFromIframeHtml/.test(markdownSource) ||
  !/htmlClassContains\(iframeTag, 'embedded_video'\)/.test(markdownSource) ||
  !/htmlClassContains\(raw, 'embedded_video_wrapper'\)/.test(markdownSource)) {
  fail('iframe embeds must be matched by class (embedded_video / embedded_video_wrapper), never by attribute order');
}
if (!/embeddedVideoTokensFromLegacyObjectHtml/.test(markdownSource) || !/'movie'/.test(markdownSource)) {
  fail('legacy <object> embeds must be restored from <param name="movie"> (with <embed src> fallback)');
}
if (!/embeddedVideoOrLinkTokens/.test(markdownSource)) {
  fail('non-whitelisted iframe srcs must degrade to a plain link paragraph instead of dropping content');
}
if (!/const EMBEDDED_VIDEO_TYPE = "embeddedVideo"/.test(markdownSource) ||
  !/export interface EmbeddedVideo extends Token/.test(markdownSource)) {
  fail('embeddedVideo token type and Tokens.EmbeddedVideo interface must exist');
}

const cardStart = markdownSource.indexOf('struct EmbeddedVideoCard');
if (cardStart < 0) {
  fail('EmbeddedVideoCard component must exist');
}
if (!/@ComponentV2\nstruct EmbeddedVideoCard/.test(markdownSource)) {
  fail('EmbeddedVideoCard must be a State-V2 @ComponentV2 struct');
}
const cardEnd = markdownSource.indexOf('@ComponentV2', cardStart);
const cardBody = markdownSource.slice(cardStart, cardEnd > cardStart ? cardEnd : undefined);
if (!/private cardFrameWidth\(\): Length/.test(cardBody) || !/private cardFrameHeight\(\): number/.test(cardBody) ||
  !/MEDIA_VIDEO_MAX_WIDTH/.test(cardBody) || !/MEDIA_VIDEO_ASPECT_RATIO/.test(cardBody)) {
  fail('EmbeddedVideoCard must reuse the bounded responsive media-card sizing contract');
}
if (!/coverFailed/.test(cardBody) || !/markdown_embedded_video_cover_failed/.test(cardBody)) {
  fail('EmbeddedVideoCard cover must degrade to placeholder on load failure (i.ytimg.com is walled with youtube.com)');
}
if (!/coverLoadingAllowed/.test(cardBody) || !/onlyLoadImagesOnWifi/.test(cardBody)) {
  fail('EmbeddedVideoCard cover must follow the media image-load policy');
}
// In-place playback: tapping the cover mounts the provider's own embed player
// (lazy WebView — never pre-instantiated in a scrolling list) with autoplay
// authorized so the cover tap is the single play gesture.
if (!/playerMounted/.test(cardBody) ||
  !/Web\(\{ src: '', controller: this\.playerController \}\)/.test(cardBody) ||
  !/mediaPlayGestureAccess\(false\)/.test(cardBody)) {
  fail('EmbeddedVideoCard must mount the provider embed player in place on tap');
}
if (!/autoplay=1/.test(cardBody)) {
  fail('embedPlayUrl must request autoplay so the cover tap is the single play gesture');
}
// YouTube returns player error 153 for referer-less embed loads; the player
// document must be loaded with a v2ex.com baseUrl so the iframe carries the
// same Referer as the real V2EX page.
if (!/loadData\(this\.playerHtml\(\), 'text\/html', 'UTF-8', 'https:\/\/www\.v2ex\.com\/'\)/.test(cardBody) ||
  !/allow="autoplay; encrypted-media; picture-in-picture"/.test(cardBody)) {
  fail('player must load through the v2ex.com-based wrapper document (YouTube error 153 guard)');
}
// ArkWeb bypasses the in-app SOCKS5 proxy; the caption row keeps the
// external-browser fallback for devices that cannot reach the provider.
if (!/_openEmbeddedVideo\(this\.options, this\.videoToken\)/.test(cardBody)) {
  fail('EmbeddedVideoCard caption must keep the external-browser open fallback');
}
// In-player share: the provider iframe's share button calls navigator.share,
// which ArkWeb lacks. A native proxy injected into all frames + a document-start
// navigator.share polyfill forward it to the system share sheet (iOS-parity).
if (!/\.javaScriptProxy\(\{[\s\S]{0,200}name: EMBEDDED_VIDEO_SHARE_PROXY_NAME/.test(cardBody) ||
  !/\.javaScriptOnDocumentStart\(this\.shareScripts\)/.test(cardBody)) {
  fail('player Web must register the share proxy and inject the navigator.share polyfill');
}
if (!/scriptRules: \["\*"\]/.test(cardBody)) {
  fail('share polyfill must inject into all frames (scriptRules ["*"]) to reach the cross-origin provider iframe');
}
if (!/class EmbeddedVideoShareBridge/.test(markdownSource) ||
  !/navigator;if\(!n\.share\)/.test(markdownSource) ||
  !/systemShare\.ShareController/.test(markdownSource) ||
  !/utd\.UniformDataType\.HYPERLINK/.test(markdownSource)) {
  fail('share bridge must polyfill navigator.share and open a HYPERLINK system share via systemShare.ShareController');
}
if (!/markdown_embedded_video_open_external/.test(markdownSource)) {
  fail('embedded video external opens must be diagnosable');
}
if (!/_isEmbeddedVideoToken\(token\)[\s\S]{0,200}EmbeddedVideoCard\(/.test(markdownSource)) {
  fail('RenderProcessedToken must dispatch embeddedVideo tokens to EmbeddedVideoCard');
}
const blockquoteStart = markdownSource.indexOf('struct MarkdownBlockquote');
const blockquoteEnd = markdownSource.indexOf('struct ', blockquoteStart + 1);
const blockquoteBody = blockquoteStart >= 0 ? markdownSource.slice(blockquoteStart, blockquoteEnd > blockquoteStart ? blockquoteEnd : undefined) : '';
if (!/_isEmbeddedVideoToken\(child\)[\s\S]{0,200}EmbeddedVideoCard\(/.test(blockquoteBody)) {
  fail('blockquote children must dispatch embeddedVideo tokens to EmbeddedVideoCard');
}
// htmlListToToken recurses <li> bodies through renderedHtmlToTokens, so an embed
// wrapper inside a list item lands in item.tokens — CustomList must dispatch it
// too or the content is silently dropped.
const customListStart = markdownSource.indexOf('struct CustomList');
const customListEnd = markdownSource.indexOf('struct ', customListStart + 1);
const customListBody = customListStart >= 0 ? markdownSource.slice(customListStart, customListEnd > customListStart ? customListEnd : undefined) : '';
if (!/_isEmbeddedVideoToken\(child\)[\s\S]{0,200}EmbeddedVideoCard\(/.test(customListBody)) {
  fail('CustomList item children must dispatch embeddedVideo tokens to EmbeddedVideoCard');
}
// Root cause of the silent embed drop seen on-device (t/1212482): an
// unconditional trailing-</div> strip amputated bodies ending with a closed
// embed wrapper, leaving an unclosed div that blockRe can never match.
const stripFnBody = markdownSource.match(/private static stripRenderedHtmlWrapper\(html: string\): string \{([\s\S]*?)\n  \}/)?.[1] || '';
if (!/unwrapped\.length !== source\.length/.test(stripFnBody)) {
  fail('stripRenderedHtmlWrapper must strip the trailing </div> only when the markdown_body wrapper was removed');
}
// Upstream extraction must be div-nesting-aware or the wrapper arrives truncated.
if (!/static extractDivInnerByClass\(html: string, className: string\): string/.test(htmlBlockUtilsSource)) {
  fail('HtmlBlockUtils.extractDivInnerByClass must exist for nesting-aware block extraction');
}
if (!/HtmlBlockUtils\.extractDivInnerByClass\(block \|\| '', 'reply_content'\)/.test(repliesParserSource)) {
  fail('reply content extraction must use nesting-aware extractDivInnerByClass (lazy </div> truncates embeds)');
}
if (!/HtmlBlockUtils\.extractDivInnerByClass\(html, 'topic_content'\)/.test(apiServiceSource)) {
  fail('web-fallback topic content extraction must use nesting-aware extractDivInnerByClass');
}

// ---------- logic replica run against real V2EX markup samples ----------
// Mirrors renderedHtmlToTokens' embed-relevant slice; the source regex
// literals are extracted above so drift in MediaUrlUtils breaks this test.

const YOUTUBE_EMBED_SRC_REGEX = new RegExp(youtubeSrcRegexLiteral, 'i');
const VIMEO_PLAYER_SRC_REGEX = new RegExp(vimeoSrcRegexLiteral, 'i');

function normalizeUrl(raw) {
  const url = (raw ?? '').trim();
  return url.startsWith('//') ? `https:${url}` : url;
}

function decodeEntities(value) {
  return (value || '')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'");
}

function htmlAttr(tag, name) {
  const re = new RegExp(`(?:^|\\s)${name}\\s*=\\s*(?:(["'])(.*?)\\1|([^\\s"'=<>]+))`, 'i');
  const match = re.exec(tag || '');
  const value = match ? (match[2] || match[3] || '') : '';
  return value ? decodeEntities(value).trim() : '';
}

function htmlClassContains(tag, className) {
  return htmlAttr(tag, 'class').split(/\s+/).includes(className);
}

function embeddedVideoFromSrc(raw) {
  const url = normalizeUrl(raw);
  if (!url) return null;
  const youtubeMatch = url.match(YOUTUBE_EMBED_SRC_REGEX);
  if (youtubeMatch?.[1]) {
    return {
      provider: 'youtube',
      videoId: youtubeMatch[1],
      watchUrl: `https://www.youtube.com/watch?v=${youtubeMatch[1]}`,
      coverUrl: `https://i.ytimg.com/vi/${youtubeMatch[1]}/hqdefault.jpg`,
    };
  }
  const vimeoMatch = url.match(VIMEO_PLAYER_SRC_REGEX);
  if (vimeoMatch?.[1]) {
    return {
      provider: 'vimeo',
      videoId: vimeoMatch[1],
      watchUrl: `https://vimeo.com/${vimeoMatch[1]}`,
      coverUrl: '',
    };
  }
  return null;
}

function embeddedVideoOrLinkTokens(raw, src) {
  const info = embeddedVideoFromSrc(src);
  if (info) {
    return [{ type: 'embeddedVideo', raw, ...info }];
  }
  const url = normalizeUrl(src);
  if (!/^https?:\/\//.test(url)) return [];
  return [{ type: 'paragraph', raw, text: url, tokens: [{ type: 'link', href: url, text: url }] }];
}

function embeddedVideoTokensFromIframeHtml(raw, body) {
  const tokens = [];
  const wrapperDiv = htmlClassContains(raw, 'embedded_video_wrapper');
  for (const match of body.matchAll(/<iframe\b[^>]*>/gi)) {
    const iframeTag = match[0];
    if (wrapperDiv || htmlClassContains(iframeTag, 'embedded_video')) {
      tokens.push(...embeddedVideoOrLinkTokens(iframeTag, htmlAttr(iframeTag, 'src')));
    }
  }
  return tokens;
}

function embeddedVideoTokensFromLegacyObjectHtml(raw) {
  let candidate = '';
  for (const match of raw.matchAll(/<param\b[^>]*>/gi)) {
    if (htmlAttr(match[0], 'name').toLowerCase() === 'movie') {
      candidate = htmlAttr(match[0], 'value');
      break;
    }
  }
  if (!candidate) {
    const embedMatch = /<embed\b[^>]*>/i.exec(raw);
    candidate = embedMatch ? htmlAttr(embedMatch[0], 'src') : '';
  }
  const info = embeddedVideoFromSrc(candidate);
  return info ? [{ type: 'embeddedVideo', raw, ...info }] : [];
}

// Faithful replica of MarkdownContent.stripRenderedHtmlWrapper — the original
// replica omitted this step and false-passed while the real pipeline amputated
// trailing embed wrappers.
function stripRenderedHtmlWrapper(html) {
  const source = (html || '').trim();
  const unwrapped = source.replace(/^<div\b[^>]*class=(["'])[^"']*markdown_body[^"']*\1[^>]*>/i, '');
  if (unwrapped.length !== source.length) {
    return unwrapped.replace(/<\/div>\s*$/i, '');
  }
  return source;
}

// Faithful replica of HtmlBlockUtils.extractDivInnerByClass.
function extractDivInnerByClass(html, className) {
  const source = html || '';
  const openRe = new RegExp(`<div[^>]*class=['"][^'"]*\\b${className}\\b[^'"]*['"][^>]*>`, 'i');
  const open = openRe.exec(source);
  if (!open) {
    return '';
  }
  const start = open.index + open[0].length;
  const divRe = /<\/?div\b[^>]*>/gi;
  divRe.lastIndex = start;
  let depth = 1;
  let tag;
  while ((tag = divRe.exec(source))) {
    depth += tag[0].charAt(1) === '/' ? -1 : 1;
    if (depth === 0) {
      return source.slice(start, tag.index);
    }
  }
  return source.slice(start);
}

function renderedHtmlToTokens(html) {
  // Real order: processTokens decodes entities, then renderedHtmlToTokens strips the wrapper.
  const source = stripRenderedHtmlWrapper(decodeEntities(html));
  const tokens = [];
  const blockRe = /<(table|h[1-6]|p|ul|ol|blockquote|pre|div|object)\b[^>]*>([\s\S]*?)<\/\1>/gi;
  let last = 0;
  for (const match of source.matchAll(blockRe)) {
    if (match.index > last) {
      const text = source.slice(last, match.index).replace(/<[^>]+>/g, '').trim();
      if (text) tokens.push({ type: 'paragraph', text });
    }
    const tag = match[1].toLowerCase();
    if (tag === 'object') {
      tokens.push(...embeddedVideoTokensFromLegacyObjectHtml(match[0]));
    } else if (tag === 'div') {
      const embedded = embeddedVideoTokensFromIframeHtml(match[0], match[2]);
      if (embedded.length > 0) {
        tokens.push(...embedded);
      } else {
        const text = match[2].replace(/<[^>]+>/g, '').trim();
        if (text) tokens.push({ type: 'paragraph', text });
      }
    } else {
      const text = match[2].replace(/<[^>]+>/g, '').trim();
      if (text) tokens.push({ type: 'paragraph', text });
    }
    last = match.index + match[0].length;
  }
  const tail = source.slice(last).replace(/<[^>]+>/g, '').trim();
  if (tail) tokens.push({ type: 'paragraph', text: tail });
  return tokens;
}

// Case 1: current YouTube wrapper (class-first attribute order).
const currentForm = renderedHtmlToTokens(
  '<div class="embedded_video_wrapper"><iframe class="embedded_video" width="640" height="360" src="//www.youtube.com/embed/dQw4w9WgXcQ" frameborder="0" allowfullscreen></iframe></div>',
);
if (currentForm.length !== 1 || currentForm[0].type !== 'embeddedVideo' ||
  currentForm[0].watchUrl !== 'https://www.youtube.com/watch?v=dQw4w9WgXcQ' ||
  currentForm[0].coverUrl !== 'https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg') {
  fail('current YouTube wrapper iframe must restore the canonical watch URL + ytimg cover', currentForm);
}

// Case 2: the other attribute serialization order (src before class) seen in older posts.
const swappedOrder = renderedHtmlToTokens(
  '<div class="embedded_video_wrapper"><iframe src="//www.youtube.com/embed/abc123XYZ_-" class="embedded_video" allowfullscreen="true" frameborder="0"></iframe></div>',
);
if (swappedOrder.length !== 1 || swappedOrder[0].type !== 'embeddedVideo' || swappedOrder[0].videoId !== 'abc123XYZ_-') {
  fail('iframe attribute order must not matter (match by class only)', swappedOrder);
}

// Case 3: Vimeo protocol-relative player src; no static cover endpoint.
const vimeoForm = renderedHtmlToTokens(
  '<div class="embedded_video_wrapper"><iframe class="embedded_video" src="//player.vimeo.com/video/12345678" frameborder="0"></iframe></div>',
);
if (vimeoForm.length !== 1 || vimeoForm[0].type !== 'embeddedVideo' ||
  vimeoForm[0].watchUrl !== 'https://vimeo.com/12345678' || vimeoForm[0].coverUrl !== '') {
  fail('Vimeo player iframe must restore vimeo.com watch URL with empty cover', vimeoForm);
}

// Case 4: pre-2014 Flash <object> markup (content_rendered is frozen at post time, e.g. t/8400).
const flashForm = renderedHtmlToTokens(
  '<object width="640" height="385"><param name="movie" value="http://www.youtube.com/v/Ahg6qcgoay4?fs=1&amp;hl=en_US"></param>' +
  '<param name="allowFullScreen" value="true"></param>' +
  '<embed src="http://www.youtube.com/v/Ahg6qcgoay4?fs=1&amp;hl=en_US" type="application/x-shockwave-flash" allowfullscreen="true" width="640" height="385"></embed></object>',
);
if (flashForm.length !== 1 || flashForm[0].type !== 'embeddedVideo' ||
  flashForm[0].watchUrl !== 'https://www.youtube.com/watch?v=Ahg6qcgoay4') {
  fail('Flash-era <object><param name="movie"> must restore the watch URL', flashForm);
}

// Case 5: URL parameter residue after the wrapper stays visible literal text (web parity, e.g. t/465341).
const residueForm = renderedHtmlToTokens(
  '<div class="embedded_video_wrapper"><iframe class="embedded_video" src="//www.youtube.com/embed/xyzXYZ123"></iframe></div>&amp;t=298s',
);
if (residueForm.length !== 2 || residueForm[0].type !== 'embeddedVideo' ||
  residueForm[1].type !== 'paragraph' || residueForm[1].text !== '&t=298s') {
  fail('parameter residue after the wrapper must stay as literal text, neither dropped nor merged into the embed', residueForm);
}

// Case 6: non-whitelisted iframe src degrades to a plain link paragraph — content is never lost.
const unknownIframe = renderedHtmlToTokens(
  '<div class="embedded_video_wrapper"><iframe class="embedded_video" src="//player.bilibili.com/player.html?bvid=BV1xx411c7mD"></iframe></div>',
);
if (unknownIframe.length !== 1 || unknownIframe[0].type !== 'paragraph' ||
  unknownIframe[0].tokens?.[0]?.href !== 'https://player.bilibili.com/player.html?bvid=BV1xx411c7mD') {
  fail('non-whitelisted embed srcs must degrade to a clickable link paragraph', unknownIframe);
}

// Case 7: a pure-video reply must not be judged empty (the common competitor pitfall).
const pureVideoReply = renderedHtmlToTokens(
  '<div class="embedded_video_wrapper"><iframe class="embedded_video" src="//www.youtube.com/embed/onlyVideo01"></iframe></div>',
);
if (pureVideoReply.length === 0) {
  fail('a reply whose content is only an embed must still produce tokens');
}

// Case 8: srcs outside the V2EX embed whitelist forms never become embeds.
for (const src of [
  'https://example.com/video.mp4',
  'https://www.youtube.com/shorts/abcdef12345',
  'https://www.youtube.com/watch?v=abcdef12345',
  'https://vimeo.com/12345678',
]) {
  if (embeddedVideoFromSrc(src) !== null) {
    fail(`non-embed src must not map to an embedded video: ${src}`);
  }
}

// Case 9: regression for the on-device silent drop (t/1212482 shape) — body
// text followed by a trailing closed wrapper. The old unconditional trailing
// </div> strip amputated the wrapper close tag, blockRe never matched, and the
// embed vanished while the text survived.
const trailingWrapper = renderedHtmlToTokens(
  '小白可以看下<br /><br />eSIM 卡是什么，以及几款 eSIM 卡对比<br /><br />' +
  '<div class="embedded_video_wrapper"><iframe src="https://www.youtube.com/embed/W46dce-LXjM" class="embedded_video" allowfullscreen="" type="text/html" id="ytplayer" frameborder="0"></iframe></div>',
);
if (trailingWrapper.length !== 2 || trailingWrapper[0].type !== 'paragraph' ||
  trailingWrapper[1].type !== 'embeddedVideo' ||
  trailingWrapper[1].watchUrl !== 'https://www.youtube.com/watch?v=W46dce-LXjM') {
  fail('a body ending with a closed embed wrapper must keep both the text and the embed (t/1212482 regression)', trailingWrapper);
}

// Case 10: a markdown_body-wrapped rendered body must still unwrap, and the
// unwrap must not eat the embed wrapper's own close tag.
const wrappedBody = renderedHtmlToTokens(
  '<div class="markdown_body"><p>intro</p>' +
  '<div class="embedded_video_wrapper"><iframe class="embedded_video" src="//www.youtube.com/embed/wrapCase001"></iframe></div></div>',
);
if (wrappedBody.length !== 2 || wrappedBody[0].type !== 'paragraph' || wrappedBody[0].text !== 'intro' ||
  wrappedBody[1].type !== 'embeddedVideo' || wrappedBody[1].videoId !== 'wrapCase001') {
  fail('markdown_body unwrap must remove only its own wrapper pair, preserving a trailing embed wrapper', wrappedBody);
}

// Case 11: reply block extraction (t/902178 shape — embed inside a reply).
// Lazy ([\s\S]*?)</div> would truncate at the wrapper's open div; the
// nesting-aware extractor must return the full closed wrapper so the token
// pipeline still finds the embed.
const replyBlock =
  '<td class="r_td"><div class="reply_content">看这个<br />' +
  '<div class="embedded_video_wrapper"><iframe class="embedded_video" src="//player.vimeo.com/video/87654321"></iframe></div></div></td>';
const replyInner = extractDivInnerByClass(replyBlock, 'reply_content');
if (!replyInner.includes('</iframe></div>')) {
  fail('reply_content extraction must retain the nested embed wrapper closed', replyInner);
}
const replyTokens = renderedHtmlToTokens(replyInner);
if (replyTokens.length !== 2 || replyTokens[0].type !== 'paragraph' ||
  replyTokens[1].type !== 'embeddedVideo' || replyTokens[1].watchUrl !== 'https://vimeo.com/87654321') {
  fail('a reply nesting an embed wrapper must yield text + embeddedVideo tokens', replyTokens);
}

// Case 12: web-fallback topic_content extraction with a nested wrapper.
const topicCell =
  '<div class="cell"><div class="topic_content">背景说明' +
  '<div class="embedded_video_wrapper"><iframe class="embedded_video" src="//www.youtube.com/embed/topicCase01"></iframe></div></div></div>';
const topicInner = extractDivInnerByClass(topicCell, 'topic_content');
if (!topicInner.includes('</iframe></div>')) {
  fail('topic_content extraction must retain the nested embed wrapper closed', topicInner);
}
const topicTokens = renderedHtmlToTokens(topicInner);
if (topicTokens.length !== 2 || topicTokens[1].type !== 'embeddedVideo' ||
  topicTokens[1].videoId !== 'topicCase01') {
  fail('a topic body nesting an embed wrapper must yield text + embeddedVideo tokens', topicTokens);
}

console.log('Embedded video contract OK (12 cases + source anchors)');
