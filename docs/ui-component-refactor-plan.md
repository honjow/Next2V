# V2Next UI 组件重构规划

更新时间：2026-05-18
当前 master：`389b26c refactor(search): extract search state coordinator`

## 0. 目标

目标不是重做视觉风格，而是把页面内重复 UI 模式收口到稳定组件层，让页面文件主要保留数据流、导航和业务决策。

本轮重构必须保持用户可见语义：

- 不改变路由名称和参数。
- 不改变登录、写操作、收藏、感谢、屏蔽、搜索等业务语义。
- 不新增假入口、假设置或不可验证的静态控件。
- 不把渲染契约任务混入普通 UI 重构；`MarkdownContent.ets` 继续按独立 rendering contract 推进。

## 1. 当前结构判断

已有共享基础：

- `SecondaryListScaffold`
- `PullRefreshListScaffold`
- `ConciseListRow`
- `GroupedListSection`
- `AppSearchField`
- `AppTextField`
- `AppActionButton`
- `FilterChip`
- `EmptyState`
- `TopicCard`
- `ReplyCard`

主要问题：

1. 页面状态重复：Loading / Error / Login required / Empty 在多个页面内手写。
2. 列表 row 重复：账号关注、屏蔽用户等 member row 重复。
3. 搜索页过重：输入、历史、本地结果、远程结果、筛选 sheet、row/card、数据逻辑混在一个页面。
4. 分页列表模式不统一：初始加载、空态、错误、footer loading、pull refresh 分散实现。
5. `TopicDetailPage` 业务复杂，不能一次大拆。
6. `MarkdownContent` 是渲染专项，不纳入本轮普通 UI lane。

## 2. Lane 顺序

### Lane 1：PageState 组件收口

范围：

- 新增共享页面状态组件。
- 迁移低风险页面中重复的 loading/error/login/empty builder。

候选组件：

- `PageLoadingState`
- `PageErrorState`
- `PageLoginRequiredState`
- `CardEmptyState`

优先迁移页面：

- `feature/user/src/main/ets/pages/UserTopicsPage.ets`
- `feature/user/src/main/ets/pages/UserRepliesPage.ets`
- `entry/src/main/ets/pages/MyNodesPage.ets`
- `entry/src/main/ets/pages/MyTopicsPage.ets`
- `entry/src/main/ets/pages/AccountFollowingPage.ets`
- `entry/src/main/ets/pages/AccountBlacklistPage.ets`
- `feature/node/src/main/ets/pages/NodeTopicPage.ets`

验收：

- 页面原有状态文案不变。
- 重试、去登录等动作保持原行为。
- `git diff --check` 通过。
- `bash dev.sh --build-only` 通过。
- 设备 QA 覆盖至少一个 loading/empty/error/login 状态或可达替代路径，并截图/记录。

### Lane 2：AccountMemberRow 收口

范围：

- 抽 `AccountMemberRow`，统一关注用户、屏蔽用户列表 row。
- 替换页面内重复 avatar + username + subtitle + chevron 结构。

优先迁移页面：

- `entry/src/main/ets/pages/AccountFollowingPage.ets`
- `entry/src/main/ets/pages/AccountBlacklistPage.ets`

验收：

- 头像、用户名、副标题、点击进入用户页行为不变。
- 有数据/空态/未登录状态实机截图。

### Lane 3：SearchPage UI 拆分

范围：

- 只拆 UI 组件，不改搜索数据语义。
- 搜索历史、本地结果、远程结果、筛选 sheet 分离。

候选组件：

- `SearchPanel`
- `SearchHistoryStrip`
- `SearchTopicRow`
- `SearchNodeRow`
- `RemoteTopicRow`
- `SearchFilterSheetContent`

验收：

- 本地、节点库、SOV2EX、网页搜索四种模式入口行为不变。
- 搜索历史保存/清空不变。
- 筛选 sheet 打开/应用/清除行为不变。
- 设备 QA 截图覆盖搜索页主态、筛选 sheet、至少一种结果列表。

