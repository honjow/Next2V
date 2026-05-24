import { common } from '@kit.AbilityKit'
import { fileIo } from '@kit.CoreFileKit'
import { AppStrings } from '../i18n/AppStrings'
import {
  CACHE_PAYLOAD_DIR_NAME,
  CACHE_PAYLOAD_FILE_SUFFIX,
  CACHE_PAYLOAD_STAGED_SUFFIX,
  CACHE_PAYLOAD_TOPIC_DETAIL_PREFIX,
  CACHE_PAYLOAD_TOPIC_LIST_PREFIX,
  FILE_PAYLOAD_THRESHOLD_BYTES,
  MAX_CACHE_PAYLOAD_FILENAME_STEM_LENGTH,
} from './CachePolicy'

export interface PayloadStoragePlan {
  payloadText: string | null
  payloadPath: string | null
  stagedPayloadPath: string | null
  size: number
}

export function preparePayloadStorage(
  context: common.UIAbilityContext,
  payloadFileName: string,
  payloadText: string
): PayloadStoragePlan {
  const size = byteLength(payloadText)
  if (size < FILE_PAYLOAD_THRESHOLD_BYTES) {
    return {
      payloadText: payloadText,
      payloadPath: null,
      stagedPayloadPath: null,
      size: size
    }
  }
  ensurePayloadDirectory(context)
  const committedName = committedPayloadFileName(context, payloadFileName)
  const stagedName = stagedPayloadFileName(committedName)
  writePayloadFile(context, stagedName, payloadText)
  return {
    payloadText: null,
    payloadPath: committedName,
    stagedPayloadPath: stagedName,
    size: size
  }
}

export function commitStagedPayloadFile(context: common.UIAbilityContext, payloadPlan: PayloadStoragePlan): void {
  if (!payloadPlan.stagedPayloadPath || !payloadPlan.payloadPath) {
    return
  }
  try {
    fileIo.renameSync(
      payloadFilePath(context, payloadPlan.stagedPayloadPath),
      payloadFilePath(context, payloadPlan.payloadPath)
    )
  } catch (error) {
    cleanupPreparedPayloadFile(context, payloadPlan)
    const e = error as Error
    throw new Error(e.message || AppStrings.text(AppStrings.R_CACHE_COMMIT_PAYLOAD_FAILED, 'Failed to commit cache file'))
  }
}

export function cleanupPreparedPayloadFile(context: common.UIAbilityContext, payloadPlan: PayloadStoragePlan): void {
  if (payloadPlan.stagedPayloadPath) {
    unlinkPayloadFileBestEffort(context, payloadPlan.stagedPayloadPath)
  }
  if (payloadPlan.payloadPath) {
    unlinkPayloadFileBestEffort(context, payloadPlan.payloadPath)
  }
}

export function resolvePayloadText(
  context: common.UIAbilityContext,
  payloadText: string,
  payloadPath: string
): string {
  if (payloadPath.length > 0 && isCachePayloadFileName(payloadPath)) {
    try {
      return fileIo.readTextSync(payloadFilePath(context, payloadPath))
    } catch (_error) {
    }
  }
  return payloadText
}

export function deleteOrphanPayloadFiles(context: common.UIAbilityContext, activePaths: Set<string>): void {
  let filenames: string[] = []
  try {
    filenames = fileIo.listFileSync(payloadBaseDir(context))
  } catch (_error) {
    return
  }
  filenames.forEach((filename: string) => {
    if (
      isCachePayloadArtifactFileName(filename) &&
      !activePaths.has(filename)
    ) {
      unlinkPayloadFileBestEffort(context, filename)
    }
  })
}

export function unlinkPayloadFileBestEffort(context: common.UIAbilityContext, relativeName: string): void {
  if (!isSafePayloadFileName(relativeName)) {
    return
  }
  try {
    fileIo.unlinkSync(payloadFilePath(context, relativeName))
  } catch (_error) {
  }
}

export function topicListPayloadFileName(rowKey: string): string {
  return CACHE_PAYLOAD_TOPIC_LIST_PREFIX + encodePayloadKey(rowKey) + CACHE_PAYLOAD_FILE_SUFFIX
}

export function topicDetailPayloadFileName(rowKey: string): string {
  return CACHE_PAYLOAD_TOPIC_DETAIL_PREFIX + encodePayloadKey(rowKey) + CACHE_PAYLOAD_FILE_SUFFIX
}

