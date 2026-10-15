import AppKit
import SwiftUI
import OSLog
import FinderHelperCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let logger = Logger(subsystem: "com.youjianzhushou.app", category: "Windows")
    private var mainWindow: NSWindow?
    private var launchedForAction = CommandLine.arguments.contains("--finder-action")

    func applicationWillFinishLaunching(_ notification: Notification) {
        AppModel.shared.showSettingsWindow = { [weak self] in self?.showMainWindow() }
        AppModel.shared.showBackgroundError = { [weak self] message in
            guard self?.mainWindow?.isVisible != true else { return false }
            // Errors from background actions need only an alert, not settings.
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
                let alert = NSAlert()
                alert.messageText = "操作未完成"
                alert.informativeText = message
                alert.addButton(withTitle: "好")
                alert.runModal()
            }
            return true
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if !launchedForAction { showMainWindow() }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        AppModel.shared.refreshExtensionStatus()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow()
        return false
    }

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool { false }

    func application(_ application: NSApplication, open urls: [URL]) {
        launchedForAction = true
        for url in urls { AppModel.shared.handle(url) }
    }

    private func showMainWindow() {
        if mainWindow == nil {
            let content = ContentView()
                .environmentObject(AppModel.shared)
                .frame(minWidth: 860, minHeight: 560)
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1100, height: 720),
                                  styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                                  backing: .buffered, defer: false)
            window.identifier = NSUserInterfaceItemIdentifier("main")
            window.titleVisibility = .visible
            window.toolbarStyle = .unified
            window.titlebarSeparatorStyle = .automatic
            window.isReleasedWhenClosed = false
            window.minSize = NSSize(width: 860, height: 560)
            window.contentView = NSHostingView(rootView: content)
            window.center()
            window.setFrameAutosaveName("FinderHelperMainWindow")
            mainWindow = window
        }
        Self.logger.notice("Showing settings window")
        NSApp.setActivationPolicy(.regular)
        mainWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
struct FinderHelperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Settings-only lifecycle: the delegate creates the real window only
        // for direct app launches, reopen events, or explicit settings requests.
        Settings { EmptyView() }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("添加文件模板…") {
                    AppModel.shared.section = .files
                    AppModel.shared.showSettingsWindow?()
                    AppModel.shared.templateToEdit = FileTemplate(name: "", fileExtension: "txt", iconName: "doc.text")
                }
                .keyboardShortcut("n")
                Button("导入模板…") {
                    AppModel.shared.section = .files
                    AppModel.shared.showSettingsWindow?()
                    AppModel.shared.importTemplate()
                }
                .keyboardShortcut("o")
            }
            CommandGroup(replacing: .appSettings) {
                Button("菜单设置…") {
                    AppModel.shared.section = .menu
                    AppModel.shared.showSettingsWindow?()
                }
                    .keyboardShortcut(",")
            }
        }
    }
}