### Lane 4：PagedListScaffold 试点

范围：

- 新增高阶分页列表脚手架或扩展现有 scaffold。
- 封装 initial loading、empty、error/retry、pull refresh、load more footer、bottom safe area。

优先试点：

- `entry/src/main/ets/pages/MyTopicsPage.ets`
- `feature/node/src/main/ets/pages/NodeTopicPage.ets`

验收：

- 下拉刷新、触底加载、加载更多失败重试保持不变。
- 空态/错误/有数据/加载更多截图或 layout 证据。

### Lane 5：TopicDetailPage 结构拆分

范围：

- 先拆 UI，不动写操作和解析逻辑。
- 禁止一次性大改。

候选拆分：

- `TopicHeaderCard`
- `ReplyFilterBar`
- `ReplyContextSheet`
- `TopicActionCoordinator`（后续，非第一步）

验收：

- 详情页打开、回复列表、只看楼主、排序、跳楼、回复 sheet、图片预览至少覆盖主路径。
- 写操作相关改动必须保留确认与全局保护语义。

## 3. 明确不做

- 不在普通 UI 重构中修改 `MarkdownContent.ets` 渲染算法。
- 不在 PageState lane 中改业务加载逻辑。
- 不在组件收口时更换页面 IA 或删除入口。
- 不用 disabled 控件掩盖未实现功能。
- 不提交 `.hermes-artifacts/` 截图、layout、日志证据。

## 4. 验证规则

每个 UI lane 必须：

1. `git diff --check`
2. `bash dev.sh --build-only`
3. 按 `AGENTS.md` 的 hdc readiness probe 连接设备。
4. 安装到 `192.168.50.237:12345`。
5. 设备 QA 保存到 `.hermes-artifacts/<yyyymmdd-HHMM>-<lane>-qa/`。
6. QA 结果包含 `validation-summary.md` 和 `result.json`。
7. `result.json` 必须有 `verdict`、`summary`、`artifact_dir`、`commands`、`changed_files`、`evidence`、`commit`。

如果设备 probe 不输出 `ok`，该 lane 的设备 QA 记为 `BLOCKED`，不得把 build 通过当作 UI PASS。

## 5. 当前执行入口

从 Lane 1 开始：

1. 新增 shared PageState 组件。
2. 先迁移 `UserTopicsPage` / `UserRepliesPage` 两个相似页面。
3. build + device QA。
4. PASS 后再继续迁移账号本地列表页。

## 6. 执行记录

### 2026-05-17 Lane 1 第一批

状态：PASS

变更：

- 新增 `shared/src/main/ets/components/PageState.ets`。
- 从 shared 入口导出 `PageLoadingState`、`PageErrorState`、`PageLoginRequiredState`、`CardEmptyState`。
- 迁移 `UserTopicsPage` 和 `UserRepliesPage` 的 loading/error/empty/footer loading 重复 builder。

验证：

- `git diff --check` 通过。
- `bash dev.sh --build-only` 通过。
- 已安装到 `192.168.50.237:12345` 并完成实机 QA。
- 证据目录：`.hermes-artifacts/20260517-2115-page-state-lane1-qa/`。
- 实机路径覆盖：发现页主题 -> 作者用户页 -> `查看全部主题` -> `全部主题`；用户页回复 tab -> `查看全部回复` -> `全部回复`。

后续入口：

1. 继续 Lane 1，迁移 `MyNodesPage` / `MyTopicsPage` / `AccountFollowingPage` / `AccountBlacklistPage`。
2. 每批保持小范围迁移、build-only、实机 QA。

### 2026-05-17 Lane 1 第二批

状态：PASS

变更：

- 迁移 `MyTopicsPage` / `MyNodesPage` 的登录、加载、错误、空态。
- 迁移 `AccountFollowingPage` / `AccountBlacklistPage` 的登录、加载、错误和列表内空态。
- 保持原有路由、文案和重试/去登录动作。

验证：

