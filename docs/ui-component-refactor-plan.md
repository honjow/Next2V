# V2Next UI 组件重构规划

更新时间：2026-05-17
当前 master：`8a25b3c refactor(entry): split index titlebar components`

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
