# 搜索重构方案(综合搜索)

Date: 2026-06-06
Status: 已定方向,暂不实施(本文为设计文档,等后续排期)

> 衔接并部分取代 [`search-source-research.md`](./search-source-research.md)。该旧文档写于 2026-05-06,当时 `remote` 源还只是"打开浏览器外链";此后代码已接入 **SOV2EX 站内 JSON 全文检索**(`Sov2exService`),`remote` 变成真正的 App 内主题搜索,外链 Bing 拆成了独立的 `externalWeb`。旧文档"不在 App 内抓取 Google/Bing 结果页"的原则**继续有效**——SOV2EX 是 JSON API,不属于结果页抓取,不违反该原则。

---

## 一、背景与目标

当前搜索把"内部实现"当"功能"暴露给用户:主入口是一排 4 个**数据源**切换芯片,逼用户在搜索前先理解 `local / localWithNodes / remote / externalWeb` 的差异。这比多数同类 V2EX 客户端更啰嗦、更割裂,且与发现页存在功能重复。

**重构目标**:把"搜什么"的决策从用户脑里挪回 App 内部。用户输入一次,App 并行给出多个**结果分区**,无需手动切数据源。对齐同类客户端"搜索 = SOV2EX 主题全文、不暴露数据源切换"的主流惯例,同时保留 V2Next 的差异化亮点(本地缓存检索)。

---

## 二、现状诊断(带证据)

### 2.1 四个"数据源"芯片里真正有独立价值的只有 1 个

- 源模式定义:`SearchSourceMode = 'local' | 'localWithNodes' | 'remote' | 'externalWeb'`,默认 `localWithNodes`(`shared/src/main/ets/settings/SearchSettings.ets:19-20`)。
- UI 渲染成四个并排芯片(`entry/src/main/ets/components/SearchPageComponents.ets:278-281`)。

| 源模式 | 真相 | 证据 |
|---|---|---|
| `local` | 与 `localWithNodes` 只差"是否搜全量节点库"一个布尔 | `SearchSourceCoordinator.ets:91` `shouldLoadNodeIndex = nextMode === 'localWithNodes'` |
| `localWithNodes` | 同上;且是默认值 → 默认行为是"先搜本地",非用户预期的"搜全站帖子" | `SearchSettings.ets:20` |
| `remote`(SOV2EX) | 唯一的真·主题全文检索,却只是四选一里的一项,还不是默认 | `Sov2exService`、`RemoteSearchCoordinator.ets` |
| `externalWeb` | 只是拼 Bing 链接跳浏览器,不是 App 内结果 | `SearchPageStateCoordinator.ets:126` `https://www.bing.com/search?q=site:v2ex.com/t ...` |

把"是否含节点"这种内部加载开关做成用户要选的"数据源",是实现细节泄漏。

### 2.2 "节点库"= 搜全量节点,且与发现页节点搜索确凿重复

两处走的是**同一条链**,只是外壳不同:

- 数据源同:都经 `NodeIndexRepository.getNodes()`(内存缓存 `/api/nodes/all.json`)。发现页 `NodeIndexViewModel.loadAllNodes`、搜索页 `SearchLocalDataCoordinator.loadNodeIndex` 同落此方法。
- 算法同:都用 `NodeSearchUtils`(发现页 `applyNodeFilter` → `filter`;搜索页 `SearchLocalResultBuilder.ets:131-151` → `search`)。
- 跳转同:点击结果都进 `NodeTopicList`。
- 差异仅在 UI 皮:发现页卡片网格(`DiscoverNodeCard`),搜索页列表行(`SearchNodeRow`);且各自独立的 keyword 总线(`DiscoverKeywordState` vs `SearchActionState`/`SearchQueryBus`)与各自 `new NodeIndexViewModel()` 实例。

结论:这是**同一功能两套 UI**,不是"恰好相似"。(`NodePickerPage` 是第三处复用同套节点检索,但用途是发帖选节点,属正当复用,不在消重范围。)

