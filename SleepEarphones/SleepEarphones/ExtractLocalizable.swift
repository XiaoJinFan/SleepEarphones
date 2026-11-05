#!/usr/bin/env swift
//
//  ExtractLocalizable.swift
//  SleepEarphones
//
//  从项目中提取所有 L(...) / LN(...) 调用，生成/更新 Localizable.json。
//
//  ## 使用方法
//  ```bash
//  # 1. 在项目根目录执行
//  swift Scripts/ExtractLocalizable.swift
//  ```
//
//  ## 生成的文件
//  - 输出到 `Scripts/Generated/Localizable.json`
//  - 与已有的 `Localizable.json` **合并**（已有翻译保留，新增 key 待翻译）
//
//  ## 参数
//  - `--root <path>`：项目根目录（默认：当前工作目录）
//  - `--output <path>`：输出路径（默认：`Scripts/Generated/Localizable.json`）
//  - `--existing <path>`：已有的 Localizable.json（默认：`Scripts/Existing/Localizable.json`）
//
//  ## 匹配规则
//  - `L("key")` → key
//  - `LN("key")` → key
//  - `L("key %@", arg)` → key = `"key %@"`（保留格式符，不含参数）
//  - 跳过注释行（以 `//` 开头或行内 `//` 之后的 `L(...)`）
//  - 跳过 `Localizable.json` 等生成文件
//

import Foundation

// ============================================================
// MARK: - 配置
// ============================================================

struct Config {
    /// 项目根目录
    let root: URL
    /// 输出路径
    let output: URL
    /// 已有的 Localizable.json（可选）
    let existing: URL?

    static func parse(arguments: [String]) -> Config {
        var root = FileManager.default.currentDirectoryPath
        var output = "Scripts/Generated/Localizable.json"
        var existing: String? = "Scripts/Existing/Localizable.json"

        var i = 1
        while i < arguments.count {
            let arg = arguments[i]
            switch arg {
            case "--root":
                i += 1
                if i < arguments.count { root = arguments[i] }
            case "--output":
                i += 1
                if i < arguments.count { output = arguments[i] }
            case "--existing":
                i += 1
                if i < arguments.count { existing = arguments[i] }
            default:
                break
            }
            i += 1
        }

        let rootURL = URL(fileURLWithPath: root)
        let outputURL = rootURL.appendingPathComponent(output)
        let existingURL = existing.map { rootURL.appendingPathComponent($0) }

        return Config(root: rootURL, output: outputURL, existing: existingURL)
    }
}

// ============================================================
// MARK: - 扫描
// ============================================================

/// 匹配 `L("...")` 或 `LN("...")`
///
/// - 捕获组 1：字符串内容（含转义符）
private let localizedCallRegex = try! NSRegularExpression(
    pattern: #"(?<![A-Za-z0-9_])(?:L|LN)\("((?:[^"\\]|\\.)*)""#,
    options: []
)

/// 收集所有 key（去重 + 排序）
func extractKeys(from fileURL: URL) -> Set<String> {
    guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
        return []
    }

    var keys = Set<String>()
    let nsContent = content as NSString
    let matches = localizedCallRegex.matches(
        in: content,
        options: [],
        range: NSRange(location: 0, length: nsContent.length)
    )

    for match in matches {
        // 检查该匹配是否在注释中
        let matchRange = match.range
        let lineRange = nsContent.lineRange(for: matchRange)
        let line = nsContent.substring(with: lineRange)

        // 跳过整行注释
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("//") { continue }

        // 跳过行内注释后的匹配（简单启发式：检查 `//` 位置）
        if let commentIndex = line.range(of: "//") {
            let commentStart = line.distance(from: line.startIndex, to: commentIndex.lowerBound)
            let matchStartInLine = matchRange.location - lineRange.location
            if matchStartInLine >= commentStart { continue }
        }

        // 提取捕获组 1
        guard match.numberOfRanges >= 2,
              let keyRange = Range(match.range(at: 1), in: content) else {
            continue
        }
        let rawKey = String(content[keyRange])

        // 反转义 Swift 字符串转义
        let key = unescapeSwiftString(rawKey)
        if !key.isEmpty {
            keys.insert(key)
        }
    }
    return keys
}

/// 反转义 Swift 字符串的 `\n` / `\"` / `\\` 等
func unescapeSwiftString(_ raw: String) -> String {
    var result = ""
    result.reserveCapacity(raw.count)
    var iterator = raw.makeIterator()
    while let ch = iterator.next() {
        guard ch == "\\" else {
            result.append(ch)
            continue
        }
        guard let next = iterator.next() else { break }
        switch next {
        case "n": result.append("\n")
        case "t": result.append("\t")
        case "r": result.append("\r")
        case "\"": result.append("\"")
        case "\\": result.append("\\")
        case "0": result.append("\0")
        default:
            // 未知转义（如 `\u{1F600}` 复杂场景）——原样保留
            result.append("\\")
            result.append(next)
        }
    }
    return result
}

