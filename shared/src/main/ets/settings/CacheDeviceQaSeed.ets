import { common } from '@kit.AbilityKit'
import { relationalStore } from '@kit.ArkData'
import { fileIo } from '@kit.CoreFileKit'
import BuildProfile from '../../../../BuildProfile'
import { V2exMember, V2exNode, V2exReply, V2exTopic } from '../network/NetworkTypes'
import { LocalDataStore } from '../storage/LocalDataStore'
import { CacheSettings, CacheStats } from './CacheSettings'
import { AppStrings } from '../i18n/AppStrings'
import {
  CACHE_KIND_TOPIC_DETAIL,
  CACHE_KIND_TOPIC_LIST,
  CACHE_PAYLOAD_DIR_NAME,
  CACHE_PAYLOAD_FILE_SUFFIX,
  KEY_PREFIX_TOPIC_DETAIL,
  KEY_PREFIX_TOPIC_LIST,
} from './CachePolicy'

const SEED_LIST_KEY_PREFIX: string = KEY_PREFIX_TOPIC_LIST + 'qa-seed-'
const SEED_DETAIL_KEY_PREFIX: string = KEY_PREFIX_TOPIC_DETAIL + '90000'
const SEED_DETAIL_MIXED_ID: number = 900001
const SEED_DETAIL_RESET_IDS: number[] = [900001, 900002, 900003]
const SEED_TOPIC_LIST_FILE_PREFIX: string = 'topic_list_qa_seed_'
const SEED_TOPIC_DETAIL_FILE_PREFIX: string = 'topic_detail_qa_seed_'
const WRONG_PAYLOAD_HASH: string = 'v1:fnv1a32-utf8:1:00000000'
const SQL_UPSERT_CACHE_ENTRY: string = 'INSERT OR REPLACE INTO cache_entries (cache_key, kind, payload_text, payload_path, payload_hash, cached_at, accessed_at, expires_at, size) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)'
const SQL_SELECT_SEED_PAYLOAD_PATHS: string = 'SELECT payload_path FROM cache_entries WHERE cache_key LIKE ? OR cache_key IN (?, ?, ?)'
const SQL_DELETE_SEEDED_CACHE_ROWS: string = 'DELETE FROM cache_entries WHERE cache_key LIKE ? OR cache_key IN (?, ?, ?)'

export interface CacheDeviceQaSeedResult {
  scenario: string
  seededRows: number
  seededFiles: number
  statsBefore: CacheStats
  statsAfter: CacheStats
  notes: string[]
}

interface SeedPayloadCounts {
  rows: number
  files: number
  notes: string[]
}

export class CacheDeviceQaSeed {
  static isEnabled(): boolean {
    return BuildProfile.DEBUG
  }

  static assertEnabled(): void {
    if (!CacheDeviceQaSeed.isEnabled()) {
      throw new Error('Cache device QA seed is available only in debug builds')
    }
  }

  static async seedLargeFileBackedList(context: common.UIAbilityContext): Promise<CacheDeviceQaSeedResult> {
    CacheDeviceQaSeed.assertEnabled()
    return CacheDeviceQaSeed.withResult(context, 'large_file_backed', async (): Promise<SeedPayloadCounts> => {
      await CacheSettings.saveTopicList(context, 'qa-seed-large-list', CacheDeviceQaSeed.largeTopics())
      return {
        rows: 1,
        files: 1,
        notes: ['Saved an over-threshold topic list through CacheSettings.saveTopicList.']
      }
    })
  }

  static async seedMixedInlineFile(context: common.UIAbilityContext): Promise<CacheDeviceQaSeedResult> {
    CacheDeviceQaSeed.assertEnabled()
    return CacheDeviceQaSeed.withResult(context, 'mixed_inline_file', async (): Promise<SeedPayloadCounts> => {
      await CacheSettings.saveTopicList(context, 'qa-seed-mixed-inline', [
        CacheDeviceQaSeed.topic(910001, 'QA seed inline topic', 'inline payload')
      ])
      await CacheSettings.saveTopicDetail(
        context,
        SEED_DETAIL_MIXED_ID,
        CacheDeviceQaSeed.topic(SEED_DETAIL_MIXED_ID, 'QA seed file-backed detail', CacheDeviceQaSeed.largeText(24)),
        CacheDeviceQaSeed.largeReplies()
      )
      return {
        rows: 2,
        files: 1,
        notes: ['Saved a small inline topic list and a large file-backed topic detail through production save paths.']
      }
    })
  }