### 2.3 "搜用户"是空头维度

- placeholder 承诺"搜索主题/节点/用户"(`search_topics_nodes_users_placeholder`)。
- 实现只是在**已缓存主题的作者名**里做 `includes` 匹配,展示成"该用户相关主题"(`SearchLocalResultBuilder.ets:165-167`,`search_user_related_topics`)。
- 后端硬约束:V2EX 官方无成员模糊搜索接口(只有 `members/show.json?username=` 精确直达);SOV2EX 的 `username` 是精确作者过滤。**无任何后端支持按用户名片段找人。**

承诺 > 实现。

### 2.4 端云同步资产(改造红线)

- `search_history(query PRIMARY KEY, searched_at)`,UPSERT 去重 + 修剪 20 条 + 倒序读取(`SearchSettings.ets:11-17`,`LocalDataStore.ets:19-20`),是 **Phase-1 端云同步表**(列刻意省 NOT NULL 以兼容云同步)。
- **红线:任何改造保持 `search_history` 表结构与端云同步契约不变**(改 schema 会触发已知 `-1108 / can not find schema record type` 类设备缓存问题)。`sourceMode` preferences 键不参与端云 RDB,可安全废弃。

---

## 三、已定决策(用户拍板)

1. **改造方向**:综合搜索单框 + 结果分区,**砍掉源模式手动切换**(方案 A 方向)。本轮先出文档,不动手实现。
2. **发现页消重**:发现页搜索框 → **跳转统一搜索页**;节点检索只在搜索页保留。发现页回归"节点发现/浏览"定位(已关注节点 / 最近浏览节点),不再做平行的节点过滤。
3. **用户维度**:**从 UI 移除**。不做"用户"结果分区,placeholder 改为"搜索主题、节点"。理由:后端做不了模糊找人,留着即误导。

---

## 四、目标形态设计

### 4.1 单输入框 + 结果分区(纵向分区,不分 Tab)

一个 `AppSearchField`,输入后并行产出结果分区,顺序按"命中即时性 + 常用度":

1. **节点**(置顶):本地全量库,即输即出、零延迟。承接原发现页/搜索页两处节点检索,统一到此。
2. **SOV2EX 主题**(主体):提交 / 防抖后拉取,支持翻页 + 现有的作者 / 节点 / 日期 / 排序高级过滤(从"与源模式混在一起"重新归位到"主题分区的可折叠高级筛选")。
3. **本地内容**(差异化亮点,弱化保留):收藏 / 最近浏览 / 离线缓存命中,作为"你看过的相关内容"。

> 不做"用户"分区(见决策 3)。不做顶部分 Tab:一次输入横扫多维度、分区滚动 + 各区"查看更多"比分 Tab 更顺,也避免"我到底搜到了啥"被切碎。

### 4.2 源模式:去掉

`local / localWithNodes / remote` 内部化为默认行为(默认"本地含节点 + SOV2EX 主题");`externalWeb` 从"模式"降级为"动作"——放在 SOV2EX 失败兜底 / 溢出菜单的"在浏览器中搜索",**不占主切换位**。

### 4.3 默认行为与节流

- 输入即本地节点 / 缓存分区秒出。
- 停止输入 ~300ms(防抖)或回车触发 SOV2EX 主题查询,兼顾 SOV2EX / 官方接口限流(官方 1.0 约 120 次/IP/小时,2.0 约 600 次/IP/小时;`all.json` 继续走 `NodeIndexRepository` 缓存)。

### 4.4 历史记录

`search_history` 的 UI 与逻辑**原样保留**。

---

## 五、改动面(不写实现,仅标记大概率要动的文件)

