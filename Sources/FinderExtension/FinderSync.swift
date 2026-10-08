import AppKit
import FinderSync
import OSLog
#if canImport(FinderHelperCore)
import FinderHelperCore
#endif

/// The extension only builds menus. File access and application launching live in
/// the containing app so the Finder process never performs those operations.
@objc(FinderSync)
final class FinderSync: FIFinderSync {
    private static let logger = Logger(subsystem: "com.youjianzhushou.app.FinderExtension", category: "FinderSync")
    private static let hostBundleIdentifier = "com.youjianzhushou.app"

    private var settings = ConfigurationStore.shared.load()
    private var refreshTimer: Timer?
    private var monitoredURLs: Set<URL>?
    private let menuActions = MenuActionRegistry()

    override init() {
        super.init()
        refreshConfiguration()

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(configurationDidChange(_:)),
            name: ConfigurationStore.configurationDidChange,
            object: nil,
            suspensionBehavior: .deliverImmediately
        )
        let workspaceNotifications = NSWorkspace.shared.notificationCenter
        workspaceNotifications.addObserver(self, selector: #selector(volumesDidChange(_:)), name: NSWorkspace.didMountNotification, object: nil)
        workspaceNotifications.addObserver(self, selector: #selector(volumesDidChange(_:)), name: NSWorkspace.didUnmountNotification, object: nil)

        // Distributed notifications can be coalesced while this process is idle.
        // A low-frequency fallback also picks up preferences changed externally.
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            self?.refreshConfiguration()
        }
        refreshTimer?.tolerance = 3
    }