  static async seedInvalidPathRow(context: common.UIAbilityContext): Promise<CacheDeviceQaSeedResult> {
    CacheDeviceQaSeed.assertEnabled()
    return CacheDeviceQaSeed.withResult(context, 'invalid_path', async (): Promise<SeedPayloadCounts> => {
      const now = CacheDeviceQaSeed.nowSeconds()
      await CacheDeviceQaSeed.upsertRawRow(
        context,
        SEED_LIST_KEY_PREFIX + 'invalid-path',
        CACHE_KIND_TOPIC_LIST,
        '',
        '../outside-cache.json',
        null,
        now,
        now + 3600,
        0
      )
      return {
        rows: 1,
        files: 0,
        notes: ['Inserted traversal payload_path as a DB string only; no fileIo call uses it.']
      }
    })
  }

  static async seedOrphanPayloadFile(context: common.UIAbilityContext): Promise<CacheDeviceQaSeedResult> {
    CacheDeviceQaSeed.assertEnabled()
    return CacheDeviceQaSeed.withResult(context, 'orphan_file', async (): Promise<SeedPayloadCounts> => {
      CacheDeviceQaSeed.writeSafeSeedPayloadFile(
        context,
        SEED_TOPIC_LIST_FILE_PREFIX + 'orphan' + CACHE_PAYLOAD_FILE_SUFFIX,
        JSON.stringify([CacheDeviceQaSeed.topic(910004, 'QA seed orphan file', 'orphan payload')])
      )
      return {
        rows: 0,
        files: 1,
        notes: ['Created an unreferenced safe payload artifact under cache_payloads.']
      }
    })
  }

  static async seedMissingFileRow(context: common.UIAbilityContext): Promise<CacheDeviceQaSeedResult> {
    CacheDeviceQaSeed.assertEnabled()
    return CacheDeviceQaSeed.withResult(context, 'missing_file', async (): Promise<SeedPayloadCounts> => {
      const now = CacheDeviceQaSeed.nowSeconds()
      await CacheDeviceQaSeed.upsertRawRow(
        context,
        SEED_LIST_KEY_PREFIX + 'missing-file',
        CACHE_KIND_TOPIC_LIST,
        '',
        SEED_TOPIC_LIST_FILE_PREFIX + 'missing' + CACHE_PAYLOAD_FILE_SUFFIX,
        null,
        now,
        now + 3600,
        128
      )
      return {
        rows: 1,
        files: 0,
        notes: ['Inserted a safe file-backed row whose payload file is intentionally absent.']
      }
    })
  }

  static async seedHashMismatchRow(context: common.UIAbilityContext): Promise<CacheDeviceQaSeedResult> {
    CacheDeviceQaSeed.assertEnabled()
    return CacheDeviceQaSeed.withResult(context, 'hash_mismatch', async (): Promise<SeedPayloadCounts> => {
      const now = CacheDeviceQaSeed.nowSeconds()
      const payload = JSON.stringify([CacheDeviceQaSeed.topic(910007, 'QA seed hash mismatch', 'hash mismatch payload')])
      const fileName = SEED_TOPIC_LIST_FILE_PREFIX + 'hash_mismatch' + CACHE_PAYLOAD_FILE_SUFFIX
      CacheDeviceQaSeed.writeSafeSeedPayloadFile(context, fileName, payload)
      await CacheDeviceQaSeed.upsertRawRow(
        context,
        SEED_LIST_KEY_PREFIX + 'hash-mismatch',
        CACHE_KIND_TOPIC_LIST,
        null,
        fileName,
        WRONG_PAYLOAD_HASH,
        now,
        now + 3600,
        payload.length
      )
      return {
        rows: 1,
        files: 1,
        notes: ['Inserted a safe file-backed topic list row with an intentionally wrong payload_hash.']
      }
    })
  }