| 文件 | 改动性质 |
|---|---|
| `entry/src/main/ets/pages/SearchPage.ets` | 从"源模式分支渲染"改为"多分区并行渲染"的编排 |
| `entry/src/main/ets/components/SearchPageComponents.ets` | 删 `SourceModeControls`/`SourceModeButton`;重排分区头;placeholder 改"搜索主题、节点";移除用户相关展示 |
| `entry/src/main/ets/model/SearchSourceCoordinator.ets` | "源模式 → 副作用"状态机简化为"输入 → 本地分区即时 + 远程分区按需";`usesNodeIndex` 内部化为默认 true |
| `entry/src/main/ets/model/SearchPageStateCoordinator.ets` | `externalWeb` 从模式降级为兜底动作;Bing 链接逻辑保留但移出主入口 |
| `entry/src/main/ets/model/SearchLocalResultBuilder.ets` / `SearchLocalDataCoordinator.ets` | 节点检索默认纳入,不再受 `usesNodeIndex` 门控;移除 `filter==='users'` 的用户分支 |
| `shared/src/main/ets/settings/SearchSettings.ets` | **废弃** `sourceMode` 持久化(`KEY_SOURCE_MODE` / `loadSourceMode` / `saveSourceMode`);**保留** `search_history` 全部逻辑 |
| `feature/node/src/main/ets/pages/DiscoverPage.ets` | 标题栏搜索框改为跳统一搜索页;移除页内平行节点过滤;保留节点发现/浏览分区 |
| i18n(7 个 locale string.json + AppStrings ResourceManager) | 废弃 `search_topics_nodes_users_placeholder` / `search_user_related_topics` 等用户相关键;新增/调整分区头与空态文案 |

**对 RDB / 端云同步影响:零 schema 变更。** `search_history` 表与端云契约完全不动;只废弃一个不参与端云的 preferences 键(`sourceMode`)。

---

## 六、风险与缓解

- **SOV2EX 是唯一主题全文后端**,第三方服务,可用性 / 索引时效不受控 → 必须保留 Bing(`externalWeb`)作为降级兜底,否则"搜主题"会整体失效。可考虑"SOV2EX 连续失败 N 次 → 显式提示切兜底"。
- **并行分区弱网加载**:各分区独立加载态 / 失败态,一个分区失败不拖垮整页。
- **节点检索消重迁移**:发现页有多个入口(标题栏、深链 `/search?q=`、账户页"本地搜索"项)汇入,迁移时全部对齐到统一搜索页,改动面不小,需逐一排查。

---

## 七、未决 / 后续拍板项

1. **`externalWeb` 引擎**:现用 Bing(`site:v2ex.com/t`)。降级为兜底后是否换 Google CSE / 维持 Bing(国内可达性 Bing 更稳)。旧文档原则:**不在 App 内解析其结果页**,只外开浏览器。
2. **是否给极客留"关掉节点分区"的隐藏开关**:默认不留(徒增复杂度),可后续按需加。
3. **历史记录事务化(顺手项)**:`recordQuery` 的 UPSERT + PRUNE 当前是两条独立 `executeSql`,非单事务(`SearchSettings.ets:42-43`)。改造若触及该文件可顺手收进事务;非本次必须项。

---

## 附录:同类客户端惯例对照

| 维度 | 业界主流 | V2Next 现状 | 重构后 |
|---|---|---|---|
| 搜索 = 什么 | 默认 SOV2EX 主题全文 | 默认 `localWithNodes`(先搜本地) | 综合(节点即时 + SOV2EX 主题 + 本地内容) |
| 数据源切换 | 不暴露;最多藏进高级 options | 主入口 4 芯片手动切 | 去掉,内部化 |
| 节点检索 | 多放独立发现页本地过滤 | 发现页 + 搜索页双处做(重复) | 统一到搜索页;发现页只浏览 |
| 用户搜索 | 业界基本缺失 | placeholder 承诺、实现是作者名匹配 | 从 UI 移除 |
| 外链兜底 | 作为降级藏起来 | 作为主入口一个芯片 | 降级为兜底动作 |

参考客户端:aidevjoe/V2EX、isaced/V2exOS、liaoliao666/v2ex(最完整者亦为"输入即本地过滤节点、回车走 SOV2EX",高级项收进 options,不把数据源摆主入口)。
