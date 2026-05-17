# V2Next 持久化与本地数据重构探究/规划

更新时间：2026-05-17
当前 master：`a63813a feat(storage): migrate cache metadata to RDB`

## 1. 当前已完成事项

### 设置项持久化优化已合入

已完成并合入 master 的阶段：

- Phase 1：集中 StorageKeys 使用与 AppStorage helper
  - `54efd94 refactor(settings): centralize storage keys and app storage helper`
- Phase 2A：提取启动设置恢复链到 `SettingsBootstrap`
  - `5f8805a refactor(settings): extract startup settings bootstrap`
- Phase 2B：启动阶段复用 `next2v_settings` preferences store
  - `754e1d8 refactor(settings): reuse startup settings preferences store`
- Phase 2C：最小 typed descriptor
  - `7f86239 refactor(settings): introduce minimal typed descriptors`
- Reading text scale schema clean break
  - `221286e refactor(settings): rename reading scale storage key`
  - merge：`1794a20 merge: lane/reading-text-scale-drop-legacy`

### Reading text scale 最新决策

用户明确决定：不用管历史，丢掉历史包袱。

当前语义：

- 使用 `StorageKeys.READING_TEXT_SCALE = 'readingTextScale'`。
- 已移除 app source/tests 中 `READING_FONT_SIZE` / `readingFontSize`。
- `ReadingSettings.normalizeTextScale` 是纯 scale 语义：
  - 不再把旧 `12/14/18` 字号值转换为 scale。
  - 超出上限直接 clamp 到 `TEXT_SCALE_MAX`。
- 旧用户只保存了 legacy `readingFontSize` 时，阅读缩放会回默认值；这是已接受行为。

验证证据：

- Review PASS：`/home/gamer/v2next-worktrees/reading-text-scale-drop-legacy/.hermes-artifacts/reading-text-scale-drop-legacy-review/summary.md`
- 237 设备 QA PASS：`/home/gamer/v2next-worktrees/reading-text-scale-drop-legacy/.hermes-artifacts/reading-text-scale-drop-legacy-qa/validation-summary.md`
- 集成记录：`/home/gamer/git/V2Next/.hermes-artifacts/reading-text-scale-drop-legacy-integrate/summary.md`

## 1.1 持久化重构 Lane4-Lane6 落地状态（2026-05-17）

当前 controller 计划中的三条后续 lane 已全部完成、集成并推送到 `origin/master`。

统一 artifact 基线：

- `/home/gamer/v2next-worktrees/rdb-migration-decision/.hermes-artifacts/direct-controller-20260517-121703/`

当前 master 最新提交：

- `a63813a feat(storage): migrate cache metadata to RDB`

最近相关提交：

- `a63813a feat(storage): migrate cache metadata to RDB`
- `c011976 refactor(storage): split collection settings helpers`
- `d368eab docs(agents): define direct worker controller mode`
- `1e746ec feat(storage): migrate search history to RDB`
- `ba97a8d docs(storage): add persistence refactor plan`

### Lane4：SearchSettings.searchHistory 迁移到 RDB

状态：完成并已推送。

结果：

- `SearchSettings` 的搜索历史迁移到 RDB/`LocalDataStore`。
- 增加/更新搜索历史、LocalDataStore、settings storage 合约测试。
- 文档冲突集成时保留了主线 bootstrap/controller 说明和 lane 执行决策。

提交：

- lane commit：`5002917`
- master integration commit：`1e746ec feat(storage): migrate search history to RDB`
- 文档保护提交：`ba97a8d docs(storage): add persistence refactor plan`

关键证据：

- Review：`lane4_review-result.json`
- QA：`lane4_qa-result.json`
- Integrate：`lane4_integrate-result.json`

### Lane5：CollectionSettings split/prep

状态：完成并已推送。

结果：

- 暂不做 CollectionSettings 全量 RDB 迁移。
- 先完成职责拆分/准备：`CollectionTypes`、`CollectionLimits`、`CollectionParsers`、`LocalDataPublisher`。
- Preferences 仍是 saved topics / saved nodes / viewed / read state 的 source of truth。
- 增加 `test_collection_settings_contract.mjs`。

重要修复：

