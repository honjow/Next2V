# V2Next 持久化收口摘要

更新时间：2026-05-17
当前 master：`3f02c0d feat(storage): migrate collection data to RDB`

## 已完成

- 轻量设置继续使用 Preferences；settings key/store/bootstrap/descriptor cleanup 已完成。
- `SearchSettings.searchHistory` 已迁入 `LocalDataStore` RDB。
- `CollectionSettings` 已完成 split/prep、saved-node 修复，并迁入 RDB。
- Collection 最终语义：saved topics、saved nodes、viewed topics、read positions、read states 均以 RDB 为 source of truth；schema `v4`；clean break，无 Preferences migration/dual-read fallback；legacy Preferences keys 仅 best-effort deletion。
- `CacheSettings` 已完成 metadata RDB、TTL/LRU policy、大 payload 文件化、原子写、debug QA seed、payload hash/read-time repair、helper split。

## 当前验证清单

- `node scripts/test_collection_rdb_contract.mjs`
- `node scripts/test_collection_settings_contract.mjs`
- `node scripts/test_local_data_store_contract.mjs`
- `node scripts/test_settings_storage_contract.mjs`
- `node scripts/test_blocked_topic_filter.mjs`
- `node scripts/test_search_history_rdb_contract.mjs`
- `node scripts/test_cache_settings_rdb_contract.mjs`
- `node scripts/test_cache_payload_hash_repair_contract.mjs`
- `node scripts/test_cache_device_qa_seed_static.mjs`
- `git diff --check`

## 可选后续

当前无 blocker。后续只按独立 spec 选择推进：

- `DraftSettings` RDB。
- `NotificationSettings` RDB/cache policy。
- `BlockedMemberSettings` RDB decision。
- `LocalDataStore` schema/store split，保持行为不变，除非新增 domain tables 否则不 bump schema。
- 统一 debug local-data seed panel。
