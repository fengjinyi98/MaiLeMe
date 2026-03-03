//
//  Date+Extension.swift
//  MaiLeMe
//
//  Created by Codex on 2026/2/28.
//

import Foundation

extension Date {
    /// 中文日期（示例：2026年2月28日）。
    func zhDateString() -> String {
        DateFormatters.zhDateFormatter.string(from: self)
    }

    /// 中文日期时间（示例：2026年2月28日 20:30）。
    func zhDateTimeString() -> String {
        DateFormatters.zhDateTimeFormatter.string(from: self)
    }
}

/// 日期格式化器集中管理，避免重复创建带来的性能开销。
private enum DateFormatters {
    static let zhDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy年M月d日"
        return formatter
    }()

    static let zhDateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy年M月d日 HH:mm"
        return formatter
    }()
}
