# 买了么（MaiLeMe）目录结构规范

最后更新：2026-03-28

## 1. 目标目录结构

```text
MaiLeMe/
├── App/
├── Models/
├── ViewModels/
├── Views/
│   ├── Components/
│   └── Screens/
├── Services/
├── Utils/
├── Resources/
└── Docs/
```

## 2. 建议文件落位

- `App/MaiLeMeApp.swift`：应用入口、SwiftData 容器配置
- `Models/Item.swift`：物品实体
- `Models/UsageRecord.swift`：使用记录实体
- `ViewModels/DarkRoomViewModel.swift`：冷静期与省钱逻辑
- `ViewModels/ExtractorViewModel.swift`：打卡与成本折算逻辑
- `Views/Components/GlassCardView.swift`：可复用毛玻璃卡片
- `Views/Components/ProgressBarView.swift`：回本进度条
- `Views/Screens/DarkRoomScreen.swift`：冲动小黑屋页面
- `Views/Screens/ExtractorScreen.swift`：闲置榨干机页面
- `Views/Screens/AddItemScreen.swift`：新增物品页面
- `Services/NotificationManager.swift`：本地通知
- `Utils/Constants.swift`：兼容常量入口与毒舌文案兼容层
- `Services/CopyLibraryLoader.swift`：结构化文案资源加载器
- `Services/CopyResolver.swift`：结构化文案解析器
- `Services/CopyAssetValidator.swift`：结构化文案资源校验器
- `Resources/RoastCopy/modules/*.json`：结构化毒舌文案资源
- `Utils/Date+Extension.swift`：日期计算
- `Resources/Assets.xcassets`：图片与图标资源

## 3. 当前落地说明

- 已创建上述目录（不再使用占位文件，避免被 Xcode 作为资源打包）
- 现有 Xcode 初始化文件仍在项目根目录（未迁移）
- 下一步可在 Xcode 中按此规范移动文件并更新 Group

## 4. 命名与组织约定

- 文件名与主类型同名（如 `DarkRoomViewModel.swift`）
- 每个 Screen 对应一个 ViewModel
- 业务计算不放在 View，统一放到 ViewModel 或 Service
- 常量集中管理，避免魔法字符串散落
