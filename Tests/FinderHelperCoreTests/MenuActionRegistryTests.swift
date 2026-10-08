import AppKit
import XCTest
@testable import FinderHelperCore

final class MenuActionRegistryTests: XCTestCase {
    func testFinderCopiedItemResolvesCapturedRequestWithoutRepresentedObject() {
        let registry = MenuActionRegistry()
        let directory = URL(fileURLWithPath: "/tmp/目录 A", isDirectory: true)
        let request = ActionRequest.create(templateID: "markdown", directory: directory)
        let original = NSMenuItem(title: "Markdown", action: nil, keyEquivalent: "")
        original.tag = registry.register(request)
        original.representedObject = "Not preserved by Finder"

        let callback = NSMenuItem(title: original.title, action: original.action, keyEquivalent: "")
        callback.tag = original.tag
        XCTAssertNil(callback.representedObject)
        XCTAssertFalse(callback === original)
        XCTAssertEqual(registry.request(for: callback.tag), request)

        let otherDirectory = URL(fileURLWithPath: "/tmp/目录 B", isDirectory: true)
        let otherTag = registry.register(.create(templateID: "text", directory: otherDirectory))
        XCTAssertNotEqual(otherTag, callback.tag)
        XCTAssertEqual(registry.request(for: callback.tag), request)
    }

    func testCustomApplicationAndSettingsRequestsResolveByTag() {
        let registry = MenuActionRegistry()
        let request = ActionRequest.open(applicationID: "editor", files: [URL(fileURLWithPath: "/tmp/file.txt")])
        XCTAssertEqual(registry.request(for: registry.register(request)), request)
        XCTAssertEqual(registry.request(for: registry.register(.showSettings)), .showSettings)
        XCTAssertNil(registry.request(for: 0))
    }

    func testEvictedAndExpiredTagsNeverResolveToAnotherAction() {
        let registry = MenuActionRegistry(capacity: 2, lifetime: 60)
        let now = Date()
        let first = registry.register(.showSettings, now: now)
        let second = registry.register(.copyPaths(files: [URL(fileURLWithPath: "/tmp/a")]), now: now)
        let latest = registry.register(.openTerminal(directory: URL(fileURLWithPath: "/tmp")), now: now.addingTimeInterval(20))
        XCTAssertNil(registry.request(for: first, now: now.addingTimeInterval(20)))
        XCTAssertNotEqual(first, latest)
        XCTAssertNil(registry.request(for: second, now: now.addingTimeInterval(60)))
        XCTAssertNotNil(registry.request(for: latest, now: now.addingTimeInterval(60)))
    }
}
