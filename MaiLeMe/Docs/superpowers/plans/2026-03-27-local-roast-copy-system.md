# 2026-03-27 本地毒舌文案系统实施计划

## 当前状态
- 状态：进行中（Task 1 - Task 10 已完成开发，待整理提交）
- 当前工作分支：`codex/local-roast-copy-system-phase2`
- 当前工作区：`/Users/fengjinyi/Desktop/MaiLeMe-worktrees/local-roast-copy-system-phase2`
- 当前验证：`xcodebuild test -quiet -project MaiLeMe.xcodeproj -scheme MaiLeMeTests -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4'` 已通过（32 tests success，0 error summaries，0 test failure summaries）

## 已完成任务

### Task 1：测试目标与分类骨架
- 提交：`91ceea3` `feat: add item taxonomy foundation`
- 结果：建立条目一级/二级分类基础设施与测试基线。

### Task 2：条目分类元数据持久化与一致性
- 提交：
  - `20868e0` `feat: store category metadata on items`
  - `c0e7cc5` `test: verify item metadata swiftdata round trip`
  - `355eb3f` `fix: lock primary category to secondary taxonomy`
  - `bdbc31c` `fix: add unresolved category metadata states`
- 结果：条目具备分类来源、置信度、行为标签、不确定状态及一致性收敛。

### Task 3：分类识别器与行为标签推断
- 提交：
  - `564d65d` `feat: infer item categories and behavior tags`
  - `dac16c6` `fix: harden local category inference rules`
- 结果：支持本地基于商品名进行分类与行为语义推断。

### Task 4：添加条目流程接入自动识别与手动兜底
- 提交：`019815c` `feat: add category recognition to add item flow`
- 结果：AddItem 流程支持自动识别、手动修正与提交时同步收敛。

### Task 5：结构化文案资源与加载器
- 提交：
  - `557d2dc` `feat: add structured copy assets and loader`
  - `8263a73` `test: strengthen copy asset loading coverage`
- 结果：建立模块化 JSON 文案资源与加载器。

### Task 6：场景解释器、记忆层与解析器
- 提交：
  - `5fe8a4a` `feat: add copy resolution engine`
  - `2154944` `test: harden copy resolver scene selection`
- 结果：支持场景判断、层级回退、轮换记忆与稳定输出。

### Task 7：兼容层接管 `AppConstants.RoastCopy`
- 提交：
  - `03c913f` `refactor: route roast copy APIs through resolver`
  - `977b509` `test: tighten roast copy compatibility bridge`
- 结果：旧文案 API 已路由进新 resolver，保留兼容兜底。

### Task 8：核心流程接入分类感知文案
- 提交：
  - `8da36dd` `feat: use category-aware copy in core item flows`
  - `f6891ae` `test: stabilize category-aware core copy flows`
- 结果：决策仪式、打卡仪式、吃灰挽救核心路径已接入分类上下文。

## 本轮新增完成项

### Task 9：把分类感知文案接入剩余核心界面
目标文件：
- `MaiLeMe/Services/NotificationManager.swift`
- `MaiLeMe/Views/Screens/SavedAmountDetailScreen.swift`
- `MaiLeMe/Views/Screens/DarkRoomScreen.swift`
- `MaiLeMe/Views/Screens/ExtractorScreen.swift`
- `MaiLeMeTests/CopyResolverTests.swift`

完成情况：
- 通知入口已透传 `itemID / primaryCategory / secondaryCategory / behaviorTags`
- 省钱复盘页面已接入分类感知的 headline / body / retrospective copy
- 决策 / 打卡全屏仪式页分享文案已透传条目分类语义
- Mock 通知工厂已补齐新签名，避免调试入口掉回旧链路
- 新增重复记忆去重保护，修复空状态文案在首屏重绘时持续写入 `CopyMemoryStore` 导致的白屏卡顿
- `CopyResolverTests` 已补强 savedReview / emptyState / share 的计数、slot 与 itemID 断言

### Task 10：补全文案资源校验与文档
目标产物：
- `CopyAssetValidator.swift`
- 校验器测试
- 架构/分类/编辑指南文档

完成情况：
- 新增 `CopyAssetValidator`，覆盖模块归属、ID 唯一性、变量契约、过滤冲突、非正权重、关键 scene/slot 覆盖矩阵
- `CopyAssetValidatorTests` 已从 loader smoke test 升级为真实 validator 测试
- 新增三份文档：
  - `COPY_SYSTEM_ARCHITECTURE.md`
  - `CATEGORY_TAXONOMY.md`
  - `COPY_EDITOR_GUIDE.md`
- 更新 `README.md`、`ROAST_COPY_GUIDE.md`、`DIRECTORY_STRUCTURE.md`、`TECH_ARCHITECTURE_V1.0.md`

## 待办清单
1. 按 Task 9 / Task 10 的边界整理提交。
2. 决定后续是否合并回 `main`。

## 风险与备注
- 主仓库仍保留两个旧 stash：一个是 Task 9 草稿来源，一个是更早前的图标误改草稿；当前未恢复，避免污染 `main`。
- 当前所有新增实现都应继续遵守“本地离线优先、无后端依赖”的设计边界。