- 首次 QA 发现 saved-node 回归：本地关注节点 toggle 后 Account 仍显示 0，SavedNodes 为空，重启后不持久化。
- Root cause：Node appbar action 缺 `nodeName`，NodeTopicPage 无法过滤目标节点；缺 node identity 时可能写脏数据。
- 处理链：fix worker -> re-review -> re-QA -> integrate。
- 原始失败证据保留为 `lane5_qa_initial_fail-result.json`，最终 canonical QA 结果为 `lane5_qa-result.json`。

提交：

- `c011976 refactor(storage): split collection settings helpers`

关键证据：

- Implementation：`lane5_impl-result.json`
- 初次 QA FAIL：`lane5_qa_initial_fail-result.json`
- Fix：`lane5_fix_saved_node-result.json`
- Review after fix：`lane5_review-result.json`
- QA after fix：`lane5_qa-result.json`
- Integrate：`lane5_integrate-result.json`
- 设备 QA 摘要：`lane5-collection-settings-split-qa-after-fix/validation-summary.md`

### Lane6：CacheSettings cache metadata 迁移到 RDB

状态：完成并已推送。

结果：

- `CacheSettings` 的列表/详情 cache metadata 迁移到 RDB。
- `LocalDataStore` schema 升到 v3。
- 保持 `CacheSettings` 对外 API 和可见行为。
- 增加 `test_cache_settings_rdb_contract.mjs`，并更新 LocalDataStore/SearchHistory 相关合约测试。

提交：

- `a63813a feat(storage): migrate cache metadata to RDB`

设备 QA 覆盖：

- 设备：`192.168.50.237:12345`
- fresh install/run。
- Home 列表缓存、Detail 缓存、Search 离线缓存来源。
- Storage settings 缓存计数显示。
- force-stop/restart 后缓存计数保持。
- clear cache 只清离线 cache，计数归零。
- 证据目录包含 10 张截图和 10 个 layout dump。

关键证据：

- Implementation：`lane6_impl-result.json`
- Review：`lane6_review-result.json`
- QA：`lane6_qa-result.json`
- Integrate：`lane6_integrate-result.json`
- 设备 QA 摘要：`lane6-cache-rdb-qa/validation-summary.md`

### 当前验证状态

主仓库 `/home/gamer/git/V2Next`：

- `master...origin/master`
- clean

已复跑并通过：

- `node scripts/test_cache_settings_rdb_contract.mjs`
- `node scripts/test_local_data_store_contract.mjs`
- `node scripts/test_search_history_rdb_contract.mjs`
- `node scripts/test_settings_storage_contract.mjs`
- `git diff --check`

当前无 in-progress controller stage，无 blocker。

## 2. 当前持久化形态

### Preferences / ArkData 用户首选项

当前大量使用 `@kit.ArkData` 的 `preferences`。

官方文档要点（离线文档）：

- 模块：`@ohos.data.preferences`
- 定位：Key-Value 轻量数据持久化。
- 支持值类型：number / string / boolean 及对应数组。
- 单 value 最大 16MB。
- 文档明确说明：首选项无法保证进程并发安全，多进程场景存在文件损坏和数据丢失风险。

当前适合继续用 Preferences 的数据：

- 主题模式。
- API 域名开关。
- 图片加载设置。
- 阅读设置。
- 回复展示模式。
- 自动签到开关。
- 其他小型 enum / boolean / number 配置。

当前不适合继续大量堆在 Preferences 的数据：

- topic/cache 列表与详情缓存。
- 收藏/稍后读。
- 浏览历史。
- 已读状态。
- 阅读位置。
- 草稿列表。
- 搜索历史。
- 通知缓存。
- blocked members 列表。

### AppStorage

当前 `StorageKeys` 同时服务于：

- preferences-backed user settings。
- auth/session/local-data/cache metadata。
- runtime window/layout state。
- navigation/action-bus / one-shot events。

重要定位：

- `AppStorage` / `@StorageLink` / `@StorageProp` 不是磁盘持久化层。
- 它是当前进程内 UI 状态发布/同步机制。
- 推荐语义：
  - Preferences/RDB/File = source of truth。
  - AppStorage = UI projection / runtime state bus。

## 3. 当前代码观察

### 设置类状态

`shared/src/main/ets/settings/` 下当前情况：