export function byteLength(value: string): number {
  let bytes = 0
  for (let i = 0; i < value.length; i++) {
    const code = value.charCodeAt(i)
    if (code <= 0x7F) {
      bytes += 1
    } else if (code <= 0x7FF) {
      bytes += 2
    } else if (code >= 0xD800 && code <= 0xDBFF && i + 1 < value.length) {
      const next = value.charCodeAt(i + 1)
      if (next >= 0xDC00 && next <= 0xDFFF) {
        bytes += 4
        i += 1
      } else {
        bytes += 3
      }
    } else {
      bytes += 3
    }
  }
  return bytes
}

export function payloadHash(payloadText: string): string {
  let bytes = 0
  let hash = 0x811c9dc5
  for (let i = 0; i < payloadText.length; i++) {
    const code = payloadText.charCodeAt(i)
    if (code <= 0x7F) {
      hash = fnv1a32Byte(hash, code)
      bytes += 1
    } else if (code <= 0x7FF) {
      hash = fnv1a32Byte(hash, 0xC0 | (code >> 6))
      hash = fnv1a32Byte(hash, 0x80 | (code & 0x3F))
      bytes += 2
    } else if (code >= 0xD800 && code <= 0xDBFF && i + 1 < payloadText.length) {
      const next = payloadText.charCodeAt(i + 1)
      if (next >= 0xDC00 && next <= 0xDFFF) {
        const point = 0x10000 + ((code - 0xD800) << 10) + (next - 0xDC00)
        hash = fnv1a32Byte(hash, 0xF0 | (point >> 18))
        hash = fnv1a32Byte(hash, 0x80 | ((point >> 12) & 0x3F))
        hash = fnv1a32Byte(hash, 0x80 | ((point >> 6) & 0x3F))
        hash = fnv1a32Byte(hash, 0x80 | (point & 0x3F))
        bytes += 4
        i += 1
      } else {
        hash = fnv1a32Byte(hash, 0xEF)
        hash = fnv1a32Byte(hash, 0xBF)
        hash = fnv1a32Byte(hash, 0xBD)
        bytes += 3
      }
    } else {
      hash = fnv1a32Byte(hash, 0xE0 | (code >> 12))
      hash = fnv1a32Byte(hash, 0x80 | ((code >> 6) & 0x3F))
      hash = fnv1a32Byte(hash, 0x80 | (code & 0x3F))
      bytes += 3
    }
  }
  return 'v1:fnv1a32-utf8:' + bytes.toString() + ':' + hash.toString(16).padStart(8, '0')
}

function ensurePayloadDirectory(context: common.UIAbilityContext): void {
  try {
    fileIo.mkdirSync(payloadBaseDir(context), true)
  } catch (_error) {
  }
}

function writePayloadFile(context: common.UIAbilityContext, relativeName: string, payloadText: string): void {
  if (!isSafePayloadFileName(relativeName)) {
    throw new Error(AppStrings.text(AppStrings.R_CACHE_INVALID_FILENAME, 'Invalid cache filename'))
  }
  let file: fileIo.File | null = null
  try {
    file = fileIo.openSync(
      payloadFilePath(context, relativeName),
      fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC
    )
    fileIo.writeSync(file.fd, payloadText)
  } finally {
    closeFileBestEffort(file)
  }
}

function closeFileBestEffort(file: fileIo.File | null): void {
  if (!file) {
    return
  }
  try {
    fileIo.closeSync(file)
  } catch (_error) {
  }
}

function committedPayloadFileName(context: common.UIAbilityContext, baseName: string): string {
  if (!isCachePayloadFileName(baseName)) {
    throw new Error(AppStrings.text(AppStrings.R_CACHE_INVALID_FILENAME, 'Invalid cache filename'))
  }
  const stem = baseName.substring(0, baseName.length - CACHE_PAYLOAD_FILE_SUFFIX.length)
  for (let attempt = 0; attempt < 8; attempt++) {
    const candidate = stem + '_' + Date.now().toString() + '_' + randomPayloadNonce() + CACHE_PAYLOAD_FILE_SUFFIX
    if (!payloadFileExistsBestEffort(context, candidate)) {
      return candidate
    }
  }
  throw new Error(AppStrings.text(AppStrings.R_CACHE_FILENAME_CONFLICT, 'Cache filename conflict'))
}

