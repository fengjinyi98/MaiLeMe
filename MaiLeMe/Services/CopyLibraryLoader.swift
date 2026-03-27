import Foundation

/// 本地文案库：承载已经从 JSON 资源解码出的全部结构化文案条目。
struct CopyLibrary: Equatable, Sendable {
    /// 文案资产明细列表。
    let entries: [RoastCopyEntry]
}

/// 文案资源加载失败时的明确错误类型，便于单测与调用方快速定位是缺文件还是解码异常。
enum CopyLibraryLoaderError: LocalizedError, Equatable {
    /// 指定资源文件在 bundle 中不存在。
    case missingResource(name: String, bundlePath: String)
    /// 指定资源文件解码失败，并携带底层错误描述，便于快速定位具体模块。
    case decodingFailed(name: String, underlyingDescription: String)

    var errorDescription: String? {
        switch self {
        case let .missingResource(name, bundlePath):
            return "未在 bundle 中找到文案资源文件：\(name).json（bundle: \(bundlePath)）。"
        case let .decodingFailed(name, underlyingDescription):
            return "文案资源文件解码失败：\(name).json（原因：\(underlyingDescription)）。"
        }
    }
}

/// 文案库加载器：负责从 App bundle 中逐个读取模块 JSON，并合并为统一的内存文案库。
final class CopyLibraryLoader {
    /// 文案资源所在 bundle；测试阶段可注入 host app bundle。
    private let bundle: Bundle
    /// 资源子目录常量，集中维护避免路径散落。
    private let modulesSubdirectory = "RoastCopy/modules"

    /// 创建文案加载器。
    /// - Parameter bundle: 资源所在 bundle，默认使用主 bundle。
    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    /// 加载全部模块文案资源，并聚合成统一文案库。
    /// - Returns: 已解码的结构化文案库。
    /// - Throws: 当任一模块文件缺失或 JSON 解码失败时抛出错误。
    func load() throws -> CopyLibrary {
        let entries = try CopyModule.allCases.flatMap { module in
            try decodeFile(named: module.resourceFileName)
        }
        return CopyLibrary(entries: entries)
    }

    /// 解码单个模块文件。
    /// - Parameter named: 不带扩展名的模块文件名。
    /// - Returns: 对应文件内的文案条目数组。
    /// - Throws: 当文件不存在或 JSON 结构不合法时抛出错误。
    private func decodeFile(named name: String) throws -> [RoastCopyEntry] {
        // 先按预期子目录查找；若 Xcode 构建阶段把资源平铺复制到 bundle 根目录，则回退到根目录继续查找。
        let url = bundle.url(
            forResource: name,
            withExtension: "json",
            subdirectory: modulesSubdirectory
        ) ?? bundle.url(
            forResource: name,
            withExtension: "json"
        )

        guard let url else {
            throw CopyLibraryLoaderError.missingResource(
                name: name,
                bundlePath: bundle.bundlePath
            )
        }

        let data = try Data(contentsOf: url)
        do {
            return try JSONDecoder().decode([RoastCopyEntry].self, from: data)
        } catch {
            throw CopyLibraryLoaderError.decodingFailed(
                name: name,
                underlyingDescription: error.localizedDescription
            )
        }
    }
}