- 已使用 `STORE_NAME_SETTINGS = 'next2v_settings'` 的用户设置：
  - `ApiDomainSettings.ets`
  - `ThemeSettings.ets`
  - `MediaSettings.ets`
  - `ReadingSettings.ets`
  - `AutoDailyCheckinSettings.ets`
  - `ReplyDisplaySettings.ets`
  - `ReplyCardStyleSettings.ets`
  - `ReplyActionAlignmentSettings.ets`
- 已有 `loadFromStore` 启动复用路径：上述 `next2v_settings` 启动设置类。
- 已 descriptor 化：
  - `ReplyDisplaySettings`
  - `ReplyCardStyleSettings`
  - `ReplyActionAlignmentSettings`

暂不应 descriptor 化或需谨慎：

- `ThemeSettings`：有系统色彩模式副作用。
- `ApiDomainSettings`：影响 HttpClient base URL 和 cookie/web 域行为。
- `CookieJarSettings`：敏感数据，独立 store。
- `FeedTabSettings`：独立 store + JSON list/selected key。
- `AutoDailyCheckinSettings`：多字段 + 启动服务触发语义。
- `ReadingSettings`：多字段，刚完成 schema clean break；后续可局部整理，但不建议和 descriptor 扩展混做。

### 重复/可抽象点

多处重复：

- `preferences.getPreferences(context, STORE_NAME)`
- `store.getSync(...)`
- `store.putSync(...)`
- `store.flushSync()`
- try/catch 包装中文错误信息
- JSON parse/stringify fallback

高重复/高收益文件：

- `CollectionSettings.ets`：500+ 行，职责包括 saved topics/nodes、viewed topics、read positions、read states、AppStorage count 发布。
- `CacheSettings.ets`：topic list/detail cache + cacheIndex。
- `DraftSettings.ets`：topic draft + reply drafts。
- `SearchSettings.ets`
- `NotificationSettings.ets`
- `BlockedMemberSettings.ets`

## 4. 可选持久化方案

### 4.1 Preferences：继续用于轻量设置

结论：保留，但边界收窄为“设置”。

适合：小型配置、enum/boolean/number/string。

不适合：业务列表、缓存、大 JSON、频繁按 id 更新的数据。

### 4.2 RDB / relationalStore：推荐用于业务本地数据

官方模块：`@ohos.data.relationalStore`

离线文档：

- `JsEtsAPIReference/modules/ohos/@ohos.data.relationalStore (关系型数据库).md`
- `JsEtsAPIReference/types/interfaces/Interface (RdbStore).md`

文档要点：

- 关系型数据库。
- `RdbStore` 支持建表、insert、query、execute 等。
- 有数据库 version，可用于 schema upgrade。
- 官方建议使用 `execute` 初始化表结构和初始数据。

适合迁移的数据：

- `CollectionSettings`
  - saved topics
  - saved nodes
  - viewed topics
  - topic read positions
  - topic read states
- `DraftSettings`
  - topic draft
  - reply drafts
- `SearchSettings`
  - search history
- `NotificationSettings`
  - notification cache / read states（如有）
- `BlockedMemberSettings`
  - blocked members
- `CacheSettings`
  - cache metadata / index / TTL / LRU

推荐理由：

- 这些数据天然是表/行/主键/时间排序/limit/按 id 查询。
- 比 Preferences 里整段 JSON parse/stringify 更稳定。
- 更容易加 schema version、索引、TTL、LRU、repair。

### 4.3 文件存储：适合大 payload / blob

官方模块入口：`@ohos.file.fs` 等 CoreFileKit 能力。

适合：

- 大块 topic detail HTML/rendered raw cache。
- API 原始响应。
- 图片/附件缓存实体。
- debug/export artifact。

不适合：

- 设置项。
- 频繁按 id 查询的小记录。
- 需要事务一致性的列表。

推荐组合：

- RDB 存索引/metadata：id、path、etag/hash、cachedAt、size。
- 文件系统存大内容。

不要用“纯文件目录扫描”代替数据库。

### 4.4 distributedKVStore：暂不建议

官方模块：`@ohos.data.distributedKVStore`

适用场景：跨设备同步 key-value。

当前 V2Next 没有明确跨设备同步需求，引入它会带来同步冲突、权限、设备状态复杂度。

暂不建议。除非后续明确做：

- 多设备阅读位置同步。
- 多设备草稿同步。
- 多设备收藏/历史同步。

### 4.5 DataShare：当前不需要

官方模块：`@ohos.data.dataShare`

