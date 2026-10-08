import Foundation
import XCTest
@testable import FinderHelperCore

final class FileCreatorTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: directory)
    }

    func testCreatesUTF8ContentAndAddsExtensionOnce() throws {
        let template = FileTemplate(name: "笔记", fileExtension: ".md", content: "你好，世界\n{{filename}}")
        let result = try FileCreator.create(template: template, named: "项目.MD", in: directory)
        XCTAssertEqual(result.lastPathComponent, "项目.md")
        XCTAssertEqual(try String(contentsOf: result, encoding: .utf8), "你好，世界\n项目.md")
    }

    func testCollisionsNeverOverwriteExistingFileOrDirectory() throws {
        let template = FileTemplate(name: "文本", fileExtension: "txt", content: "new {{filename}}")
        let original = directory.appendingPathComponent("笔记.txt")
        try Data("keep me".utf8).write(to: original)
        try FileManager.default.createDirectory(at: directory.appendingPathComponent("笔记 2.txt"), withIntermediateDirectories: false)
        let result = try FileCreator.create(template: template, named: "笔记", in: directory)
        XCTAssertEqual(result.lastPathComponent, "笔记 3.txt")
        XCTAssertEqual(try String(contentsOf: original, encoding: .utf8), "keep me")
        XCTAssertEqual(try String(contentsOf: result, encoding: .utf8), "new 笔记 3.txt")
    }

    func testDoesNotFollowExistingSymlink() throws {
        let destination = directory.appendingPathComponent("original.txt")
        try Data("original".utf8).write(to: destination)
        try FileManager.default.createSymbolicLink(at: directory.appendingPathComponent("note.txt"), withDestinationURL: destination)
        let result = try FileCreator.create(template: FileTemplate(name: "文本", fileExtension: "txt", content: "new"), named: "note", in: directory)
        XCTAssertEqual(result.lastPathComponent, "note 2.txt")
        XCTAssertEqual(try String(contentsOf: destination, encoding: .utf8), "original")
    }

    func testRejectsUnsafeAndOversizeNames() throws {
        let template = FileTemplate(name: "文本", fileExtension: "txt")
        for name in ["", "   ", ".", "..", "../escape", "nested/name", "nested\\name", "a:b", "bad\u{0}name", "bad\nname"] {
            XCTAssertThrowsError(try FileCreator.create(template: template, named: name, in: directory), name)
        }
        XCTAssertThrowsError(try FileCreator.create(template: template, named: String(repeating: "中", count: 90), in: directory)) {
            XCTAssertEqual($0 as? FileCreationError, .nameTooLong)
        }
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path), [])
    }

    func testRejectsUnsafeExtensionsAndNonDirectoryTargets() throws {
        for ext in ["../txt", "a/b", "a\\b", "..txt", "txt.", ".", "a:b", "txt\n"] {
            XCTAssertThrowsError(try FileCreator.create(template: FileTemplate(name: "文本", fileExtension: ext), named: "test", in: directory), ext)
        }
        let file = directory.appendingPathComponent("file")
        try Data().write(to: file)
        let template = FileTemplate(name: "文本", fileExtension: "txt")
        XCTAssertThrowsError(try FileCreator.create(template: template, named: "test", in: file)) {
            XCTAssertEqual($0 as? FileCreationError, .invalidDirectory)
        }
        XCTAssertThrowsError(try FileCreator.create(template: template, named: "test", in: URL(string: "https://example.com/folder")!))
    }

    func testSupportsExtensionlessAndCompoundExtensions() throws {
        let plain = try FileCreator.create(template: FileTemplate(name: "配置", fileExtension: ""), named: ".gitignore", in: directory)
        XCTAssertEqual(plain.lastPathComponent, ".gitignore")
        let compound = try FileCreator.create(template: FileTemplate(name: "声明", fileExtension: "d.ts"), named: "types.d.ts", in: directory)
        XCTAssertEqual(compound.lastPathComponent, "types.d.ts")
    }

    func testDatePlaceholdersAndSinglePassSubstitution() throws {
        let template = FileTemplate(name: "文本", fileExtension: "txt", content: "{{filename}}|{{date}}|{{datetime}}|{{unknown}}")
        let result = try FileCreator.create(template: template, named: "{{date}}", in: directory)
        let parts = try String(contentsOf: result, encoding: .utf8).components(separatedBy: "|")
        XCTAssertEqual(parts[0], "{{date}}.txt")
        XCTAssertNotNil(parts[1].range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression))
        XCTAssertNotNil(ISO8601DateFormatter().date(from: parts[2]))
        XCTAssertEqual(parts[3], "{{unknown}}")
    }
}

