import { MediaUrlUtils } from "../../utils/MediaUrlUtils";

// Visible load sentinel for inline images whose intrinsic dimensions are not known yet.
// Once ImageSpan reports dimensions, the measured image size wins even if the
// paragraph width has not reported yet.
export const INLINE_IMAGE_PENDING_SIZE = 24;
export const INLINE_IMAGE_VIEWPORT_SAFE_MAX_HEIGHT = 1200;
export const INLINE_IMAGE_SIZE_RECORD_LIMIT = 64;

export interface InlineImageTokenRecord {
  type?: string;
  raw?: string;
  text?: string;
  href?: string;
  inlineImage?: boolean;
}

export interface InlineImageSizeRecord {
  url: string;
  widthPx: number;
  heightPx: number;
}

export interface InlineImageRenderSize {
  width: number;
  height: number;
}

export function _isInlineImageToken(token: InlineImageTokenRecord): boolean {
  const image = token as InlineImageTokenRecord;
  return token && token.type === "image" && image.inlineImage === true;
}

export function _findInlineImageSizeRecord(records: InlineImageSizeRecord[], url: string): InlineImageSizeRecord | null {
  if (!url || !records || records.length === 0) {
    return null;
  }
  for (const record of records) {
    if (record.url === url) {
      return record;
    }
  }
  return null;
}

export function _inlineImageRenderUrl(token: InlineImageTokenRecord): string {
  if (!token || token.type !== "image") {
    return "";
  }
  return MediaUrlUtils.imageUrlForRender(token.href ?? "");
}

export function _areaWidth(value: Area): number {
  if (typeof value.width === 'number') {
    return value.width;
  }
  if (typeof value.width === 'string') {
    const parsed = Number.parseFloat(value.width);
    return Number.isNaN(parsed) ? 0 : parsed;
  }
  return 0;
}

export function _inlineImageRenderSize(token: InlineImageTokenRecord, sizeRecords: InlineImageSizeRecord[], availableWidth: number): InlineImageRenderSize {
  const contentMaxWidth = Math.max(0, availableWidth);
  const url = _inlineImageRenderUrl(token);
  return _inlineImageRenderSizeByUrl(url, sizeRecords, contentMaxWidth);
}

export function _inlineImageRenderSizeByUrl(url: string, sizeRecords: InlineImageSizeRecord[], contentMaxWidth: number): InlineImageRenderSize {
  const record = _findInlineImageSizeRecord(sizeRecords, url);
  const widthPx = record?.widthPx ?? 0;
  const heightPx = record?.heightPx ?? 0;
  if (widthPx <= 0 || heightPx <= 0) {
    return {
      width: INLINE_IMAGE_PENDING_SIZE,
      height: INLINE_IMAGE_PENDING_SIZE,
    };
  }
  if (contentMaxWidth <= 0) {
    return {
      width: Math.max(1, Math.round(widthPx)),
      height: Math.max(1, Math.round(heightPx)),
    };
  }
  const scale = Math.min(1, contentMaxWidth / widthPx, INLINE_IMAGE_VIEWPORT_SAFE_MAX_HEIGHT / heightPx);
  return {
    width: Math.max(1, Math.round(widthPx * scale)),
    height: Math.max(1, Math.round(heightPx * scale)),
  };
}

export function _isMixedInlineImageCandidate(token: InlineImageTokenRecord): boolean {
  if (!token || token.type !== "image") {
    return false;
  }
  if (_isInlineImageToken(token)) {
    return true;
  }
  if (token.inlineImage === false) {
    return false;
  }
  const raw = (token.raw ?? "").trim().toLowerCase();
  return raw.startsWith("<img");
}

export function _inlineTokenKey(token: InlineImageTokenRecord, index: number): string {
  const record = token as InlineImageTokenRecord;
  return `${String(record.type ?? "token")}-${String(record.raw ?? record.href ?? record.text ?? index)}-${index}`;
}

export function _appendCacheBust(url: string, nonce: number): string {
  if (!url) {
    return "";
  }
  if (nonce <= 0) {
    return url;
  }
  const sep = url.indexOf("?") >= 0 ? "&" : "?";
  return `${url}${sep}_r=${nonce}`;
}
