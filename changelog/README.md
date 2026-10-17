# 版本日志发布流程

从 1.0.11 开始，每个版本使用 `changelog/v<versionName>.md` 作为 GitHub Release 正文。历史版本不自动补写或覆盖。

## 准备版本

1. 以 `AppScope/app.json5` 为版本源，递增 `versionCode`，同步各模块包版本、HAR BuildProfile 和备份元数据回退值。
2. 新建对应版本的 Markdown 日志，按需要使用“新增”“改进”“修复”等分类。内容覆盖上一版本之后的用户可见变化，说明必要的验证限制，不直接粘贴提交列表或敏感诊断数据。
3. 在仓库根目录运行：

   ```bash
   node scripts/test_version_consistency_contract.mjs
   node scripts/test_release_notes_contract.mjs
   GITHUB_REF=refs/tags/v1.0.11 node scripts/test_version_consistency_contract.mjs
   ```

   最后一条的版本应替换为待发布版本。日志缺失、仅含空白、版本漂移或 tag 与版本不一致都会失败。

4. 完成该版本的功能测试、构建和必要的设备验证，将版本文件、日志和代码一起纳入发布提交。

## 发布

按维护者授权推送代码及 `v<versionName>` tag 后，现有 `Build OHOS` 工作流构建 release HAP。发布任务再次校验版本与日志，将对应 Markdown 文件作为 Release 正文，并上传 HAP；普通分支构建不会发布 Release。

当前 workflow 保留原有发布筛选：包含 `stable`、`alpha`、`rc` 的 tag 不进入发布任务，包含 `pre` 的发布标记为预发布。所有 tag 构建仍须与 `versionName` 完全对应；本流程不改变渠道规则。

日志由人工维护，CI 不再自动生成替代正文。修改已发布版本的本地日志不会自动更新远端 Release，需要另行授权同步；应用内展示也不属于此发布流程。
