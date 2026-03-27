import XCTest
@testable import MaiLeMe

/// 验证结构化文案资源能被本地加载器正确解码，避免后续 resolver 接入前资源格式已悄悄失效。
final class CopyAssetValidatorTests: XCTestCase {
    /// 全部模块资源都应能从 App bundle 成功载入，且每个模块至少产出一条文案。
    func test_copy_library_loader_decodes_notification_assets() throws {
        let loader = CopyLibraryLoader(bundle: .main)
        let library = try loader.load()

        XCTAssertFalse(library.entries.isEmpty)

        let groupedModules = Dictionary(grouping: library.entries, by: \.module)
        XCTAssertEqual(Set(groupedModules.keys), Set(CopyModule.allCases))

        for module in CopyModule.allCases {
            XCTAssertFalse(
                groupedModules[module, default: []].isEmpty,
                "模块 \(module.rawValue) 至少应包含一条结构化文案。"
            )
        }
    }
}