- `git diff --check` 通过。
- `bash dev.sh --build-only` 通过。
- 已安装到 `192.168.50.237:12345` 并完成实机 QA。
- 证据目录：`.hermes-artifacts/20260517-2131-page-state-account-qa/`。
- 实机路径覆盖：账号页 -> `收藏主题`、`收藏节点`、`关注用户`、`屏蔽与忽略`。
- 覆盖状态：收藏主题有数据、收藏节点有数据、关注用户有数据、屏蔽与忽略列表内空态。

后续入口：

1. 完成 Lane 1 剩余 `feature/node/src/main/ets/pages/NodeTopicPage.ets`。
2. 进入 Lane 2，抽 `AccountMemberRow` 收口关注/屏蔽用户 row。

### 2026-05-17 Lane 1 第三批

状态：PASS

变更：

- 迁移 `NodeTopicPage` 的初始 loading overlay 内部实现、空态和错误态到共享 PageState。
- 保留原 Stack + PullRefreshListScaffold 结构、分页、下拉刷新、加载更多错误和节点收藏动作。

验证：

- `git diff --check` 通过。
- `bash dev.sh --build-only` 通过。
- 已安装到 `192.168.50.237:12345` 并完成实机 QA。
- 证据目录：`.hermes-artifacts/20260517-2137-page-state-node-topic-qa/`。
- 实机路径覆盖：账号页 -> `收藏节点` -> `iPhone` 节点主题页。

Lane 1 结论：完成。下一步进入 Lane 2，抽 `AccountMemberRow`。

### 2026-05-17 Lane 2

状态：PASS

变更：

- 新增 `shared/src/main/ets/components/AccountMemberRow.ets`。
- 从 shared 入口导出 `AccountMemberRow`。
- 迁移 `AccountFollowingPage` 和 `AccountBlacklistPage` 的 member row，保留原点击进入用户页行为。
- 保留关注用户头像 placeholder、用户名、副标题、右侧箭头和卡片视觉。

验证：

- `git diff --check` 通过。
- `bash dev.sh --build-only` 通过。
- 已安装到 `192.168.50.237:12345` 并完成实机 QA。
- 证据目录：`.hermes-artifacts/20260517-2142-account-member-row-qa/`。
- 实机路径覆盖：账号页 -> `关注用户`；账号页 -> `屏蔽与忽略`。
- 覆盖状态：关注用户有数据 row、屏蔽与忽略空态。

Lane 2 结论：完成。下一步进入 Lane 3，拆分 `SearchPage` UI 层，先只抽展示组件，不改变搜索数据语义。

### 2026-05-17 Lane 3 第一批

状态：PASS

变更：

- 新增 `entry/src/main/ets/components/SearchPageComponents.ets`。
- 抽出 `SearchPanelHeader`，承载搜索输入、加载/错误提示和来源 chip。
- 抽出 `SearchHistoryStrip`，承载历史标题、清空入口和历史关键词 chip。
- 抽出 `SearchTopicRow` / `SearchNodeRow` / `RemoteTopicRow`，承载本地主题、节点和 SOV2EX 结果 row。
- 抽出 `ExternalWebSearchCard`，承载网页搜索模式卡片。
- `SearchPage` 保留搜索状态、过滤、远程请求、历史持久化、导航和 sheet 状态，不改变业务语义。

验证：

- `git diff --check` 通过。
- `bash dev.sh --build-only` 通过。
- 已安装到 `192.168.50.237:12345` 并完成实机 QA。
- 证据目录：`.hermes-artifacts/20260517-2149-search-ui-components-qa/`。
- 实机路径覆盖：应用内搜索路由 `https://www.v2ex.com/search?q=apple` -> 本地结果 -> `SOV2EX` 结果 -> 搜索筛选 sheet -> 清空关键词后的搜索历史。

后续入口：

1. Lane 3 第二批继续拆筛选 sheet 内容，但必须保持远程筛选状态和执行时机不变。
2. 如果 sheet 拆分引入 `@Link` 状态较多，优先拆本地筛选内容，再拆远程筛选内容。