偏跨应用/跨能力共享数据。V2Next 当前没有对外共享数据需求。

暂不使用。

## 5. 推荐目标架构

### 用户设置层

继续 Preferences：

- `next2v_settings`
- `next2v_feed_tabs` 可暂留独立 Preferences。
- `CookieJarSettings` / Auth 相关先保持独立，暂不混入普通设置。

继续方向：

- 扩展 `SettingsStorage.ets` 小 helper。
- 继续 contract tests。
- 小心扩展 descriptor。

### 本地业务数据层

新增 RDB：例如 `V2Next.db`。

建议表（初稿）：

- `saved_topics`
  - `topic_id` primary key
  - title/node/member/replies/avatar/json
  - `saved_at`
- `saved_nodes`
  - `node_name` primary key
  - title/topics/avatar/json
  - `saved_at`
- `viewed_topics`
  - `topic_id` primary key
  - topic summary fields
  - `viewed_at`
- `topic_read_positions`
  - `topic_id` primary key
  - `floor`
  - `updated_at`
- `topic_read_states`
  - `topic_id` primary key
  - `touched_at`
  - `updated_at`
- `reply_drafts`
  - `topic_id` primary key
  - `content`
  - `updated_at`
- `topic_draft`
  - can be one-row table or key/value table
- `search_history`
  - query primary/unique
  - `searched_at`
- `blocked_members`
  - username primary key
  - metadata
  - `updated_at`

### 网络缓存层

推荐 RDB + 文件：

- RDB 表：`cache_entries`
  - `cache_key` primary key
  - `kind` topic_list/topic_detail/raw_response
  - `payload_path` or inline payload
  - `cached_at`
  - `expires_at`
  - `size`
  - `etag/hash`
- 大 payload 放文件。
- 小 payload 可直接 RDB text/blob。

增加能力：

- TTL。
- LRU。
- 最大条数/最大大小。
- index repair。
- 清理孤儿文件。

### UI 状态发布层

保留 AppStorage：

- local counts
- read states projection
- runtime layout state
- action bus

建议抽：

- `LocalDataPublisher` / `LocalDataState`
  - 发布 `LOCAL_DATA_UPDATED_AT`
  - 发布 saved/viewed counts
  - 发布 `TOPIC_READ_STATES`

不要让业务 store 同时承担过多 UI 发布职责。

## 6. 建议执行路线

### Lane 1：Store/key 注册表 + contract test

目标：低风险把边界写清楚。

内容：

- 新增 `SettingsStores.ets` 或类似文件，集中 store names：
  - `next2v_settings`
  - `next2v_auth`
  - `next2v_auth_session`
  - `next2v_cookiejar`
  - `next2v_feed_tabs`
  - `next2v_cache`
  - `next2v_collections`
  - `next2v_drafts`
  - `next2v_search`
  - `next2v_notifications`
  - `next2v_blocked_members`
- 不改实际 store string。
- 更新引用。
- contract test 锁定 store names、StorageKeys 分区、不要误合并独立 store。

验证：

- `node scripts/test_settings_storage_contract.mjs`
- `bash dev.sh --build-only`

### Lane 2：Preferences helper for JSON business stores

目标：减少重复代码，不改数据层。

内容：

- 增加 helper：
  - `withPreferencesStore(context, storeName, action)`
  - `readJsonArray`
  - `readJsonObject`
  - `writeJsonValue`
  - `deleteKeysAndFlush`
- 先应用到 `SearchSettings` / `BlockedMemberSettings` / `DraftSettings` 这类边界小的文件。
- 不改 schema，不迁 RDB。

验证：

- 静态 contract tests。
- build-only。
- 若涉及 UI 可见数据，做对应 smoke。

### Lane 3：RDB spike / LocalDataStore skeleton

目标：只建立 RDB 基础设施，不接业务。

内容：

- 新增 `LocalDataStore.ets` / `V2Next.db`。
- `relationalStore.getRdbStore`。
- schema version。
- `execute` 初始化建表。
- 最小表可先建 `schema_meta` 或空业务表。
- 添加 contract test，锁 SQL schema/version。

非目标：

- 不迁 Collections/Drafts/Cache。
- 不改变用户行为。

验证：

- build-only。
- 启动 smoke，确保 DB init 不 crash。

### Lane 4：迁移 SearchSettings.searchHistory 到 RDB（已完成）

