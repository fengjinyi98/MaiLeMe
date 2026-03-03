# 买了么（MaiLeMe）V1.0 技术架构文档

最后更新：2026-02-28  
版本：V1.0（MVP）

## 1. 技术选型

### 1.1 客户端
- 语言：Swift 5.x/6.x
- UI：SwiftUI
- 并发：Swift Concurrency（async/await）

### 1.2 本地数据
- 持久化：SwiftData
- 策略：Local First，优先离线可用

### 1.3 后端策略
- V1.0：无后端
- V1.5：CloudKit 同步
- V2.0：按业务需要评估 Firebase 或自建 Go + PostgreSQL

## 2. 架构模式

采用 MVVM：
- Model：SwiftData 实体及数据关系
- View：SwiftUI 页面与组件
- ViewModel：业务计算、状态管理、聚合逻辑

## 3. 分层职责

- Models：定义 `Item`、`UsageRecord` 等数据结构与状态
- ViewModels：承载冷却计时、成本计算、看板统计
- Views/Components：可复用组件（卡片、进度条）
- Views/Screens：业务页面（小黑屋、榨干机、添加页）
- Services：通知、后续同步等横向能力
- Utils：常量、日期工具、格式化工具

## 4. 核心数据模型（V1.0 建议）

### 4.1 Item（物品）
建议字段：
- `id: UUID`
- `name: String`
- `price: Decimal`
- `status: ItemStatus`（wish / bought / archived）
- `createdAt: Date`
- `cooldownDays: Int?`
- `cooldownEndDate: Date?`
- `decision: CooldownDecision?`（saved / purchased）
- `targetCostPerUse: Decimal?`
- `lastUsedAt: Date?`

### 4.2 UsageRecord（使用打卡）
建议字段：
- `id: UUID`
- `itemId: UUID`
- `usedAt: Date`
- `note: String?`

## 5. 关键业务规则

- 当前单次成本 = `buyPrice / usageCount`
- 当 `usageCount = 0` 时，单次成本显示为“未使用”而非数值
- 吃灰天数 = 今天 - 最近一次使用日期（无记录则按购买日计算）
- 冷静期到期前不可执行“最终决策”

## 6. 通知与文案

- 本地通知由 `NotificationManager` 统一调度
- 规则示例：
  - 连续 7 天未使用：轻提醒
  - 连续 30 天未使用：强提醒 + 毒舌文案
- 文案池放入 `Constants.swift`，支持后续 A/B 扩展

## 7. 可测试性建议

- 成本计算、排序、冷静期到期判断放在 ViewModel 并写单元测试
- 时间相关逻辑统一通过可注入的 `DateProvider`，避免测试不稳定
- 先保证核心计算可测，再扩展 UI 快照测试
