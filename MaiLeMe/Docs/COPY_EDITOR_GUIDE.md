# 文案资源编辑指南

最后更新：2026-03-28

## 1. 资源位置

结构化文案存放在：
- `MaiLeMe/Resources/RoastCopy/modules/*.json`

每个文件对应一个 `CopyModule`：
- `notifications.json`
- `decision.json`
- `checkin.json`
- `idle_rescue.json`
- `saved_review.json`
- `empty_state.json`
- `share.json`

## 2. 新增一条文案的步骤

1. 先判断属于哪个 `module`
2. 再判断落在哪个 `slot`
3. 选择或新增正确的 `scene`
4. 写 `template`
5. 用 `{{variable}}` 标注变量
6. 在 `variables` 里声明同名变量
7. 视需要填写 `categoryInclude/exclude`、`behaviorInclude/exclude`
8. 给出合理 `intensity/stability/weight`
9. 跑测试验证

## 3. ID 命名规范

推荐格式：

```text
<module>_<scene>_<slot>_<序号>
```

示例：
- `checkin_first_use_immediate_title_001`
- `notification_light_reminder_body_001`
- `share_checkin_share_closing_body_001`

原则：
- 全库唯一
- 一眼能看出模块、场景、槽位
- 不要把随机业务词塞进 id

## 4. Scene 命名规范

统一使用：
- 小写
- snake_case

示例：
- `decision_saved`
- `first_use_immediate`
- `body_mid_cooldown`
- `checkin_share_closing`

不要使用：
- 驼峰
- 中文
- 带空格
- 临时缩写

## 5. Template 与变量规则

### 5.1 正确写法

```json
{
  "template": "{{itemName}} 已经 {{idleDays}} 天没用了。",
  "variables": ["itemName", "idleDays"]
}
```

### 5.2 错误写法

- 继续写旧 `%@`
- 模板用了变量，但 `variables` 没声明
- `variables` 声明了，但模板里没用
- 变量名大小写不一致

## 6. 过滤字段怎么用

### `categoryInclude / categoryExclude`
用于一级分类过滤。

适合：
- 办公设备
- 数码产品
- 美妆/家电等大类差异明显的文案

### `behaviorInclude / behaviorExclude`
用于消费动机过滤。

适合：
- 效率幻觉
- 自我提升
- 升级替换

原则：
- 不要把同一个值同时放进 include 和 exclude
- 没必要时就留空，空代表更泛化的兜底文案

## 7. 必需覆盖矩阵（速查）

以下 scene/slot 组合至少要有 1 条 entry：

- `notification.body`
  - `light_reminder`
  - `strong_reminder`
  - `cooldown_ready`
  - `cooldown_followup`
  - `rescue_followup`
- `decision.title/subtitle/actionTitle/roast`
  - `decision_saved`
  - `decision_purchased`
- `checkin.title/subtitle/badge`
  - `first_use_immediate`
  - `first_use_late`
  - `first_use_normal`
  - `revival_heavy`
  - `revival_mid`
  - `steady_high_usage`
  - `checkin_default`
- `checkin.roast`
  - `first_use`
  - `big_moment`
  - `high_usage`
  - `default`
- `idleRescue.primary`
  - `primary_light / warm / mid / heavy / severe / extreme`
- `idleRescue.secondary`
  - `secondary_never_used / heavy / default`
- `savedReview.title`
  - `headline_low / mid / high / huge`
- `savedReview.body`
  - `body_short_cooldown / mid_cooldown / long_cooldown`
- `emptyState.body`
  - `dark_room_empty`
  - `extractor_empty`
- `share.body`
  - `decision_saved_outcome`
  - `decision_purchased_outcome`
  - `checkin_share_closing`

## 8. 常见错误

- scene 写对了但 slot 写错
- 只改 fallback，不改 JSON 资源
- 继续把文案写回 `Constants.swift` 主模板池
- 模板变量没声明或多声明
- 把 share 文案放进 notification 模块文件
- 复制一条 entry 却忘记改 `id`

## 9. 本地自检

提交前至少执行：

```bash
xcodebuild test -project /Users/fengjinyi/Desktop/MaiLeMe/MaiLeMe.xcodeproj -scheme MaiLeMeTests -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4'
```

重点关注：
- `CopyAssetValidatorTests`
- `CopyResolverTests`

如果报错：
- `duplicateID`：检查是否复制后忘改 id
- `moduleMismatch`：检查文件归属与 `module` 字段
- `variableMismatch`：检查 `template` 与 `variables`
- `missingRequiredCoverage`：补上缺失的 scene/slot 条目