实际选择：先迁 SearchSettings.searchHistory，原因：数据量小、UI 验证路径短、风险低于 Collection/Cache。

已落地：

- Search history 使用 RDB 存储。
- clean break，不做旧 Preferences 搜索历史迁移。
- commit：`1e746ec feat(storage): migrate search history to RDB`。

验证：

- `test_search_history_rdb_contract.mjs`
- `test_local_data_store_contract.mjs`
- `test_settings_storage_contract.mjs`
- 独立 review + 设备/行为 QA + integrate 后 master 复跑。

### Lane 5：CollectionSettings split/prep（已完成，未迁 RDB）

目标：降低后续迁移风险，先拆文件职责，再决定 saved topics/nodes 等数据保留策略。

已落地：

- 拆出 `CollectionTypes.ets`、`CollectionLimits.ets`、`CollectionParsers.ets`、`LocalDataPublisher.ets`。
- `CollectionSettings.ets` 继续承载持久化入口，Preferences 仍是 source of truth。
- 增加 `test_collection_settings_contract.mjs`。
- 修复 split/prep 过程中暴露的 saved-node action scoping 回归。
- commit：`c011976 refactor(storage): split collection settings helpers`。

未落地：

- saved topics / saved nodes / viewed topics / read positions / read states 的完整 RDB 迁移。
- 这部分需要先明确是否保留旧数据、是否 clean break、是否分域迁移。

### Lane 6：迁移 CacheSettings cache metadata 到 RDB（已完成第一安全切片）

目标：缓存 metadata 可维护化。

已落地：

- topic list/detail cache metadata 迁移到 RDB。
- 小 payload/metadata 仍走当前 CacheSettings 公共 API，保持 UI 行为不变。
- `LocalDataStore` schema 升级到 v3。
- 增加 `test_cache_settings_rdb_contract.mjs`。
- commit：`a63813a feat(storage): migrate cache metadata to RDB`。

已验证：

- Storage settings cache count。
- Home/detail/search cache-backed 行为。
- force-stop/restart 后 RDB 持久化。
- clear cache 只清 cache，不触发 local-data clear。

后续可选增强：

- TTL / LRU。
- 最大条数/最大大小。
- 大 payload 文件化 + RDB index。
- index repair / orphan cleanup。

## 7. 关键风险/决策点

### 是否保留历史数据

用户这次对 reading scale 已明确：可以丢历史。

但后续每个数据域需单独决策：

- 草稿：通常不应轻易丢。
- 收藏/稍后读：通常不应丢。
- 浏览历史：可以讨论是否丢。
- cache：可以丢。
- search history：可以丢。
- blocked members：不建议丢，除非确认。

### save 语义

当前很多设置是：

1. 先 `apply` 到 AppStorage。
2. 再写 preferences。

风险：写盘失败时 UI 已显示新值，重启后回旧值。

建议定规则：

- 普通 UI 设置：可乐观更新，但失败要有明确处理策略。
- 敏感/业务数据：应 persist 成功后再发布 AppStorage。
- Cookie/Auth/AutoCheckin：不要套普通设置规则。

### RDB 迁移不应和 UI 改版混做

每个 RDB migration lane 应保持：

- UI 不变。
- 行为不变，除非用户明确接受 clean break。
- 先 contract/static tests，再 build，再必要设备 QA。

## 8. 当前执行决策（2026-05-17）

### 旧本地数据策略

项目仍处于非常早期阶段，后续本地业务数据迁 RDB 时可采用 clean break：

- 可以直接丢弃旧 Preferences 本地业务数据。
- 不需要实现 Preferences -> RDB 数据迁移。
- 不需要为旧本地数据设计迁移回滚。
- 不需要围绕 search history / drafts / blocked members 等早期本地数据做保留取舍。
- 仍需保持 UI/API 行为不变；可接受的用户可见变化仅限旧本地数据重置/消失。

### 实机 QA 证据要求

后续所有实机 QA 必须在 fresh QA artifact 目录中保存并在 validation-summary.md 中列出：

- QA verdict。
- 关键命令结果。
- artifact 目录。
- 截图路径。
- layout/dump 路径。
- 关键日志路径。
- 是否已集成/提交/推送。

缺少截图和 layout/dump 证据时，不得把实机 QA 记为 PASS；除非明确说明设备验证不可行并以 BLOCKED/NOT_RUN 处理。