### 2026-05-17 Lane 3 第二批

状态：PASS

变更：

- 在 `SearchPageComponents.ets` 中抽出 `LocalSearchFilterSheetContent`。
- 在 `SearchPageComponents.ets` 中抽出 `RemoteSearchFilterSheetContent`。
- 将 `SearchResultFilter` 和 `RemoteDateRange` 类型移入搜索组件文件统一导出。
- `SearchPage` 保留筛选状态写入、远程搜索执行、结果重置和 sheet 关闭时机。

验证：

- `git diff --check` 通过。
- `bash dev.sh --build-only` 通过。
- 已安装到 `192.168.50.237:12345` 并完成实机 QA。
- 证据目录：`.hermes-artifacts/20260517-2155-search-filter-components-qa/`。
- 实机路径覆盖：应用内搜索路由 `https://www.v2ex.com/search?q=apple` -> 本地筛选 sheet -> SOV2EX 远程筛选 sheet -> 作者输入 `Dream4U` -> 键盘收起后的远程筛选 sheet。

Lane 3 结论：主要 UI 拆分完成。后续若继续瘦身，优先评估是否抽搜索数据/状态 viewmodel；不要在同一 lane 中再扩大到网络语义。

### 2026-05-17 Lane 4 第一批

状态：PASS

变更：

- 新增 `shared/src/main/ets/components/PagedListScaffold.ets`。
- 从 shared 入口导出 `PagedListScaffold`。
- `PagedListScaffold` 收口分页列表的初始 loading、初始 error/retry、empty、`PullRefreshListScaffold` 包装和底部 `LoadingFooter`。
- 迁移 `MyTopicsPage`，保留登录态、两步验证、数据请求、分页去重、toast 和路由行为。

验证：

- `git diff --check` 通过。
- `bash dev.sh --build-only` 通过。
- 已安装到 `192.168.50.237:12345` 并完成实机 QA。
- 证据目录：`.hermes-artifacts/20260517-2208-paged-list-my-topics-qa/`。
- 实机路径覆盖：账号页 -> `收藏主题` -> 有数据列表 -> 连续上滑触发分页/后续主题渲染。

后续入口：

1. Lane 4 第二批再评估 `NodeTopicPage` 是否适合接入 `PagedListScaffold`。
2. `NodeTopicPage` 当前有 loading overlay、节点收藏状态和加载更多错误重试，迁移时必须保留这些页面级交互，不强行一次收口。

### 2026-05-17 Lane 4 第二批

状态：PASS

变更：

- 扩展 `PagedListScaffold`，支持可选隐藏 footer、加载更多错误文案和显式重试按钮文案。
- 扩展 `LoadingFooter`，保留默认“加载失败，点击重试”的点击重试语义，同时支持页面传入错误文案和按钮式重试。
- 迁移 `NodeTopicPage` 接入 `PagedListScaffold`，保留节点主题 loading overlay、空态、错误态、下拉刷新、触底加载、加载更多失败重试和节点收藏相关状态。
- 避免给 `PagedListScaffold` 增加第二个 `@BuilderParam`；ArkUI 尾随 builder 调用要求组件只有一个 `@BuilderParam`。

验证：

- `git diff --check` 通过。
- `bash dev.sh --build-only` 通过。
- 已安装到 `192.168.50.237:12345` 并完成实机 QA。
- 证据目录：`.hermes-artifacts/20260517-2217-paged-list-node-topic-qa/`。
- 实机路径覆盖：应用内路由 `https://www.v2ex.com/go/apple` -> `Apple` 节点主题页 -> 连续上滑触发分页/后续主题渲染。

Lane 4 结论：`PagedListScaffold` 已完成 `MyTopicsPage` 和 `NodeTopicPage` 两个试点。下一步进入 Lane 5 前，先拆分范围较小、可独立验证的 `TopicDetailPage` 展示组件，不碰写操作和解析逻辑。