  static async validateHashMismatchRepair(context: common.UIAbilityContext): Promise<CacheDeviceQaSeedResult> {
    CacheDeviceQaSeed.assertEnabled()
    return CacheDeviceQaSeed.withResult(context, 'hash_mismatch_validate', async (): Promise<SeedPayloadCounts> => {
      const topics = await CacheSettings.loadTopicList(context, 'qa-seed-hash-mismatch')
      return {
        rows: 0,
        files: 0,
        notes: ['Production read returned ' + topics.length.toString() + ' topics; expected cache miss after hash mismatch cleanup.']
      }
    })
  }

  static async seedExpiredRow(context: common.UIAbilityContext): Promise<CacheDeviceQaSeedResult> {
    CacheDeviceQaSeed.assertEnabled()
    return CacheDeviceQaSeed.withResult(context, 'expired_row', async (): Promise<SeedPayloadCounts> => {
      const now = CacheDeviceQaSeed.nowSeconds()
      const payload = JSON.stringify([CacheDeviceQaSeed.topic(910006, 'QA seed expired row', 'expired payload')])
      await CacheDeviceQaSeed.upsertRawRow(
        context,
        SEED_LIST_KEY_PREFIX + 'expired',
        CACHE_KIND_TOPIC_LIST,
        payload,
        null,
        null,
        now - 7200,
        now - 3600,
        payload.length
      )
      return {
        rows: 1,
        files: 0,
        notes: ['Inserted an expired cache row; loadStats/loadKeyIndex should remove it.']
      }
    })
  }

  static async resetSeededCache(context: common.UIAbilityContext): Promise<CacheDeviceQaSeedResult> {
    CacheDeviceQaSeed.assertEnabled()
    return CacheDeviceQaSeed.withResult(context, 'reset_seeded', async (): Promise<SeedPayloadCounts> => {
      const store = await LocalDataStore.open(context)
      const payloadPaths = await CacheDeviceQaSeed.selectSeedPayloadPaths(store)
      await store.executeSql(SQL_DELETE_SEEDED_CACHE_ROWS, CacheDeviceQaSeed.seedRowArgs())
      const removedFiles = CacheDeviceQaSeed.deleteSeedPayloadFiles(context, payloadPaths)
      return {
        rows: SEED_DETAIL_RESET_IDS.length + 1,
        files: removedFiles,
        notes: ['Removed seed-prefixed rows and seed-created payload files only.']
      }
    })
  }

  static async seedAll(context: common.UIAbilityContext): Promise<CacheDeviceQaSeedResult[]> {
    CacheDeviceQaSeed.assertEnabled()
    const results: CacheDeviceQaSeedResult[] = []
    results.push(await CacheDeviceQaSeed.seedLargeFileBackedList(context))
    results.push(await CacheDeviceQaSeed.seedMixedInlineFile(context))
    results.push(await CacheDeviceQaSeed.seedInvalidPathRow(context))
    results.push(await CacheDeviceQaSeed.seedOrphanPayloadFile(context))
    results.push(await CacheDeviceQaSeed.seedMissingFileRow(context))
    results.push(await CacheDeviceQaSeed.seedHashMismatchRow(context))
    results.push(await CacheDeviceQaSeed.seedExpiredRow(context))
    return results
  }

  private static async withResult(
    context: common.UIAbilityContext,
    scenario: string,
    action: () => Promise<SeedPayloadCounts>
  ): Promise<CacheDeviceQaSeedResult> {
    const statsBefore = await CacheSettings.loadStats(context)
    const counts = await action()
    const statsAfter = await CacheSettings.loadStats(context)
    return {
      scenario: scenario,
      seededRows: counts.rows,
      seededFiles: counts.files,
      statsBefore: statsBefore,
      statsAfter: statsAfter,
      notes: counts.notes
    }
  }

