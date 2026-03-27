# 本地毒舌文案系统架构说明

最后更新：2026-03-28

## 1. 目标

本系统用于在**无后端、离线优先**前提下，为买了么的通知、决策、打卡、吃灰挽救、省钱复盘、空状态与分享链路提供可扩展、可测试、可回退的结构化文案能力。

## 2. 非目标

- 不做 LLM 在线生成
- 不做文案质量主观评分
- 不做运行时拦截式强校验
- 不要求每个品类都有专属文案

## 3. 数据流

```text
Resources/RoastCopy/modules/*.json
        ↓
CopyLibraryLoader
        ↓
CopyLibrary(entries)
        ↓
CopyResolver + CopyScenarioInterpreter + CopyMemoryStore
        ↓
AppConstants.RoastCopy（兼容层）
        ↓
UI / 本地通知 / 分享文本
```

## 4. 核心组件

### 4.1 `RoastCopyEntry`
路径：`MaiLeMe/Models/RoastCopyEntry.swift`

单条结构化文案记录，核心字段：
- `module`：业务模块（notification / decision / checkin / idleRescue / savedReview / emptyState / share）
- `slot`：投放位置（title / subtitle / badge / roast / actionTitle / body / primary / secondary）
- `scene`：命中场景，可一条覆盖多个场景
- `template`：模板正文，使用 `{{variable}}` 占位
- `variables`：模板声明的变量清单
- `categoryInclude/categoryExclude`：一级品类过滤
- `behaviorInclude/behaviorExclude`：行为标签过滤
- `intensity/stability/weight`：强度、稳定性、权重

### 4.2 `CopyLibraryLoader`
路径：`MaiLeMe/Services/CopyLibraryLoader.swift`

职责：
- 按 `CopyModule.resourceFileName` 定位模块 JSON
- 解码为 `[RoastCopyEntry]`
- 聚合成 `CopyLibrary`

### 4.3 `CopyResolver`
路径：`MaiLeMe/Services/CopyResolver.swift`

职责：
- 按 `module + scene + slot` 做硬过滤
- 结合 `primaryCategory + behaviorTags + intensityCap + allowRandom` 做候选评分
- 按稳定性/历史命中结果避免重复
- 渲染模板变量并返回最终文案

### 4.4 `CopyScenarioInterpreter`
职责：
- 将打卡、吃灰等业务状态映射成标准 scene 名称
- 让业务层只提供语义，不关心资源命名细节

### 4.5 `CopyMemoryStore`
职责：
- 记录近期命中的 `copyID/module/scene/slot/itemID`
- 支撑 rotating / stable 场景的去重与稳定输出

### 4.6 `AppConstants.RoastCopy`
路径：`MaiLeMe/Utils/Constants.swift`

职责：
- 作为旧调用面的兼容层
- 对外继续暴露 `light(...)`、`decisionSavedBundle(...)` 等稳定 API
- 内部把上下文转成 `CopyContext` 调 resolver
- 若资源异常，则回退到旧模板池 fallback

## 5. 当前覆盖范围

已进入结构化文案系统的模块：
- 通知
- 冷静期决策仪式
- 榨干机打卡仪式
- 吃灰挽救
- 省钱复盘
- 空状态
- 分享文本片段

## 6. 回退策略

当以下情况发生时，系统会回退到兼容层 fallback：
- 资源文件缺失
- JSON 解码失败
- 当前 scene/slot 无命中候选
- 单条模板渲染失败

原则：
- **不阻断主流程**
- **不让 UI/通知链路因为文案资源问题崩溃**
- 通过测试和 validator 尽量提前发现问题，而不是把风险留给运行时

## 7. `CopyAssetValidator` 的职责边界

负责：
- 模块文件存在、可解码、非空
- entry 基础结构合法
- 模板变量声明与真实占位一致
- 关键 scene/slot 覆盖矩阵完整
- 模块归属、ID 唯一性、过滤条件冲突检测

不负责：
- 文案是否足够“毒舌”
- 文案长度/修辞/风格优劣
- secondaryCategory 的业务策略设计
- 运行时热更新或在线编辑

## 8. 设计边界

当前系统仍是**本地离线优先**：
- taxonomy 在本地判断
- resolver 在本地执行
- 资源随 App 包发布
- 后续若引入后端或 LLM，应以当前 `CopyContext -> CopyResolver` 接口为边界演进，而不是绕开现有兼容层。