final class ActionRequestTests: XCTestCase {
    func testEveryActionRoundTripsWithSpecialCharacters() throws {
        let directory = URL(fileURLWithPath: "/Users/测试/文件 & #? 100% + 空格", isDirectory: true)
        let files = [directory.appendingPathComponent("hello & #?%.md"), directory.appendingPathComponent("second.txt")]
        let requests: [ActionRequest] = [
            .create(templateID: "custom + &? 中文", directory: directory),
            .open(applicationID: "editor & 2", files: files),
            .copyPaths(files: files),
            .openTerminal(directory: directory),
            .showSettings
        ]
        for request in requests {
            XCTAssertEqual(try ActionRequest(url: request.makeURL()), request)
        }
    }

    func testRejectsMalformedEnvelopesAndParameters() {
        let invalid = [
            "https://settings", "finderhelper://unknown", "finderhelper://settings/path",
            "finderhelper://settings?", "finderhelper://settings?x=1", "finderhelper://settings#fragment",
            "finderhelper://user@settings", "finderhelper://settings:42",
            "finderhelper://create?template=t", "finderhelper://create?template=&directory=file:///tmp",
            "finderhelper://create?template=t&template=x&directory=file:///tmp",
            "finderhelper://create?template=t&directory=file:///tmp&extra=1",
            "finderhelper://terminal?directory=file:///tmp&directory=file:///other",
            "finderhelper://open?application=app", "finderhelper://copy-paths",
            "finderhelper://copy-paths?file", "finderhelper://open?application=app&application=other&file=file:///tmp/a"
        ]
        for raw in invalid {
            XCTAssertThrowsError(try ActionRequest(url: URL(string: raw)!), raw)
        }
    }

    func testRejectsRemoteRelativeAndTraversingFileURLs() throws {
        let invalid = ["https://example.com/a", "/tmp/a", "file://server/tmp/a", "file:relative", "file:///tmp/../etc", "file:///tmp/%2E%2E/etc", "file:///tmp/a?query=yes", "file:///tmp/a#fragment", "file:///tmp/%00a"]
        for file in invalid {
            var components = URLComponents()
            components.scheme = "finderhelper"
            components.host = "copy-paths"
            components.queryItems = [URLQueryItem(name: "file", value: file)]
            XCTAssertThrowsError(try ActionRequest(url: components.url!), file)
        }
    }

    func testEncodingRejectsEmptyFileSelectionAndInvalidIdentifiers() {
        XCTAssertThrowsError(try ActionRequest.open(applicationID: "app", files: []).makeURL())
        XCTAssertThrowsError(try ActionRequest.copyPaths(files: []).makeURL())
        XCTAssertThrowsError(try ActionRequest.create(templateID: "\n", directory: URL(fileURLWithPath: "/tmp")).makeURL())
        XCTAssertThrowsError(try ActionRequest.openTerminal(directory: URL(string: "https://example.com")!).makeURL())
    }
}

final class ConfigurationStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUpWithError() throws {
        suiteName = "FinderHelperCoreTests." + UUID().uuidString
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testSettingsPersistAcrossStoreInstances() throws {
        var settings = AppSettings.default
        settings.menuEnabled = false
        settings.templates.append(FileTemplate(name: "自定义", fileExtension: "csv", content: "name,value\n"))
        settings.applications = [CustomApplication(name: "编辑器", path: "/Applications/Editor.app")]
        settings.monitoredFolders = ["/tmp"]
        try ConfigurationStore(defaults: defaults).save(settings)
        XCTAssertEqual(ConfigurationStore(defaults: defaults).load(), settings)
    }

    func testMissingAndCorruptSettingsFallBackToDefaults() {
        let store = ConfigurationStore(defaults: defaults)
        XCTAssertEqual(store.load(), .default)
        XCTAssertEqual(store.load().monitoredFolders, [])
        defaults.set(Data("broken json".utf8), forKey: ConfigurationStore.defaultsKey)
        XCTAssertEqual(store.load(), .default)
    }

    func testOlderSettingsKeepUserChoicesAndSupplyNewDefaults() throws {
        let data = Data(#"{"menuEnabled":false,"templates":[],"applications":[]}"#.utf8)
        defaults.set(data, forKey: ConfigurationStore.defaultsKey)
        let settings = ConfigurationStore(defaults: defaults).load()
        XCTAssertFalse(settings.menuEnabled)
        XCTAssertEqual(settings.templates, [])
        XCTAssertTrue(settings.showCopyPath)
        XCTAssertTrue(settings.showOpenInTerminal)
        XCTAssertNil(settings.terminalApplication)
        XCTAssertTrue(settings.revealAfterCreation)
    }
}