function stagedPayloadFileName(committedName: string): string {
  if (!isCachePayloadFileName(committedName)) {
    throw new Error(AppStrings.text(AppStrings.R_CACHE_INVALID_FILENAME, 'Invalid cache filename'))
  }
  return committedName + CACHE_PAYLOAD_STAGED_SUFFIX
}

function randomPayloadNonce(): string {
  return Math.floor(Math.random() * 0x100000000).toString(16).padStart(8, '0')
}

function encodePayloadKey(value: string): string {
  let encoded = ''
  for (let i = 0; i < value.length; i++) {
    const code = value.charCodeAt(i)
    if (code <= 0x7F) {
      encoded += hexByte(code)
    } else if (code <= 0x7FF) {
      encoded += hexByte(0xC0 | (code >> 6))
      encoded += hexByte(0x80 | (code & 0x3F))
    } else if (code >= 0xD800 && code <= 0xDBFF && i + 1 < value.length) {
      const next = value.charCodeAt(i + 1)
      if (next >= 0xDC00 && next <= 0xDFFF) {
        const point = 0x10000 + ((code - 0xD800) << 10) + (next - 0xDC00)
        encoded += hexByte(0xF0 | (point >> 18))
        encoded += hexByte(0x80 | ((point >> 12) & 0x3F))
        encoded += hexByte(0x80 | ((point >> 6) & 0x3F))
        encoded += hexByte(0x80 | (point & 0x3F))
        i += 1
      } else {
        encoded += hexByte(0xEF)
        encoded += hexByte(0xBF)
        encoded += hexByte(0xBD)
      }
    } else {
      encoded += hexByte(0xE0 | (code >> 12))
      encoded += hexByte(0x80 | ((code >> 6) & 0x3F))
      encoded += hexByte(0x80 | (code & 0x3F))
    }
  }
  if (encoded.length <= 0 || encoded.length > MAX_CACHE_PAYLOAD_FILENAME_STEM_LENGTH) {
    throw new Error(AppStrings.text(AppStrings.R_CACHE_FILENAME_LENGTH_INVALID, 'Invalid cache filename length'))
  }
  return encoded
}

function hexByte(value: number): string {
  const clean = value & 0xFF
  return clean.toString(16).padStart(2, '0')
}

function payloadBaseDir(context: common.UIAbilityContext): string {
  return context.filesDir + '/' + CACHE_PAYLOAD_DIR_NAME
}

function payloadFilePath(context: common.UIAbilityContext, relativeName: string): string {
  return payloadBaseDir(context) + '/' + relativeName
}

function payloadFileExistsBestEffort(context: common.UIAbilityContext, relativeName: string): boolean {
  if (!isSafePayloadFileName(relativeName)) {
    return true
  }
  try {
    return fileIo.accessSync(payloadFilePath(context, relativeName))
  } catch (_error) {
    return false
  }
}

function isCachePayloadFileName(relativeName: string): boolean {
  return (
    relativeName.startsWith(CACHE_PAYLOAD_TOPIC_LIST_PREFIX) ||
    relativeName.startsWith(CACHE_PAYLOAD_TOPIC_DETAIL_PREFIX)
  ) && relativeName.endsWith(CACHE_PAYLOAD_FILE_SUFFIX) &&
    !relativeName.includes(CACHE_PAYLOAD_STAGED_SUFFIX) &&
    isSafePayloadFileName(relativeName)
}

function isCachePayloadArtifactFileName(relativeName: string): boolean {
  if (isCachePayloadFileName(relativeName)) {
    return true
  }
  if (!relativeName.endsWith(CACHE_PAYLOAD_FILE_SUFFIX + CACHE_PAYLOAD_STAGED_SUFFIX)) {
    return false
  }
  return isCachePayloadFileName(relativeName.substring(0, relativeName.length - CACHE_PAYLOAD_STAGED_SUFFIX.length))
}

function isSafePayloadFileName(relativeName: string): boolean {
  if (
    relativeName.length <= 0 ||
    relativeName.startsWith('.') ||
    relativeName.includes('/') ||
    relativeName.includes('\\') ||
    relativeName.includes('..')
  ) {
    return false
  }
  return /^[A-Za-z0-9._-]+$/.test(relativeName)
}

function fnv1a32Byte(hash: number, byte: number): number {
  return Math.imul((hash ^ (byte & 0xFF)) >>> 0, 16777619) >>> 0
}