  private static async upsertRawRow(
    context: common.UIAbilityContext,
    cacheKey: string,
    kind: string,
    payloadText: string | null,
    payloadPath: string | null,
    payloadHash: string | null,
    cachedAt: number,
    expiresAt: number,
    size: number
  ): Promise<void> {
    const store = await LocalDataStore.open(context)
    const args: relationalStore.ValueType[] = [cacheKey, kind, payloadText, payloadPath, payloadHash, cachedAt, cachedAt, expiresAt, size]
    await store.executeSql(SQL_UPSERT_CACHE_ENTRY, args)
  }

  private static async selectSeedPayloadPaths(store: relationalStore.RdbStore): Promise<string[]> {
    const resultSet = await store.querySql(SQL_SELECT_SEED_PAYLOAD_PATHS, CacheDeviceQaSeed.seedRowArgs())
    const paths: string[] = []
    try {
      const pathIndex = resultSet.getColumnIndex('payload_path')
      while (resultSet.goToNextRow()) {
        if (!resultSet.isColumnNull(pathIndex)) {
          const payloadPath = resultSet.getString(pathIndex)
          if (payloadPath.length > 0) {
            paths.push(payloadPath)
          }
        }
      }
    } finally {
      resultSet.close()
    }
    return paths
  }

  private static seedRowArgs(): relationalStore.ValueType[] {
    return [
      SEED_LIST_KEY_PREFIX + '%',
      KEY_PREFIX_TOPIC_DETAIL + SEED_DETAIL_RESET_IDS[0].toString(),
      KEY_PREFIX_TOPIC_DETAIL + SEED_DETAIL_RESET_IDS[1].toString(),
      KEY_PREFIX_TOPIC_DETAIL + SEED_DETAIL_RESET_IDS[2].toString()
    ]
  }

  private static deleteSeedPayloadFiles(context: common.UIAbilityContext, payloadPaths: string[]): number {
    const candidates = new Set<string>()
    payloadPaths.forEach((payloadPath: string) => {
      if (CacheDeviceQaSeed.isSafeSeedPayloadFileName(payloadPath)) {
        candidates.add(payloadPath)
      }
    })
    try {
      fileIo.listFileSync(CacheDeviceQaSeed.payloadBaseDir(context)).forEach((fileName: string) => {
        if (CacheDeviceQaSeed.isSeedCreatedPayloadFileName(fileName)) {
          candidates.add(fileName)
        }
      })
    } catch (_error) {
    }
    let removed = 0
    candidates.forEach((fileName: string) => {
      if (CacheDeviceQaSeed.unlinkSafeSeedPayloadFile(context, fileName)) {
        removed += 1
      }
    })
    return removed
  }

  private static writeSafeSeedPayloadFile(context: common.UIAbilityContext, fileName: string, payloadText: string): void {
    if (!CacheDeviceQaSeed.isSafeSeedPayloadFileName(fileName)) {
      throw new Error(AppStrings.text(AppStrings.R_CACHE_INVALID_SEED_FILENAME, 'Invalid QA seed cache filename'))
    }
    try {
      fileIo.mkdirSync(CacheDeviceQaSeed.payloadBaseDir(context), true)
    } catch (_error) {
    }
    let file: fileIo.File | null = null
    try {
      file = fileIo.openSync(
        CacheDeviceQaSeed.payloadFilePath(context, fileName),
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC
      )
      fileIo.writeSync(file.fd, payloadText)
    } finally {
      CacheDeviceQaSeed.closeFileBestEffort(file)
    }
  }

  private static unlinkSafeSeedPayloadFile(context: common.UIAbilityContext, fileName: string): boolean {
    if (!CacheDeviceQaSeed.isSafeSeedPayloadFileName(fileName) && !CacheDeviceQaSeed.isProductionSeedPayloadFileName(fileName)) {
      return false
    }
    try {
      fileIo.unlinkSync(CacheDeviceQaSeed.payloadFilePath(context, fileName))
      return true
    } catch (_error) {
      return false
    }
  }

  private static closeFileBestEffort(file: fileIo.File | null): void {
    if (!file) {
      return
    }
    try {
      fileIo.closeSync(file)
    } catch (_error) {
    }
  }

  private static isSeedCreatedPayloadFileName(fileName: string): boolean {
    return CacheDeviceQaSeed.isSafeSeedPayloadFileName(fileName) || CacheDeviceQaSeed.isProductionSeedPayloadFileName(fileName)
  }

