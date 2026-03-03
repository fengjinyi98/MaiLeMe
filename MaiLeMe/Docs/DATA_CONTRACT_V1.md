# 买了么（MaiLeMe）数据契约 V1

最后更新：2026-02-28

## 1. 设计目标

- 用最少实体支撑 V1.0 全流程：冷静期、购买流转、使用打卡、看板统计。
- 统一金额与时间口径，避免后续统计结果漂移。
- 保持可迁移性，为 V1.5 CloudKit 同步预留字段语义。

## 2. 实体定义

### 2.1 Item（物品主表）

字段清单：

- `id: UUID`：业务主键，唯一。
- `name: String`：物品名称，必填。
- `createdAt: Date`：创建时间（录入时间）。
- `status: ItemStatus`：当前状态，见状态枚举。
- `wishPriceCents: Int`：想买阶段价格，单位“分”。
- `cooldownDays: Int?`：冷静期天数，仅小黑屋场景使用。
- `cooldownEndAt: Date?`：冷静期结束时间。
- `decision: CooldownDecision?`：冷静期终局决策（忍住/破戒）。
- `decisionAt: Date?`：完成终局决策时间。
- `purchaseAt: Date?`：实际购买时间。
- `purchasePriceCents: Int?`：实际买入价，单位“分”。
- `purchasedDuringCooldown: Bool`：是否在冷静期未结束时提前购买。
- `expectedUseCount: Int?`：预期使用次数（可选，正整数）。
- `targetCostPerUseCents: Int?`：目标单次成本，单位“分”。
- `usageCount: Int`：累计打卡次数。
- `lastUsedAt: Date?`：最近一次使用时间。
- `savedAmountCents: Int`：本条目累计贡献的“省下金额”，单位“分”。
- `usageRecords: [UsageRecord]`：使用记录关系，级联删除。

### 2.2 UsageRecord（使用打卡表）

字段清单：

- `id: UUID`：业务主键，唯一。
- `usedAt: Date`：打卡时间。
- `durationMinutes: Int?`：本次使用时长（分钟，可选）。
- `note: String?`：备注（可选）。
- `item: Item?`：所属物品（反向关系）。

## 3. 枚举定义

- `ItemStatus`
  - `wish`：待购（冷静期中/待决策）
  - `purchased`：已购买（进入榨干机）
  - `saved`：忍住没买（已转化为省钱）
  - `archived`：归档（历史记录）

- `CooldownDecision`
  - `saved`：忍住没买
  - `purchased`：破戒购买

## 4. 统一口径

### 4.1 金额口径

- 所有金额字段统一用“分”（`Int`）存储。
- UI 展示层再转换成元，避免浮点精度问题。

### 4.2 时间口径

- 所有时间使用系统当前时区写入 `Date`。
- 吃灰天数计算口径：
  - 有 `lastUsedAt`：`today - lastUsedAt`
  - 无 `lastUsedAt` 且已购买：`today - purchaseAt`
  - 无 `purchaseAt`：视为未进入吃灰统计

## 5. 关键业务规则

1. 正常购买决策要求冷静期结束；若用户在冷静期内提前购买，需走“冲动购买”路径并写入 `purchasedDuringCooldown = true`。  
2. 当决策为 `saved` 时：
   - `status = .saved`
   - `savedAmountCents = wishPriceCents`
3. 当决策为 `purchased` 时：
   - `status = .purchased`
   - 必须写入 `purchaseAt` 与 `purchasePriceCents`
   - `targetCostPerUseCents` 优先取手动输入，否则按 `purchasePriceCents / expectedUseCount` 自动估算
4. `usageCount` 初始值为 0，打卡后递增。  
5. 当前单次成本（展示层计算）：
   - `usageCount == 0` 显示“未使用”
   - 否则 `purchasePriceCents / usageCount`

## 6. 看板指标映射

- 靠意念省下的总金额：`sum(Item.savedAmountCents where status == .saved)`
- 吃灰 Top 3：`status == .purchased` 按“吃灰天数”降序取前 3
- 回本进度：以 `purchasePriceCents / usageCount` 与 `targetCostPerUseCents` 比较

## 7. V1 数据边界

- V1 不引入远端 ID、账号 ID、多人共享字段。
- V1 不做软删除，归档通过 `status = .archived` 处理。
- V1 不单独做统计快照表，统计均由 `Item + UsageRecord` 实时聚合。