### 2026-05-17 Lane 5 第一批

状态：PASS

范围：

- 只拆 `TopicDetailPage` 的回复列表展示组件。
- 不改主题正文解析、Markdown 渲染、回复编辑器、感谢、收藏、屏蔽、举报、复制、图片预览、链接跳转等行为逻辑。

变更：

- 新增 `feature/detail/src/main/ets/components/TopicDetailComponents.ets`。
- 抽出 `TopicDetailReplyDivider`，承载回复数量、楼层跳转、回复显示模式菜单和“最新”入口。
- 抽出 `ReplyContextSheetContent` 和 `ReplyContextListItem`，承载回复上下文 sheet 外壳和上下文预览条目。
- `TopicDetailPage` 保留状态、楼层计算、菜单状态、跳转和回调行为。

验收：

- `git diff --check` 通过。
- `bash dev.sh --build-only` 通过。
- 已安装到 `192.168.50.237:12345` 并完成实机 QA。
- 证据目录：`.hermes-artifacts/20260517-2226-topic-detail-components-qa/`。
- 实机路径覆盖：`Apple` 节点主题页 -> 第一条主题详情 -> 回复工具条 -> 显示模式菜单 -> 回复操作菜单 -> `#2 回复上下文` sheet。

后续入口：

1. `TopicDetailPage` 下一批仍只拆纯展示：优先评估主题头部元信息卡或预加载进度/footer。
2. 写回复、感谢、收藏、屏蔽、举报、解析和 Markdown 渲染继续保持原页面内逻辑，不在同一批移动。

### 2026-05-17 Lane 5 第二批

状态：PASS

范围：

- 继续只拆 `TopicDetailPage` 的纯展示组件。
- 不改主题正文 Markdown、补充内容解析、图片/链接/mention 点击、写回复、感谢、收藏、屏蔽、举报等行为逻辑。

变更：

- 在 `TopicDetailComponents.ets` 中抽出 `TopicDetailHeader`，承载主题作者、发布时间、节点 tag 和标题展示。
- `TopicDetailHeader` 通过 `onTitleAreaChange` 回传标题测量结果，`TopicDetailPage` 继续负责 appbar identity 显隐状态。
- 抽出 `TopicRepliesPreloadIndicator`，承载回复预加载进度展示。
- `TopicDetailPage` 保留主题正文、补充内容、导航参数和所有交互行为。

验证：

- `git diff --check` 通过。
- `bash dev.sh --build-only` 通过。
- 已安装到 `192.168.50.237:12345` 并完成实机 QA。
- 证据目录：`.hermes-artifacts/20260517-2251-topic-detail-header-qa/`。
- 实机路径覆盖：`Apple` 节点主题页 -> 第一条主题详情 -> 主题头部/正文渲染 -> 连续上滑触发 appbar identity 与回复区展示。

Lane 5 展示拆分结论：低风险展示层已拆出回复工具条、回复上下文、主题头部和预加载提示。后续若继续拆 `TopicDetailPage`，应进入行为协调或正文渲染边界，风险显著高于当前批次。

### 2026-05-17 Lane 6 第一批

状态：PASS

范围：

- 先拆 `SearchPage` 本地结果构建逻辑，降低页面内数据合并和排序代码量。
- 不改搜索入口、历史记录、远端 Web 搜索、节点索引加载、筛选 sheet 和结果点击行为。

变更：

- 新增 `SearchLocalResultBuilder`，集中处理本地主题/节点搜索结果的匹配、去重、来源合并和排序。
- `SearchPage` 保留 keyword/source/filter 状态、缓存加载、远端搜索时序和页面交互，只调用 builder 接收 `topicResults` 与 `nodeResults`。
- 保留原有本地搜索来源优先级：收藏主题、最近浏览、详情缓存、列表缓存、关注节点、节点库。

验证：