/// 递归扫描目录下的所有 `.swift` 文件
func collectSwiftFiles(in root: URL) -> [URL] {
    var files: [URL] = []
    let fm = FileManager.default
    guard let enumerator = fm.enumerator(
        at: root,
        includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
        options: [.skipsHiddenFiles, .skipsPackageDescendants]
    ) else { return [] }

    for case let url as URL in enumerator {
        // 跳过目录
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey])
        if values?.isDirectory == true {
            // 跳过一些无关目录
            let name = url.lastPathComponent
            let skipDirs: Set<String> = [
                "Pods", "Carthage", "DerivedData", "Build",
                ".git", "Scripts/Generated", "Scripts/Existing"
            ]
            if skipDirs.contains(name) { enumerator.skipDescendants() }
            continue
        }

        guard url.pathExtension == "swift" else { continue }
        files.append(url)
    }
    return files
}

// ============================================================
// MARK: - JSON 读写
// ============================================================

/// xcstrings 的顶层结构
struct XCStrings: Codable {
    var sourceLanguage: String
    var strings: [String: StringEntry]
    var version: String

    struct StringEntry: Codable {
        var extractionState: String?
        var localizations: [String: Localization]

        struct Localization: Codable {
            var stringUnit: StringUnit

            struct StringUnit: Codable {
                var state: String
                var value: String
            }
        }
    }
}

/// 加载已有的 Localizable.json（可选）
func loadExisting(at url: URL?) -> XCStrings? {
    guard let url, FileManager.default.fileExists(atPath: url.path) else { return nil }
    do {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(XCStrings.self, from: data)
    } catch {
        print("⚠️ 加载已有 Localizable.json 失败：\(error)")
        return nil
    }
}

/// 计算 key 的 SHA256（用于统一翻译去重）
///
/// - Note: 实际使用时可省略——当前简单起见直接用空翻译
func emptyLocalization(for language: String) -> XCStrings.StringEntry.Localization {
    XCStrings.StringEntry.Localization(
        stringUnit: .init(state: "new", value: "")
    )
}

// ============================================================
// MARK: - 主流程
// ============================================================

let config = Config.parse(arguments: CommandLine.arguments)
print("📂 项目根目录：\(config.root.path)")

// 1. 扫描 Swift 文件
let swiftFiles = collectSwiftFiles(in: config.root)
print("📄 找到 \(swiftFiles.count) 个 .swift 文件")

// 2. 提取所有 key
var allKeys = Set<String>()
for file in swiftFiles {
    let keys = extractKeys(from: file)
    allKeys.formUnion(keys)
}
print("🔑 共提取 \(allKeys.count) 个唯一的 L() / LN() key")

// 3. 加载已有的 Localizable.json（保留已有翻译）
var strings: [String: XCStrings.StringEntry] = [:]
if let existing = loadExisting(at: config.existing) {
    strings = existing.strings
    print("📥 加载已有翻译：\(existing.strings.count) 个 key")
}

// 4. 合并：新增的 key 用空翻译占位
let supportedLanguages = ["zh-Hans", "en", "fr", "ja", "de"]
var newKeyCount = 0

for key in allKeys {
    if strings[key] == nil {
        newKeyCount += 1
        var localizations: [String: XCStrings.StringEntry.Localization] = [:]
        for lang in supportedLanguages {
            // 源语言 zh-Hans 直接用 key 本身
            let value = (lang == "zh-Hans") ? key : ""
            localizations[lang] = XCStrings.StringEntry.Localization(
                stringUnit: .init(
                    state: lang == "zh-Hans" ? "translated" : "new",
                    value: value
                )
            )
        }
        strings[key] = XCStrings.StringEntry(
            extractionState: "stale",
            localizations: localizations
        )
    }
}

print("✨ 新增 \(newKeyCount) 个 key")

// 5. 输出
let result = XCStrings(
    sourceLanguage: "zh-Hans",
    strings: strings,
    version: "1.1"
)

// 6. 确保输出目录存在
try? FileManager.default.createDirectory(
    at: config.output.deletingLastPathComponent(),
    withIntermediateDirectories: true
)

// 7. 编码（prettyPrinted + sortedKeys + withoutEscapingSlashes）
let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
do {
    let data = try encoder.encode(result)
    try data.write(to: config.output, options: .atomic)
    print("✅ 已生成：\(config.output.path)")
    print("   - 总计 \(strings.count) 个 key")
    print("   - 5 种语言：\(supportedLanguages.joined(separator: ", "))")
} catch {
    print("❌ 编码或写入失败：\(error)")
    exit(1)
}
