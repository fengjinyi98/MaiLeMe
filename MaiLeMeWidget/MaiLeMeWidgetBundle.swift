//
//  MaiLeMeWidgetBundle.swift
//  MaiLeMeWidget
//
//  Created by Codex on 2026/3/4.
//

import WidgetKit
import SwiftUI

/// 小组件入口 Bundle：按阶段组合多个组件，便于逐步演进。
@main
struct MaiLeMeWidgetBundle: WidgetBundle {
    var body: some Widget {
        RationalDefenseWidget()
        TodayActionWidget()
        IdleAlertWidget()
    }
}