    deinit {
        refreshTimer?.invalidate()
        DistributedNotificationCenter.default().removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    override var toolbarItemName: String { "右键助手" }
    override var toolbarItemToolTip: String { "新建文件、自定义应用打开及更多操作" }
    override var toolbarItemImage: NSImage {
        NSImage(systemSymbolName: "cursorarrow.click.2", accessibilityDescription: "右键助手")
            ?? NSImage(size: NSSize(width: 18, height: 18))
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        // Read on every invocation so an already-running Finder sees edits made
        // in the host immediately, even if a notification was missed.
        refreshConfiguration()
        guard settings.menuEnabled else { return nil }

        let controller = FIFinderSyncController.default()
        let context = MenuContext(
            kind: menuKind,
            target: controller.targetedURL(),
            selection: controller.selectedItemURLs() ?? []
        )

        let menu = makeMenu(title: "右键助手")
        let contents = makeMenu(title: "右键助手")
        let root = NSMenuItem(title: "右键助手", action: nil, keyEquivalent: "")
        root.image = symbol("cursorarrow.click.2")
        root.submenu = contents
        menu.addItem(root)

        let creationMenu = makeMenu(title: "新建文件")
        let templates = settings.templates.filter(\.isEnabled)
        for template in templates {
            let request = context.directory.map { ActionRequest.create(templateID: template.id, directory: $0) }
            let item = actionItem(title: template.name, image: template.iconName, request: request)
            if let directory = context.directory {
                item.toolTip = "在 \(directory.path) 中新建文件"
            } else {
                item.toolTip = "请在普通文件夹中使用此操作"
            }
            creationMenu.addItem(item)
        }
        if templates.isEmpty {
            creationMenu.addItem(actionItem(title: "添加文件模板…", image: "plus", request: .showSettings))
        }
        let creationItem = NSMenuItem(title: "新建文件", action: nil, keyEquivalent: "")
        creationItem.image = symbol("doc.badge.plus")
        creationItem.submenu = creationMenu
        contents.addItem(creationItem)

        let applicationMenu = makeMenu(title: "打开方式")
        let applications = settings.applications.filter(\.isEnabled)
        for application in applications {
            let request: ActionRequest? = context.files.isEmpty ? nil : .open(applicationID: application.id, files: context.files)
            let item = actionItem(title: application.name, image: "app", request: request)
            item.toolTip = application.path
            applicationMenu.addItem(item)
        }
        applicationMenu.addItem(actionItem(title: "管理应用…", image: "plus", request: .showSettings))
        let applicationItem = NSMenuItem(title: "打开方式", action: nil, keyEquivalent: "")
        applicationItem.image = symbol("arrow.up.forward.app")
        applicationItem.submenu = applicationMenu
        contents.addItem(applicationItem)

        if settings.showCopyPath {
            let request: ActionRequest? = context.files.isEmpty ? nil : .copyPaths(files: context.files)
            contents.addItem(actionItem(title: context.files.count > 1 ? "复制所选路径" : "复制路径", image: "doc.on.doc", request: request))
        }
        if settings.showOpenInTerminal {
            let request = context.directory.map { ActionRequest.openTerminal(directory: $0) }
            contents.addItem(actionItem(title: settings.terminalMenuTitle, image: "terminal", request: request))
        }
        contents.addItem(actionItem(title: "设置…", image: "gearshape", request: .showSettings))
        return menu
    }

    private func makeMenu(title: String) -> NSMenu {
        let menu = NSMenu(title: title)
        menu.autoenablesItems = false
        return menu
    }

    private func actionItem(title: String, image: String, request: ActionRequest?) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(performMenuAction(_:)), keyEquivalent: "")
        item.target = self
        item.image = symbol(image)
        item.isEnabled = request != nil
        if let request {
            // Capture the context now: the Finder selection may change before
            // the containing app receives the eventual URL event.
            // Finder copies menu items into another process. representedObject
            // and custom subclasses are not preserved; the supported tag is.
            item.tag = menuActions.register(request)
        }
        return item
    }

    private func symbol(_ name: String) -> NSImage? {
        let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)
            ?? NSImage(systemSymbolName: "doc", accessibilityDescription: nil)
        image?.size = NSSize(width: 16, height: 16)
        return image
    }

    @objc private func performMenuAction(_ sender: NSMenuItem) {
        Self.logger.notice("Menu action received, tag=\(sender.tag)")
        guard let request = menuActions.request(for: sender.tag) else {
            Self.logger.error("No request for menu tag \(sender.tag); reopen the menu.")
            NSSound.beep()
            return
        }
        do {
            let url = try request.makeURL()
            guard let applicationURL = containingApplicationURL() else {
                Self.logger.error("The containing application could not be located.")
                NSSound.beep()
                return
            }
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.allowsRunningApplicationSubstitution = false
            configuration.activates = false
            // This flag only affects cold launches; an existing settings window
            // remains under the user's control during subsequent actions.
            configuration.arguments = ["--finder-action"]
            if case .showSettings = request {
                configuration.activates = true
            }
            NSWorkspace.shared.open([url], withApplicationAt: applicationURL, configuration: configuration) { _, error in
                if let error {
                    Self.logger.error("Could not deliver a menu action: \(error.localizedDescription)")
                    NSSound.beep()
                } else {
                    Self.logger.notice("Delivered menu action to the containing app.")
                }
            }
        } catch {
            Self.logger.error("Could not encode a menu action: \(error.localizedDescription)")
            NSSound.beep()
        }
    }

    private func containingApplicationURL() -> URL? {
        // Prefer this extension's own containing app when several builds exist.
        let containingURL = Bundle.main.bundleURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        if containingURL.pathExtension == "app",
           Bundle(url: containingURL)?.bundleIdentifier == Self.hostBundleIdentifier {
            return containingURL
        }
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: Self.hostBundleIdentifier)
    }

    @objc private func configurationDidChange(_ notification: Notification) {
        refreshConfiguration()
    }

    @objc private func volumesDidChange(_ notification: Notification) {
        refreshConfiguration()
    }

    private func refreshConfiguration() {
        settings = ConfigurationStore.shared.load()
        var directories = Set<URL>()
        if settings.monitoredFolders.isEmpty {
            // An empty list means the user selected “all folders”.
            directories.insert(URL(fileURLWithPath: "/", isDirectory: true))
            // Register removable/network volume roots without traversing them
            // or requesting directory contents. Inaccessible volumes simply
            // produce no additions; mount notifications refresh the set.
            let volumes = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: nil, options: [.skipHiddenVolumes]) ?? []
            directories.formUnion(volumes.filter(\.isFileURL).map(\.standardizedFileURL))
        } else {
            for path in settings.monitoredFolders {
                let expandedPath = (path as NSString).expandingTildeInPath
                guard expandedPath.hasPrefix("/") else { continue }
                directories.insert(URL(fileURLWithPath: expandedPath, isDirectory: true).standardizedFileURL)
            }
        }
        if monitoredURLs != directories {
            FIFinderSyncController.default().directoryURLs = directories
            monitoredURLs = directories
        }
    }
}

private struct MenuContext {
    let files: [URL]
    let directory: URL?

    init(kind: FIMenuKind, target: URL?, selection: [URL]) {
        let target = target.flatMap { $0.isFileURL ? $0.standardizedFileURL : nil }
        let selection = Self.uniqueFileURLs(selection)

        switch kind {
        case .contextualMenuForContainer, .contextualMenuForSidebar:
            // A background/sidebar click refers to its own target. The Finder
            // may still report unrelated selected items in the current window.
            files = target.map { [$0] } ?? []
            directory = target.flatMap(Self.folder)
        case .contextualMenuForItems, .toolbarItemMenu:
            files = selection.isEmpty ? (target.map { [$0] } ?? []) : selection
            if files.count == 1, let folder = Self.folder(files[0]) {
                directory = folder
            } else if !files.isEmpty {
                let parents = Set(files.map { $0.deletingLastPathComponent().standardizedFileURL })
                directory = parents.count == 1 ? parents.first : nil
            } else {
                directory = target.flatMap(Self.folder)
            }
        @unknown default:
            files = []
            directory = nil
        }
    }

    private static func uniqueFileURLs(_ urls: [URL]) -> [URL] {
        var seen = Set<URL>()
        return urls.filter(\.isFileURL).map(\.standardizedFileURL).filter { seen.insert($0).inserted }
    }

    private static func folder(_ url: URL) -> URL? {
        guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey]),
              values.isDirectory == true,
              values.isPackage != true else { return nil }
        return url
    }
}
