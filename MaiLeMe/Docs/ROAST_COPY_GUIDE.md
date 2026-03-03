# 毒舌文案管理指南

最后更新：2026-03-03

## 目标

- 统一文案入口，避免页面硬编码导致后期难维护。
- 支持“按场景扩充模板”，不改业务逻辑即可迭代文案风格。
- 保证同一条目在详情页内文案稳定，不出现每次重绘就变文案的问题。

## 文案中心位置

- 主文件：`Utils/Constants.swift`
- 命名空间：`AppConstants.RoastCopy`

## 目前已收口的场景

1. 通知文案  
   对应方法：`light`、`strong`、`cooldownReady`、`cooldownFollowup`、`idleRescueFollowup`
2. 冷静期决策仪式文案  
   对应方法：`decisionSavedBundle`、`decisionPurchasedBundle`、`decisionCelebrationRoastLine`、`decisionShareText`
3. 榨干机打卡仪式文案  
   对应方法：`checkinFirstUseImmediateBundle`、`checkinFirstUseLateBundle`、`checkinRevivalHeavyBundle`、`checkinCelebrationRoastLine`、`checkinShareText`
4. 吃灰挽救文案（详情 + 闲鱼转卖）  
   对应方法：`idleRescuePrimary`、`idleRescueSecondary`、`resaleCondition`、`resaleReason`、`resaleNegotiationReply`
5. 省钱复盘文案  
   对应方法：`savedReviewHeadline`、`savedReviewBody`

## 稳定性策略

- 通知与仪式页：使用随机模板，增强“新鲜感”。
- 详情复盘类页面：使用稳定选择（`pickStable`），同一条目在同一场景下文案不跳变。

## 扩充文案建议

1. 只改 `AppConstants.RoastCopy` 模板池，不直接在页面写新文案。
2. 新增模板时保持“短句 + 强语气 + 可分享”风格。
3. 变量占位统一用 `%@`，并通过 `format(...)` 注入参数。
4. 每个场景建议至少保留 3-5 条模板，避免重复感。
