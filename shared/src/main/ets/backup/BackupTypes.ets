export const BACKUP_MAGIC: string = 'NEXT2V_BACKUP'
export const BACKUP_APP_ID: string = 'com.honjow.next2v'
// v1: plaintext-only envelope (preferences/drafts/collections/search/notifications).
// v2: adds the optional, encryption-only `userInfo` section (accounts + credentials).
// minSupported stays 1 so plaintext v1 files keep importing into newer builds, while a
// v2 file that carries userInfo is always wrapped by the encrypted container below.
export const BACKUP_SCHEMA_VERSION: number = 2
export const BACKUP_MIN_SUPPORTED_SCHEMA_VERSION: number = 1
export const BACKUP_FILE_SUFFIX: string = '.next2v-backup.json'
export const BACKUP_CHECKSUM_ALGORITHM: string = 'SHA-256'
export const MAX_BACKUP_BYTES: number = 10 * 1024 * 1024

export type BackupSectionName =
  | 'preferences'
  | 'drafts'
  | 'collections'
  | 'search'
  | 'notifications'
  | 'userInfo'

// Plaintext-eligible sections. `userInfo` is intentionally excluded here: it carries login
// credentials and may only travel inside the encrypted container, never in a plaintext envelope.
export const BACKUP_SECTION_NAMES: BackupSectionName[] = [
  'preferences',
  'drafts',
  'collections',
  'search',
  'notifications',
]

// Sections that are only valid when the envelope is sealed by the encrypted container.
export const BACKUP_ENCRYPTED_ONLY_SECTION_NAMES: BackupSectionName[] = ['userInfo']

// ── Encrypted container (outer wrapper around a signed plaintext envelope) ──
export const BACKUP_CIPHER_ALGORITHM: string = 'AES-256-GCM'
export const BACKUP_KDF_ALGORITHM: string = 'PBKDF2-SHA256'
export const BACKUP_KDF_ITERATIONS: number = 210000
export const BACKUP_KDF_KEY_SIZE: number = 32
export const BACKUP_CIPHER_SALT_BYTES: number = 16
export const BACKUP_CIPHER_IV_BYTES: number = 12
export const BACKUP_CIPHER_TAG_BYTES: number = 16

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
  userInfo?: BackupUserInfoCount
}

export interface BackupUserInfoCount {
  accounts: number
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
  userInfo?: BackupUserInfoSection
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

// User info section: account list plus their login credentials. This shape mirrors the
// settings-layer account record but is duplicated here so the backup layer keeps its own
// stable serialization contract and does not import the settings credential types
// (the secret-exclusion contract forbids that in plaintext-eligible files).
export interface BackupUserInfoSection {
  activeAccountId: string
  accounts: BackupAccountRecord[]
}

export interface BackupAccountRecord {
  id: string
  username: string
  avatar: string
  loginMode: string
  baseUrl: string
  cookieSnapshot: string
  tokenSnapshot: string
  validatedAt: number
  addedAt: number
  updatedAt: number
}

// ── Encrypted container wrapper ──
// A backup that contains userInfo is serialized as a signed plaintext envelope, then
// sealed inside this container. The container keeps magic/appId so import can still
// recognize "this is an encrypted Next2V backup" without the password, and records the
// algorithm + KDF parameters needed to derive the key and decrypt.
export interface BackupCipherMeta {
  cipher: string
  kdf: string
  iterations: number
  keySize: number
  salt: string
  iv: string
}

export interface BackupEncryptedEnvelope {
  magic: string
  appId: string
  schemaVersion: number
  minSupportedSchemaVersion: number
  encrypted: boolean
  createdAt: string
  appVersion: string
  appVersionCode: number
  cipherMeta: BackupCipherMeta
  ciphertext: string
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
  // True when the raw file is a recognized Next2V backup sealed by the encrypted container.
  // In that case `ok` is false and `code` is 'password_required'; the caller must prompt for a
  // password and call the decrypt path. Never set when a plaintext envelope parses.
  encrypted?: boolean
  code: string
  message: string
}

export interface BackupRestoreResult {
  ok: boolean
  restoredSections: BackupSectionName[]
  failedSections: BackupSectionName[]
  message: string
}
