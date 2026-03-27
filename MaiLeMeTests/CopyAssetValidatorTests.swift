import XCTest
@testable import MaiLeMe

/// 验证结构化文案资源能被本地加载器正确解码，避免后续 resolver 接入前资源格式已悄悄失效。
final class CopyAssetValidatorTests: XCTestCase {
    /// 通知模块资源应能从 App bundle 成功载入，并至少产出一条 notification 模块文案。
    func test_copy_library_loader_decodes_notification_assets() throws {
        let loader = CopyLibraryLoader(bundle: .main)
        let library = try loader.load()

        XCTAssertFalse(library.entries.isEmpty)
        XCTAssertTrue(library.entries.contains { $0.module == .notification })
    }
}