  private static isProductionSeedPayloadFileName(fileName: string): boolean {
    if (!CacheDeviceQaSeed.isSafePayloadFileName(fileName) || !fileName.endsWith(CACHE_PAYLOAD_FILE_SUFFIX)) {
      return false
    }
    return fileName.startsWith('topic_list_746f7069634c6973743a71612d736565642d') ||
      fileName.startsWith('topic_detail_746f70696344657461696c3a3930303030')
  }

  private static isSafeSeedPayloadFileName(fileName: string): boolean {
    if (!CacheDeviceQaSeed.isSafePayloadFileName(fileName) || !fileName.endsWith(CACHE_PAYLOAD_FILE_SUFFIX)) {
      return false
    }
    return fileName.startsWith(SEED_TOPIC_LIST_FILE_PREFIX) || fileName.startsWith(SEED_TOPIC_DETAIL_FILE_PREFIX)
  }

  private static isSafePayloadFileName(fileName: string): boolean {
    if (
      fileName.length <= 0 ||
      fileName.startsWith('.') ||
      fileName.includes('/') ||
      fileName.includes('\\') ||
      fileName.includes('..')
    ) {
      return false
    }
    return /^[A-Za-z0-9._-]+$/.test(fileName)
  }

  private static payloadBaseDir(context: common.UIAbilityContext): string {
    return context.filesDir + '/' + CACHE_PAYLOAD_DIR_NAME
  }

  private static payloadFilePath(context: common.UIAbilityContext, fileName: string): string {
    return CacheDeviceQaSeed.payloadBaseDir(context) + '/' + fileName
  }

  private static largeTopics(): V2exTopic[] {
    const topics: V2exTopic[] = []
    for (let i = 0; i < 50; i++) {
      topics.push(CacheDeviceQaSeed.topic(920000 + i, 'QA seed large list ' + i.toString(), CacheDeviceQaSeed.largeText(7)))
    }
    return topics
  }

  private static largeReplies(): V2exReply[] {
    const replies: V2exReply[] = []
    for (let i = 0; i < 36; i++) {
      replies.push({
        id: 930000 + i,
        thanks: 0,
        content: CacheDeviceQaSeed.largeText(9),
        content_rendered: '<p>' + CacheDeviceQaSeed.largeText(9) + '</p>',
        member: CacheDeviceQaSeed.member(i),
        created: CacheDeviceQaSeed.nowSeconds() - i,
        last_modified: CacheDeviceQaSeed.nowSeconds() - i,
        floor: i + 1
      })
    }
    return replies
  }

  private static topic(id: number, title: string, content: string): V2exTopic {
    return {
      id: id,
      title: title,
      url: 'https://www.v2ex.com/t/' + id.toString(),
      content: content,
      content_rendered: '<p>' + content + '</p>',
      replies: 0,
      member: CacheDeviceQaSeed.member(id),
      node: CacheDeviceQaSeed.node(),
      created: CacheDeviceQaSeed.nowSeconds(),
      last_modified: CacheDeviceQaSeed.nowSeconds(),
      last_touched: CacheDeviceQaSeed.nowSeconds()
    }
  }

  private static member(seed: number): V2exMember {
    return {
      id: 940000 + seed,
      username: 'qa_seed_user_' + seed.toString(),
      tagline: 'cache qa seed',
      avatar_mini: '',
      avatar_normal: '',
      avatar_large: ''
    }
  }

  private static node(): V2exNode {
    return {
      id: 950001,
      name: 'qa-seed',
      title: 'QA Seed',
      title_alternative: 'QA Seed',
      url: 'https://www.v2ex.com/go/qa-seed',
      topics: 1,
      avatar_mini: '',
      avatar_normal: '',
      avatar_large: ''
    }
  }

  private static largeText(kilobytes: number): string {
    const unit = 'qa-seed-cache-payload-0123456789 '
    let value = ''
    while (value.length < kilobytes * 1024) {
      value += unit
    }
    return value
  }

  private static nowSeconds(): number {
    return Math.floor(Date.now() / 1000)
  }
}