### Controller/agent 推进约定

本系列任务已授权持续按 controller / agent 模式推进：implementation -> review -> QA -> integrate -> next lane。
常规 gate 之间不再询问确认；只有真实 blocker、QA FAIL、REQUEST_CHANGES、需要用户实机/账号输入，或仍未决且会改变用户可见行为的重大 schema 设计问题才停止。

## 9. 新会话固定当前 controller 模式

新会话不要只说“按这个文档继续”，也不要默认调用 Kanban 后等待看板自动推进。建议把下面这段作为新会话启动块直接发给 assistant：

```text
请读取并按 `/home/gamer/git/V2Next/docs/persistence-storage-refactor-plan.md` 继续。

工作模式要求：
1. 先加载 `harmonyos-development-workflow` 和 `session-context-discipline`。
2. 当前聊天就是 controller，不要假设 Kanban 会自动推进。
3. 除非我明确要求使用 Kanban，否则优先使用独立 worktree + `terminal(background=true, notify_on_complete=true)` 后台 worker/reviewer/QA 进程。
4. 每个 worker prompt 必须自包含：repo/worktree/branch、spec、禁止项、验证命令、artifact 路径、commit/summary 输出要求。
5. 每个后台进程完成后，controller 必须立即读 artifact、查 git status/log/diff、复跑关键验证，然后显式派下一 gate：implementation -> review -> QA -> integrate。
6. 常规 PASS gate 之间不要停下来问确认；只有 REQUEST_CHANGES、QA FAIL、build blocker、真实 schema/迁移决策或任务边界不清才停。
7. 汇报只给状态、关键证据、artifact 路径、下一步；不要贴长日志。
```

如果必须使用 Kanban，则需要额外要求：

```text
如果使用 Kanban，看板只是任务容器，不是 controller。必须同时启动/保持 controller loop：定期检查 board/task/runs/log/PID/artifact，发现 todo/blocked/stalled 要主动 dispatch/recover/reassign，并在每个 gate 完成后显式创建或推进下一 gate。不能把“已创建卡片”当作“任务会自动继续”。
```

## 10. 当前情况与下一步候选

当前情况：

- 本轮持久化重构 controller 计划已完成：Lane4 SearchHistory RDB、Lane5 Collection split/prep、Lane6 Cache metadata RDB。
- 主仓库 master 已同步 origin/master，最新 commit `a63813a`。
- 当前无 in-progress controller stage，无 blocker。

已完成的目标架构切片：

- 用户轻量设置：继续 Preferences。
- Search history：已迁 RDB。
- Cache metadata：已迁 RDB。
- CollectionSettings：已拆分职责，但数据仍在 Preferences。
- AppStorage：继续作为 UI projection / runtime bus，不作为 durable source of truth。

下一步候选按风险从低到高：

1. 文档/测试加固
   - 把 Lane4-Lane6 的实际 schema、行为边界、QA 入口整理到更短的开发者说明。
   - 补齐 `LocalDataStore` schema/version 注释和 contract 覆盖说明。

2. Cache 后续增强
   - TTL / LRU / max size。
   - index repair / orphan cleanup。
   - 大 payload 文件化 + RDB index。
   - 风险中等，适合按小 lane 做。

3. CollectionSettings 完整 RDB 迁移
   - saved topics / saved nodes / viewed topics / read positions / read states 分域迁移。
   - 需要先决策旧 Preferences 数据保留策略。
   - 不建议和 UI 改版混做。

4. DraftSettings / BlockedMemberSettings / NotificationSettings RDB 化
   - 草稿和 blocked members 通常不应默认丢数据，需要单独数据保留策略。
   - Notification cache 可视实际业务价值决定是否迁移。

建议下一条实现 lane：

> 基于 `docs/persistence-storage-refactor-plan.md` 和当前 master，推进 CacheSettings TTL/LRU 第一安全切片：只新增过期/容量清理策略和 contract tests，保持 UI 不变；按第 9 节 controller 模式执行 implementation -> review -> QA/build -> integrate。

如果要继续 Collection：

> 先做 CollectionSettings RDB migration spec lane，只产出分域迁移方案和数据保留决策矩阵，不直接改代码；明确 saved topics、saved nodes、viewed topics、read positions、read states 是否保留旧数据、是否 clean break、每域 QA 路径。
