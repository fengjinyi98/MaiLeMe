# 分类与行为标签体系说明

最后更新：2026-03-28

## 1. 目标

分类体系用于解决两个问题：
1. 让本地文案更“对题”
2. 给未来的后端/LLM 升级保留稳定上下文边界

## 2. 一级分类 `ItemPrimaryCategory`

一级分类用于表达大的消费语义，目前 resolver 真实参与筛选的是它。

示例方向：
- `digital`
- `office`
- `beauty`
- `appliance`
- `fashion`
- `sports`
- `other`

> 具体枚举以 `MaiLeMe/Models/ItemCategory.swift` 为准。

## 3. 二级分类 `ItemSecondaryCategory`

二级分类用于更细粒度标记商品，例如：
- `desktopComputer`
- `ssd`
- 以及其他具体商品子类

当前职责：
- 在条目模型中长期保存
- 在 UI / 分享 / 通知链路中继续透传
- 作为未来更细文案策略的扩展位

当前限制：
- **resolver 目前不直接使用 secondaryCategory 做筛选**
- 它现在更多承担“保真透传”和未来扩展位职责

## 4. 行为标签 `ItemBehaviorTag`

行为标签表达“这笔消费背后的动机”，例如：
- `efficiencyFantasy`
- `selfImprovement`
- `upgradeReplace`

当前 resolver 会参与筛选的是它。

适用场景：
- 同样是办公设备，但“效率幻觉”与“升级替换”对应的话术应该不同
- 行为标签比纯商品类目更能解释用户为什么会冲动消费

## 5. 分类来源与置信度

条目会记录：
- 分类来源（自动识别 / 用户手动选择 / 未解决）
- 分类置信度（low / medium / high 等）
- 行为标签来源（推断 / 用户调整）

目的：
- 让 UI 能知道当前标签是否可信
- 允许“自动识别失败时手动兜底”
- 为后续策略升级预留可追踪元数据

## 6. taxonomy 如何进入文案系统

链路如下：

```text
Item
  ├─ primaryCategory
  ├─ secondaryCategory
  └─ behaviorTags
        ↓
CopyContext
        ↓
CopyResolver
```

当前实际生效字段：
- `primaryCategory`
- `behaviorTags`

当前仅透传未筛选字段：
- `secondaryCategory`

## 7. 何时该新增 taxonomy

应该新增的情况：
- 现有一级分类无法区分两个真实高频消费语义
- 需要长期复用，不只是为一条文案临时服务
- 能被 Add Item 识别器或用户手动选择稳定产出

不该新增的情况：
- 只是为了某一条文案更顺口
- 仅影响个别营销表达，不影响业务判断
- 无法稳定识别，也不适合让用户手动选择

## 8. 何时只加文案，不加 taxonomy

优先只加文案的情况：
- 只是某个 scene 下缺 1-2 条兜底表达
- 现有 `primaryCategory + behaviorTags` 已够区分
- 问题是“文案数量不够”，不是“语义体系不够”

## 9. 演进建议

短期：
- 继续让 resolver 基于 `primaryCategory + behaviorTags` 工作
- 保持 `secondaryCategory` 仅透传，不急着参与筛选

中期：
- 若用户量起来，再根据真实数据决定是否让 `secondaryCategory` 参与规则
- 若引入后端/LLM，也仍建议把 taxonomy 当成强约束上下文，而不是完全自由文本
