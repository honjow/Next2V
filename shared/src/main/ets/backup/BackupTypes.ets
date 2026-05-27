export const BACKUP_MAGIC: string = 'NEXT2V_BACKUP'
export const BACKUP_APP_ID: string = 'com.honjow.next2v'
export const BACKUP_SCHEMA_VERSION: number = 1
export const BACKUP_MIN_SUPPORTED_SCHEMA_VERSION: number = 1
export const BACKUP_FILE_SUFFIX: string = '.next2v-backup.json'
export const BACKUP_CHECKSUM_ALGORITHM: string = 'SHA-256'
export const MAX_BACKUP_BYTES: number = 10 * 1024 * 1024

export type BackupSectionName = 'preferences' | 'drafts' | 'collections' | 'search' | 'notifications'

export const BACKUP_SECTION_NAMES: BackupSectionName[] = [
  'preferences',
  'drafts',
  'collections',
  'search',
  'notifications'
]

export interface BackupChecksum {
  algorithm: string
  value: string
}

export interface BackupEnvelopeV1 {
  magic: string
  appId: string
  schemaVersion: number
  minSupportedSchemaVersion: number
  createdAt: string
  appVersion: string
  appVersionCode: number
  sections: BackupSectionName[]
  counts: BackupCountsV1
  data: BackupDataV1
  checksum?: BackupChecksum
}

export interface BackupCountsV1 {
  preferences: number
  drafts: BackupDraftsCount
  collections: BackupCollectionsCount
  search: BackupSearchCount
  notifications: BackupNotificationsCount
}

export interface BackupDraftsCount {
  replyDrafts: number
  topicDraft: number
}

export interface BackupCollectionsCount {
  savedTopics: number
  savedNodes: number
  viewedTopics: number
  readPositions: number
  readStates: number
}

export interface BackupSearchCount {
  history: number
}

export interface BackupNotificationsCount {
  items: number
}

export interface BackupDataV1 {
  preferences?: BackupPreferencesSection
  drafts?: BackupDraftsSection
  collections?: BackupCollectionsSection
  search?: BackupSearchSection
  notifications?: BackupNotificationsSection
}

export interface BackupPreferencesSection {
  apiDomain?: BackupApiDomainPreferences
  language?: BackupLanguagePreferences
  theme?: BackupThemePreferences
  appearance?: BackupAppearancePreferences
  media?: BackupMediaPreferences
  reading?: BackupReadingPreferences
  reply?: BackupReplyPreferences
  feedTabs?: BackupFeedTabsPreferences
  autoDailyCheckin?: BackupAutoDailyCheckinPreferences
}

export interface BackupApiDomainPreferences {
  baseUrl: string
  useCoDomain?: boolean
}

export interface BackupLanguagePreferences {
  mode: string
}

export interface BackupThemePreferences {
  mode: string
}

export interface BackupAppearancePreferences {
  avatarAppearance: string
}

export interface BackupMediaPreferences {
  autoLoadImages: boolean
  onlyLoadImagesOnWifi: boolean
}

export interface BackupReadingPreferences {
  textScale: number
  lineHeight: number
  density: string
  restorePosition: boolean
  base64DecodeMode: string
}

export interface BackupReplyPreferences {
  displayMode: string
  cardStyle: string
  actionAlignmentMode: string
}

export interface BackupFeedTabsPreferences {
  visibleKeys: string
}

export interface BackupAutoDailyCheckinPreferences {
  enabled: boolean
}

export interface BackupDraftsSection {
  replyDrafts: Object[]
  topicDraft?: Object | null
}

export interface BackupCollectionsSection {
  savedTopics: Object[]
  savedNodes: Object[]
  viewedTopics: Object[]
  readPositions: Object[]
  readStates: Object[]
}

export interface BackupSearchSection {
  history: string[]
  sourceMode: string
}

export interface BackupNotificationsSection {
  ownerKey: string
  items: Object[]
  page: number
  hasMore: boolean
  updatedAt: number
}

export interface BackupPreview {
  createdAt: string
  appVersion: string
  appVersionCode: number
  sections: BackupSectionName[]
  counts: BackupCountsV1
  warning: string
}

export interface BackupValidationResult {
  ok: boolean
  code: string
  message: string
}

export interface BackupParseResult {
  ok: boolean
  envelope?: BackupEnvelopeV1
  code: string
  message: string
}

export interface BackupRestoreResult {
  ok: boolean
  restoredSections: BackupSectionName[]
  failedSections: BackupSectionName[]
  message: string
}