- `git diff --check` 通过。
- `bash dev.sh --build-only` 通过。
- 已安装到 `192.168.50.237:12345` 并完成实机 QA。
- 证据目录：`.hermes-artifacts/20260517-2256-search-local-builder-qa/`。
- 实机路径覆盖：应用内路由 `https://www.v2ex.com/search?q=apple` -> 本地搜索结果渲染 -> 本地筛选 sheet 展开。

后续入口：

1. `SearchPage` 后续可继续拆状态协调，但应先明确远端搜索、本地搜索、历史记录三条状态线的职责边界。
2. 下一步按计划进入 `TopicDetailPage` 行为协调拆分，优先选择纯协调、无写操作、无网络请求的上下文构建逻辑。

### 2026-05-17 Lane 7 第一批

状态：PASS

范围：

- 拆 `TopicDetailPage` 回复上下文构建协调逻辑。
- 不改回复感谢、回复提交、主题收藏/感谢、屏蔽/举报、Markdown 渲染、图片预览、链接跳转和网络请求。

变更：

- 新增 `ReplyContextCoordinator`，集中生成回复上下文 sheet 的条目。
- 将上文/下文楼层、当前回复、当前回复 mention 到的历史作者、后续提到当前作者的回复等上下文规则移出页面。
- `TopicDetailPage` 保留 sheet 显隐、标题、跳转到楼层和 UI 事件接线。

验证：

- `git diff --check` 通过。
- `bash dev.sh --build-only` 通过。
- 已安装到 `192.168.50.237:12345` 并完成实机 QA。
- 证据目录：`.hermes-artifacts/20260517-2301-reply-context-coordinator-qa/`。
- 实机路径覆盖：应用内路由 `https://www.v2ex.com/go/apple` -> 第一条主题详情 -> 回复操作菜单 -> `查看上下文` -> `#1 回复上下文` sheet，确认 `当前回复`、`提到 @di11wei`、`下文` 条目渲染。

后续入口：

1. `TopicDetailPage` 仍有较重的写操作与网络行为，后续拆分必须按“单一行为族 + 实机 QA”的节奏推进。
2. 下一批可评估把回复/主题 action preparation 拆成 service/coordinator，但感谢、收藏、屏蔽、举报属于有副作用行为，不能和展示/上下文构建混在一批。

### 2026-05-18 Lane 7 第二批

状态：PASS

范围：

- 拆 `TopicDetailPage` action 协调中的纯解析、文案和本地状态处理。
- 不移动 AlertDialog、toast、网络调用、登录 cookie 读取、真实感谢/收藏/忽略/举报执行。
- 不改变主题 action command payload、topicId 过滤、菜单入口、确认弹窗按钮和副作用保护语义。

变更：

- 新增 `TopicDetailActionCoordinator`。
- 将 topic action command 解析移出页面，并继续按 topicId 过滤当前前台详情页。
- 将主题收藏/感谢/忽略/举报确认文案、回复 action 文案、解析失败 fallback 文案集中到 coordinator。
- 将回复感谢状态 JSON 读取和写入集中到 coordinator，`TopicDetailPage` 仍负责 view model 标记和持久状态字段赋值。

验证：

- `git diff --check` 通过。
- `bash dev.sh --build-only` 通过。
- 已安装到 `192.168.50.237:12345` 并完成实机 QA。
- 证据目录：`.hermes-artifacts/20260518-0002-topic-detail-action-coordinator-qa/`。
- 实机路径覆盖：应用内路由 `https://www.v2ex.com/go/apple` -> 第一条主题详情 -> 更多 action 菜单 -> `忽略主题` 确认弹窗 -> 取消，不执行真实忽略。

后续入口：

1. 下一批若继续拆 action 行为，应只选一个行为族，例如 topic favorite/thank 或 reply thank。
2. 涉及真实写操作执行时，必须明确账号状态和副作用回滚策略；未明确前只验证确认/取消和未登录提示路径。

### 2026-05-18 Lane 7 第三批

状态：PASS

范围：

- 按剩余计划依序完成：
  1. action 行为族的前置 guard 收口。
  2. 阅读/滚动协调逻辑收口。
