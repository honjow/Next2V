export const KEY_PREFIX_TOPIC_LIST: string = 'topicList:'
export const KEY_PREFIX_TOPIC_DETAIL: string = 'topicDetail:'
export const KEY_PREFIX_NODE_DETAIL: string = 'nodeDetail:'
export const KEY_CACHE_INDEX: string = 'cacheIndex'

export const CACHE_KIND_TOPIC_LIST: string = 'topic_list'
export const CACHE_KIND_TOPIC_DETAIL: string = 'topic_detail'
export const CACHE_KIND_NODE_DETAIL: string = 'node_detail'
// Every expiry/clear/size/stats/index SQL keys off this list, so adding node_detail here brings it
// under the same lifecycle automatically (row-count pruning is added explicitly in CacheSettings).
export const CACHE_KINDS_SQL: string = `'${CACHE_KIND_TOPIC_LIST}', '${CACHE_KIND_TOPIC_DETAIL}', '${CACHE_KIND_NODE_DETAIL}'`

// Offline cache policy. These values are intentionally centralized here so
// callers keep treating AppStorage as UI projection, not durable cache state.
export const TOPIC_LIST_TTL_SECONDS: number = 7 * 24 * 60 * 60
export const TOPIC_DETAIL_TTL_SECONDS: number = 30 * 24 * 60 * 60
export const NODE_DETAIL_TTL_SECONDS: number = 30 * 24 * 60 * 60
export const MAX_TOPIC_LIST_ROWS: number = 32
export const MAX_TOPIC_DETAIL_ROWS: number = 200
export const MAX_NODE_DETAIL_ROWS: number = 200
export const MAX_TOPIC_LIST_ITEMS: number = 50
export const FILE_PAYLOAD_THRESHOLD_BYTES: number = 256 * 1024
export const MAX_CACHE_PAYLOAD_SIZE: number = 20 * 1024 * 1024

export const CACHE_PAYLOAD_DIR_NAME: string = 'cache_payloads'
export const CACHE_PAYLOAD_TOPIC_LIST_PREFIX: string = 'topic_list_'
export const CACHE_PAYLOAD_TOPIC_DETAIL_PREFIX: string = 'topic_detail_'
export const CACHE_PAYLOAD_FILE_SUFFIX: string = '.json'
export const CACHE_PAYLOAD_STAGED_SUFFIX: string = '.staged'
export const MAX_CACHE_PAYLOAD_FILENAME_STEM_LENGTH: number = 180
