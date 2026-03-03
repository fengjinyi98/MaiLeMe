//
//  PurchaseDecisionSheet.swift
//  MaiLeMe
//
//  Created by Codex on 2026/2/28.
//

import SwiftUI

/// “还是买了”补充信息弹层：记录真实买入价与目标单次成本。
struct PurchaseDecisionSheet: View {
    @Environment(\.dismiss) private var dismiss

    let itemName: String
    let defaultPriceCents: Int
    let onConfirm: (_ purchasePriceCents: Int, _ targetCostPerUseCents: Int?, _ expectedUseCount: Int?) -> Void

    @State private var purchasePriceYuanText: String
    @State private var expectedUseCountText: String = ""
    @State private var targetCostYuanText: String = ""

    init(
        itemName: String,
        defaultPriceCents: Int,
        onConfirm: @escaping (_ purchasePriceCents: Int, _ targetCostPerUseCents: Int?, _ expectedUseCount: Int?) -> Void
    ) {
        self.itemName = itemName
        self.defaultPriceCents = defaultPriceCents
        self.onConfirm = onConfirm
        let price = String(format: "%.2f", Double(defaultPriceCents) / 100.0)
        _purchasePriceYuanText = State(initialValue: price)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackgroundView()

                ScrollView {
                    VStack(spacing: 14) {
                        GlassCardView(accent: AppTheme.Palette.accent) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("确认购买")
                                    .font(.title3.bold())
                                    .foregroundStyle(AppTheme.Palette.primaryText)
                                Text(itemName)
                                    .font(.headline)
                                    .foregroundStyle(AppTheme.Palette.secondaryText)
                            }
                        }

                        GlassCardView(accent: AppTheme.Palette.warning) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("购买参数")
                                    .font(.headline)
                                    .foregroundStyle(AppTheme.Palette.primaryText)

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("实际买入价（元）")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.Palette.tertiaryText)
                                    TextField("例如：699", text: $purchasePriceYuanText)
                                        .keyboardType(.decimalPad)
                                        .textFieldStyle(.roundedBorder)
                                }

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("预期使用次数（可选）")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.Palette.tertiaryText)
                                    TextField("例如：120", text: $expectedUseCountText)
                                        .keyboardType(.numberPad)
                                        .textFieldStyle(.roundedBorder)
                                }

                                if let autoTargetCostCents {
                                    Text("系统预估单次成本：¥\(centsToYuan(autoTargetCostCents))（可手动覆盖）")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.Palette.secondaryText)
                                }

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("目标单次成本（元，可选，手动覆盖）")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.Palette.tertiaryText)
                                    TextField("例如：9.9", text: $targetCostYuanText)
                                        .keyboardType(.decimalPad)
                                        .textFieldStyle(.roundedBorder)
                                }

                                if !isExpectedUseCountInputValid || !isManualTargetInputValid {
                                    Text("输入格式有误，请检查数字格式。")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.Palette.warning)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("补充购买信息")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("确认") {
                        guard let purchasePrice = parsedPurchasePriceCents else {
                            return
                        }
                        let targetCost = parsedManualTargetCostCents
                        let expectedUseCount = parsedExpectedUseCount
                        onConfirm(purchasePrice, targetCost, expectedUseCount)
                        dismiss()
                    }
                    .disabled(!canConfirm)
                }
            }
        }
    }

    /// 提交按钮可用条件：必填价格有效，且可选字段格式合法。
    private var canConfirm: Bool {
        parsedPurchasePriceCents != nil && isExpectedUseCountInputValid && isManualTargetInputValid
    }

    /// 解析后的实际买入价（分）。
    private var parsedPurchasePriceCents: Int? {
        parsedCents(from: purchasePriceYuanText)
    }

    /// 解析后的预期使用次数（次）。
    private var parsedExpectedUseCount: Int? {
        parsedPositiveInt(from: expectedUseCountText)
    }

    /// 解析后的手动目标单次成本（分）。
    private var parsedManualTargetCostCents: Int? {
        parsedCents(from: targetCostYuanText)
    }

    /// 基于“买入价 / 预期使用次数”自动估算目标单次成本。
    private var autoTargetCostCents: Int? {
        guard let purchasePriceCents = parsedPurchasePriceCents,
              let expectedUseCount = parsedExpectedUseCount else {
            return nil
        }
        return max(1, purchasePriceCents / expectedUseCount)
    }

    /// 可选整数输入是否合法：空值合法，非空时需为正整数。
    private var isExpectedUseCountInputValid: Bool {
        isOptionalPositiveIntInputValid(expectedUseCountText)
    }

    /// 可选金额输入是否合法：空值合法，非空时需为非负数字。
    private var isManualTargetInputValid: Bool {
        isOptionalCurrencyInputValid(targetCostYuanText)
    }

    /// 将“元”文本解析为“分”。
    /// 规则：空字符串返回 `nil`（表示未填写）；非法字符串返回 `nil`。
    private func parsedCents(from text: String) -> Int? {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            return nil
        }
        guard let amount = Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX")) else {
            return nil
        }
        guard amount >= 0 else {
            return nil
        }
        let cents = NSDecimalNumber(decimal: amount)
            .multiplying(by: NSDecimalNumber(value: 100))
            .intValue
        return max(0, cents)
    }

    /// 将文本解析为正整数；空字符串返回 `nil`（可选字段未填写）。
    private func parsedPositiveInt(from text: String) -> Int? {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            return nil
        }
        guard let value = Int(normalized), value > 0 else {
            return nil
        }
        return value
    }

    /// 校验可选金额输入是否有效。
    private func isOptionalCurrencyInputValid(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || parsedCents(from: text) != nil
    }

    /// 校验可选正整数输入是否有效。
    private func isOptionalPositiveIntInputValid(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || parsedPositiveInt(from: text) != nil
    }

    /// 将“分”转换为“元”。
    private func centsToYuan(_ cents: Int) -> String {
        String(format: "%.2f", Double(cents) / 100.0)
    }
}