- 不移动真实写操作执行、AlertDialog、toast、cookie 读取、view model 网络请求、页面滚动器实例。
- 不改变楼层编号、列表 index 偏移、阅读位置保存/恢复、目标楼层跳转、回复预加载上限和 action 未登录/已感谢/缺失提示语义。

变更：

- 扩展 `TopicDetailActionCoordinator`，集中 topic thank、reply thank、topic/reply moderation 的前置 guard 与 topic thank 状态解析。
- 新增 `TopicDetailScrollCoordinator`，集中回复列表末尾 index、跳楼输入解析、楼层到列表 index 映射、阅读中心 index 到回复 index 映射、目标楼层预加载循环。
- `TopicDetailPage` 继续负责 UIContext、CollectionSettings、DetailViewModel、Scroller、toast/dialog 和真实副作用执行。

验证：

- `git diff --check` 通过。
- `bash dev.sh --build-only` 通过。
- 已安装到 `192.168.50.237:12345` 并完成实机 QA。
- 证据目录：`.hermes-artifacts/20260518-0012-topic-detail-action-scroll-coordinator-qa/`。
- 实机路径覆盖：应用内路由 `https://www.v2ex.com/go/apple` -> 第一条主题详情 -> 连续滚动到回复区 -> 更多 action 菜单 -> `忽略主题` 确认弹窗 -> 取消，不执行真实忽略。

后续入口：

1. `TopicDetailPage` 后续若继续拆，应转向更高风险的真实写操作执行器或 ReplyComposerSheet，必须一批一个行为族。
2. `SearchPage` 仍可拆本地/远端/网页搜索状态协调，但需覆盖本地结果、SOV2EX、filter sheet 和历史记录。

### 2026-05-18 Lane 7 第四批

状态：PASS

范围：

- 拆回复编辑器中的纯文本协调逻辑。
- 覆盖 `ReplyComposerSheet` 和独立 `ReplyEditorPage` 两个回复编辑入口。
- 不移动真实回复提交、草稿 I/O、AlertDialog、toast、UIContext、ApiService 调用和页面关闭/刷新副作用。
- 保留 sheet 与独立页的差异：sheet 保存节流仍为 600ms，独立页保存节流仍为 500ms；独立页提交按钮继续受 cookie gate 约束。

变更：

- 新增 `ReplyComposerCoordinator`，集中 initial content 归一化、草稿/mention 合并、Markdown inline/line prefix 插入、提交可用性判断和 sheet 编辑区高度计算。
- `ReplyComposerSheet` 调用 coordinator 处理 initialContent watch、草稿合并、Markdown toolbar 插入、提交按钮 enabled 和 keyboard 高度下的编辑区高度。
- `ReplyEditorPage` 调用同一 coordinator 处理草稿合并、Markdown toolbar 插入和基础提交可用性，同时保留原 cookie gate、提交确认文案、成功后返回页面和草稿保存时序。

验证：

- `git diff --check` 通过。
- `bash dev.sh --build-only` 通过。
- 只读 review：PASS。
- 已安装到 `192.168.50.237:12345` 并完成实机 QA。
- 证据目录：`.hermes-artifacts/20260518-0140-reply-composer-coordinator-qa/`。
- 实机路径覆盖：应用内路由 `https://www.v2ex.com/go/apple` -> 第一条主题详情 -> 打开回复 sheet -> 输入 `qa_test_reply` -> Markdown bold 插入 `**文字**` -> 预览渲染 -> 清空草稿确认 -> 清空后提交按钮恢复 disabled。

后续入口：

1. `ReplyComposerSheet` / `ReplyEditorPage` 仍有草稿 I/O 和提交状态机重复；下一批如继续拆，应先抽 draft persistence adapter，仍不移动真实提交执行。
2. `TopicDetailPage` 的真实感谢/收藏/忽略/举报执行器仍属高风险区；若继续，应一批只选一个行为族，并覆盖确认/取消与未提交真实副作用路径。

