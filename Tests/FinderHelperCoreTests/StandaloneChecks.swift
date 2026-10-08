// Run on Macs with Command Line Tools only (XCTest requires full Xcode):
// swiftc -D FINDER_HELPER_STANDALONE_CHECKS Sources/FinderHelperCore/*.swift \
//   Tests/FinderHelperCoreTests/StandaloneChecks.swift -o /tmp/finderhelper-checks
// /tmp/finderhelper-checks
#if FINDER_HELPER_STANDALONE_CHECKS
import Foundation
import AppKit
import CoreFoundation

@main
enum StandaloneChecks {
    struct Failure: Error, CustomStringConvertible {
        let description: String
    }

    static var checks = 0

    static func expect(_ condition: @autoclosure () throws -> Bool, _ message: String) throws {
        guard try condition() else { throw Failure(description: message) }
        checks += 1
    }

    static func expectFailure(_ message: String, _ operation: () throws -> Void) throws {
        do {
            try operation()
        } catch {
            checks += 1
            return
        }
        throw Failure(description: "Expected failure: \(message)")
    }

    static func main() throws {
        if CommandLine.arguments.count == 4, CommandLine.arguments[1] == "--check-shared-domain" {
            let expected = try JSONDecoder().decode(AppSettings.self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[3])))
            try expect(ConfigurationStore(preferenceDomain: CommandLine.arguments[2], readOnly: true).load() == expected, "separate process reads host preference domain")
            return
        }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("FinderHelperChecks-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try checkFinderMenuForwarding(in: directory)
        let template = FileTemplate(name: "文本", fileExtension: "txt", content: "你好 {{filename}}|{{date}}|{{datetime}}")
        let first = try FileCreator.create(template: template, named: "笔记", in: directory)
        let second = try FileCreator.create(template: template, named: "笔记.txt", in: directory)
        try expect(first.lastPathComponent == "笔记.txt", "automatic extension")
        try expect(second.lastPathComponent == "笔记 2.txt", "collision suffix")
        try expect(try String(contentsOf: first, encoding: .utf8).hasPrefix("你好 笔记.txt|"), "preserved first content")
        let parts = try String(contentsOf: second, encoding: .utf8).components(separatedBy: "|")
        try expect(parts[0] == "你好 笔记 2.txt", "actual collision name in content")
        try expect(parts[1].range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil, "date placeholder")
        try expect(ISO8601DateFormatter().date(from: parts[2]) != nil, "datetime placeholder")

        try FileManager.default.createDirectory(at: directory.appendingPathComponent("笔记 3.txt"), withIntermediateDirectories: false)
        let fourth = try FileCreator.create(template: template, named: "笔记", in: directory)
        try expect(fourth.lastPathComponent == "笔记 4.txt", "directory collision")
        try FileManager.default.createSymbolicLink(at: directory.appendingPathComponent("symlink.txt"), withDestinationURL: first)
        let symlink = try FileCreator.create(template: template, named: "symlink", in: directory)
        try expect(symlink.lastPathComponent == "symlink 2.txt", "symlink is never followed")
        for name in ["", "..", "../escape", "a/b", "a\\b", "a:b", "bad\nname", String(repeating: "中", count: 90)] {
            try expectFailure("unsafe name \(name)") { _ = try FileCreator.create(template: template, named: name, in: directory) }
        }
        for ext in ["../txt", "a/b", "..txt", ".", "txt.", "txt\n"] {
            try expectFailure("unsafe extension \(ext)") { _ = try FileCreator.create(template: FileTemplate(name: "测试", fileExtension: ext), named: "name", in: directory) }
        }

        // Concurrent writers exercise exclusive creation, not just the suffix logic.
        let lock = NSLock()
        var concurrentResults: [URL] = []
        var concurrentErrors: [Error] = []
        DispatchQueue.concurrentPerform(iterations: 24) { _ in
            do {
                let result = try FileCreator.create(template: template, named: "并发", in: directory)
                lock.lock()
                concurrentResults.append(result)
                lock.unlock()
            } catch {
                lock.lock()
                concurrentErrors.append(error)
                lock.unlock()
            }
        }
        try expect(concurrentErrors.isEmpty, "concurrent writes succeed")
        try expect(Set(concurrentResults).count == 24, "concurrent writes have unique paths")
        for result in concurrentResults {
            try expect(try String(contentsOf: result, encoding: .utf8).hasPrefix("你好 \(result.lastPathComponent)|"), "concurrent content matches path")
        }

        let weirdPath = directory.appendingPathComponent("中文 & #?%+ 文件.md")
        let requests: [ActionRequest] = [
            .create(templateID: "text + & 中文", directory: directory),
            .open(applicationID: "editor & 2", files: [first, weirdPath]),
            .copyPaths(files: [weirdPath]), .openTerminal(directory: directory), .showSettings
        ]
        for request in requests { try expect(try ActionRequest(url: request.makeURL()) == request, "action roundtrip") }
        let invalidRequests = [
            "https://settings", "finderhelper://unknown", "finderhelper://settings/path", "finderhelper://settings?",
            "finderhelper://settings#fragment", "finderhelper://user@settings", "finderhelper://settings:42",
            "finderhelper://create?template=t", "finderhelper://create?template=t&template=x&directory=file:///tmp",
            "finderhelper://create?template=t&directory=file:///tmp&extra=1", "finderhelper://copy-paths?file",
            "finderhelper://open?application=editor", "finderhelper://terminal?directory=https://example.com"
        ]
        for raw in invalidRequests { try expectFailure(raw) { _ = try ActionRequest(url: URL(string: raw)!) } }
        for path in ["https://example.com/a", "/tmp/a", "file://server/tmp/a", "file:relative", "file:///tmp/../etc", "file:///tmp/%2E%2E/etc", "file:///tmp/a?q=1", "file:///tmp/a#fragment", "file:///tmp/%00a"] {
            var components = URLComponents()
            components.scheme = "finderhelper"
            components.host = "copy-paths"
            components.queryItems = [URLQueryItem(name: "file", value: path)]
            try expectFailure(path) { _ = try ActionRequest(url: components.url!) }
        }
        try expectFailure("empty files") { _ = try ActionRequest.copyPaths(files: []).makeURL() }
        try expectFailure("invalid id") { _ = try ActionRequest.create(templateID: "\n", directory: directory).makeURL() }

        let suite = "FinderHelperStandaloneChecks." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ConfigurationStore(defaults: defaults)
        try expect(store.load() == .default, "new store defaults")
        try expect(store.load().monitoredFolders.isEmpty, "new store monitors all folders")
        var settings = AppSettings.default
        settings.menuEnabled = false
        settings.applications = [CustomApplication(name: "编辑器", path: "/Applications/Editor.app")]
        settings.monitoredFolders = [directory.path]
        settings.terminalApplication = CustomApplication(name: "Ghostty", path: "/Applications/Ghostty.app")
        try store.save(settings)
        try expect(ConfigurationStore(defaults: defaults).load() == settings, "settings persistence")
        defaults.set(Data("invalid json".utf8), forKey: ConfigurationStore.defaultsKey)
        try expect(store.load() == .default, "corrupt settings fallback")
        defaults.set(Data(#"{"menuEnabled":false,"templates":[]}"#.utf8), forKey: ConfigurationStore.defaultsKey)
        let upgraded = store.load()
        try expect(!upgraded.menuEnabled && upgraded.templates.isEmpty && upgraded.showCopyPath, "missing new settings get defaults")
        try expect(upgraded.terminalApplication == nil && upgraded.terminalName == "系统终端", "old settings keep system terminal")
        try checkSharedPreferences(in: directory)
        try checkTerminalDestinations()
        print("Passed \(checks) core and Finder menu checks.")
    }

    static func checkTerminalDestinations() throws {
        let folder = URL(fileURLWithPath: "/tmp/中文 & #?%+ ' \" $(touch sentinel); 文件夹", isDirectory: true)
        for identifier in ["com.apple.Terminal", "com.mitchellh.ghostty", "com.googlecode.iterm2", "custom.terminal"] {
            try expect(TerminalLaunch.destination(bundleIdentifier: identifier, directory: folder) == folder, "folder URL passed unchanged to \(identifier)")
        }
        for identifier in ["dev.warp.Warp-Stable", "dev.warp.Warp-Preview"] {
            let url = try TerminalLaunch.destination(bundleIdentifier: identifier, directory: folder)
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
            try expect(components.scheme == (identifier.hasSuffix("Preview") ? "warppreview" : "warp"), "Warp variant scheme")
            try expect(components.host == "action" && components.path == "/new_window", "Warp window route")
            try expect(components.queryItems == [URLQueryItem(name: "path", value: folder.path)], "Warp path is one query value, not a command")
        }
        for raw in ["https://example.com", "file://server/tmp", "file:///tmp/../etc", "file:relative", "file:///tmp/a#fragment"] {
            try expectFailure("invalid terminal folder") { _ = try TerminalLaunch.destination(bundleIdentifier: "com.mitchellh.ghostty", directory: URL(string: raw)!) }
        }
        let terminal = CustomApplication(name: "Ghostty", path: "/Applications/Ghostty.app")
        let settings = AppSettings(terminalApplication: terminal)
        try expect(try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(settings)) == settings, "terminal setting roundtrip")
        try expect(settings.terminalMenuTitle == "在 Ghostty 中打开", "selected terminal menu title")
        try expect(AppSettings.default.terminalMenuTitle == "在终端中打开", "default terminal menu unchanged")
    }

    static func checkSharedPreferences(in directory: URL) throws {
        let domain = "FinderHelperSharedChecks." + UUID().uuidString
        defer {
            CFPreferencesSetValue(ConfigurationStore.defaultsKey as CFString, nil, domain as CFString,
                                  kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
            CFPreferencesSynchronize(domain as CFString, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        }
        let writer = ConfigurationStore(preferenceDomain: domain)
        let reader = ConfigurationStore(preferenceDomain: domain, readOnly: true)
        try expect(reader.load() == .default, "empty shared domain defaults")
        var expected = AppSettings.default
        expected.applications = [CustomApplication(name: "测试编辑器", path: "/Applications/Editor.app")]
        try writer.save(expected)
        try expect(reader.load() == expected, "read-only store sees host settings")
        try expectFailure("extension cannot save") { try reader.save(.default) }
        try expect(writer.load() == expected, "rejected write preserves host settings")
        expected.menuEnabled = false
        try writer.save(expected)
        try expect(reader.load() == expected, "reader refreshes changed preferences")
        let fixture = directory.appendingPathComponent("expected-settings.json")
        try JSONEncoder().encode(expected).write(to: fixture)
        let child = Process()
        child.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
        child.arguments = ["--check-shared-domain", domain, fixture.path]
        try child.run()
        child.waitUntilExit()
        try expect(child.terminationStatus == 0, "preferences survive process boundary")
    }

    static func checkFinderMenuForwarding(in directory: URL) throws {
        let now = Date()
        let registry = MenuActionRegistry(capacity: 3, lifetime: 60)
        let create = ActionRequest.create(templateID: "markdown", directory: directory)
        let open = ActionRequest.open(applicationID: "editor", files: [directory.appendingPathComponent("中文.md")])
        let original = NSMenuItem(title: "Markdown", action: nil, keyEquivalent: "")
        original.tag = registry.register(create, now: now)
        original.representedObject = "This object is not forwarded by Finder"

        // Model Finder's process boundary: the callback sender is a new item,
        // with supported fields, and without representedObject or its identity.
        let forwarded = NSMenuItem(title: original.title, action: original.action, keyEquivalent: "")
        forwarded.tag = original.tag
        try expect(forwarded !== original && forwarded.representedObject == nil, "Finder callback has no representedObject")
        try expect(registry.request(for: forwarded.tag, now: now) == create, "copied Finder item resolves create request")
        let openTag = registry.register(open, now: now)
        try expect(registry.request(for: openTag, now: now) == open, "custom application resolves by tag")
        try expect(registry.request(for: original.tag, now: now) == create, "later menu does not replace earlier directory context")
        try expect(openTag != original.tag, "menus have distinct tags")
        try expect(registry.request(for: 0, now: now) == nil, "unset tag is rejected")
        try expect(registry.request(for: -1, now: now) == nil, "unknown tag is rejected")
        let settingsTag = registry.register(.showSettings, now: now.addingTimeInterval(10))
        try expect(registry.request(for: settingsTag, now: now.addingTimeInterval(10)) == .showSettings, "settings menu resolves by tag")
        let terminalTag = registry.register(.openTerminal(directory: directory), now: now.addingTimeInterval(20))
        try expect(registry.request(for: original.tag, now: now) == nil, "capacity eviction rejects old action")
        try expect(terminalTag != original.tag, "evicted tags are never reused")
        try expect(registry.request(for: openTag, now: now.addingTimeInterval(60)) == nil, "expired menu is rejected")
        try expect(registry.request(for: terminalTag, now: now.addingTimeInterval(60)) == .openTerminal(directory: directory), "newer menu remains valid when earlier menu expires")
    }
}
#endif