### 2026-05-18 Lane 7 第五批

状态：PASS

范围：

- 继续拆回复编辑器草稿状态机。
- 覆盖 `ReplyComposerSheet` 和独立 `ReplyEditorPage` 两个入口。
- 不移动真实回复提交、提交确认弹窗、toast 文案、页面关闭/刷新副作用和各入口的节流差异。
- 保留差异：sheet 无 `isSaving` gate；独立页继续有 `isSaving` gate 和清空成功/失败 toast。

变更：

- 新增 `ReplyComposerDraftCoordinator`，集中草稿初始 state、load draft + initialContent merge、保存判断、保存时间戳和清草稿调用。
- `ReplyComposerSheet` 通过 draft coordinator 初始化/加载/保存/清空草稿，仍保留 600ms 节流、关闭时保存、提交成功后 `hasSubmitted` 防止再次保存。
- `ReplyEditorPage` 通过 draft coordinator 初始化/加载/保存/清空草稿，仍保留 500ms 节流、`isSaving` gate、清空 toast、提交成功后清草稿并返回。

验证：

- `git diff --check` 通过。
- `bash dev.sh --build-only` 通过。
- 只读 review：PASS。
- 已安装到 `192.168.50.237:12345` 并完成实机 QA。
- 证据目录：`.hermes-artifacts/20260518-0152-reply-composer-draft-coordinator-qa/`。
- 实机路径覆盖：应用内路由 `https://www.v2ex.com/go/apple` -> 第一条主题详情 -> 打开回复 sheet -> 输入 `draft_state_qa` -> 关闭 sheet -> 重新打开并确认草稿恢复 -> 清空草稿确认 -> 清空后 TextArea 为空且提交按钮 disabled。

后续入口：

1. 下一步进入 `SearchPage` 状态协调拆分，先明确本地搜索、远端 SOV2EX、网页搜索、历史记录四条状态线，避免混入 UI 视觉变更。
2. `ReplyComposerSheet` / `ReplyEditorPage` 剩余提交前状态机可后续单独拆，但真实 `ApiService.submitReplyWithCookie` 仍不应和 Search lane 混在一起。

### 2026-05-18 Lane 8 第一批

状态：PASS

范围：

- 拆 `SearchPage` 中的纯状态/决策 helper。
- 不移动本地集合加载、缓存加载、节点库加载、SOV2EX 网络请求、历史记录 I/O、浏览器启动和页面导航。
- 不改本地搜索、远端搜索、网页搜索和 filter sheet 的触发时机。

变更：

- 新增 `SearchPageStateCoordinator`。
- 集中 action command 解析、pending search query 解析、source/filter 结果显示判断、文案、remote reset state、remote filter 判断、date range 到 `gte`、SOV2EX hit 到 UI item 映射、highlight 清洗和外部搜索 URL 构建。
- `SearchPage` 继续负责状态字段、加载副作用、SOV2EX 请求执行、历史记录持久化、sheet 显隐和导航。

验证：

- `git diff --check` 通过。
- `bash dev.sh --build-only` 通过。
- 只读 review：PASS。
- 已安装到 `192.168.50.237:12345` 并完成实机 QA。
- 证据目录：`.hermes-artifacts/20260518-0159-search-state-coordinator-qa/`。
- 实机路径覆盖：应用内路由 `https://www.v2ex.com/search?q=apple` -> SOV2EX 模式空态/筛选 sheet -> 切换节点库本地搜索 -> `主题结果 19` -> 本地 filter sheet。

后续入口：

1. `SearchPage` 下一批如继续拆，应优先抽 `RemoteSearchCoordinator`，但仍需要保留 remote 输入 reset、日期立即请求、apply 才关闭 sheet、分页 from 语义。
2. 本轮用户指定顺序里的第 3 项进入 `TopicDetailPage` 单一写操作执行器拆分，建议只选 `reply thank` 或 `topic thank`，并实机只覆盖确认/取消或非破坏路径。
