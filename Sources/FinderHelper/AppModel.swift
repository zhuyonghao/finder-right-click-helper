import AppKit
import Combine
import FinderSync
import FinderHelperCore
import UniformTypeIdentifiers
import OSLog

enum AppSection: String, CaseIterable, Identifiable {
    case files = "新建文件"
    case applications = "打开方式"
    case menu = "菜单设置"
    case help = "使用指南"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .files: return "doc.badge.plus"
        case .applications: return "square.stack.3d.up"
        case .menu: return "slider.horizontal.3"
        case .help: return "questionmark.circle"
        }
    }
}

@MainActor
final class AppModel: ObservableObject {
    private static let logger = Logger(subsystem: "com.youjianzhushou.app", category: "Actions")
    static let shared = AppModel()
    @Published var section: AppSection = .files
    @Published var sidebarVisible = true
    @Published var inspectorVisible = true
    @Published var templateToEdit: FileTemplate?
    @Published var settings: AppSettings {
        didSet { persist() }
    }
    @Published var extensionEnabled = false
    @Published var installedTerminalApplications: [CustomApplication] = []
    @Published var errorMessage: String? {
        didSet {
            if let message = errorMessage {
                if showBackgroundError?(message) == true {
                    errorMessage = nil
                    return
                }
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
    var showSettingsWindow: (() -> Void)?
    var showBackgroundError: ((String) -> Bool)?
    @Published var notice: String?
    private var noticeTask: Task<Void, Never>?

    init() {
        settings = ConfigurationStore.shared.load()
        refreshExtensionStatus()
    }

    func persist() {
        do { try ConfigurationStore.shared.save(settings) }
        catch { errorMessage = "设置保存失败：\(error.localizedDescription)" }
    }

    func refreshExtensionStatus() {
        extensionEnabled = FIFinderSyncController.isExtensionEnabled
    }

    func showExtensionSettings() {
        FIFinderSyncController.showExtensionManagementInterface()
    }

    var terminalChoices: [CustomApplication] {
        var choices = installedTerminalApplications
        if let selected = settings.terminalApplication, !choices.contains(where: { $0.path == selected.path }) {
            choices.append(selected)
        }
        return choices
    }

    func refreshTerminalApplications() {
        let identifiers = ["com.mitchellh.ghostty", "com.googlecode.iterm2", "dev.warp.Warp-Stable", "dev.warp.Warp-Preview"]
        installedTerminalApplications = identifiers.compactMap { identifier in
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier),
                  let bundle = Bundle(url: url) else { return nil }
            return terminalApplication(at: url, bundle: bundle)
        }
    }

    func chooseTerminalApplication() {
        let panel = NSOpenPanel()
        panel.title = "选择终端应用"
        panel.message = "选择可接收文件夹路径的终端应用，例如 Ghostty 或 iTerm2。"
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.applicationBundle]
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url, let bundle = Bundle(url: url), bundle.bundleIdentifier != nil else { return }
        settings.terminalApplication = bundle.bundleIdentifier == "com.apple.Terminal" ? nil : terminalApplication(at: url, bundle: bundle)
        refreshTerminalApplications()
        notify("终端已设为\(settings.terminalName)")
    }

    private func terminalApplication(at url: URL, bundle: Bundle) -> CustomApplication {
        let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? url.deletingPathExtension().lastPathComponent
        return CustomApplication(id: url.path, name: name, path: url.path)
    }

    func chooseDirectoryAndOpenTerminal() {
        let panel = NSOpenPanel()
        panel.title = "试用\(settings.terminalName)"
        panel.message = "选择文件夹，确认终端能在该目录打开。"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        guard panel.runModal() == .OK, let directory = panel.url else { return }
        do { try openTerminal(in: directory) }
        catch { errorMessage = error.localizedDescription }
    }

    private func openTerminal(in directory: URL) throws {
        let destination = try directory.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])
        guard destination.isDirectory == true, destination.isPackage != true else {
            throw UserFacingError("终端操作需要一个普通文件夹，请重新选择。")
        }
        let appURL: URL
        if let application = settings.terminalApplication {
            appURL = URL(fileURLWithPath: application.path)
        } else if let systemTerminal = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal") {
            appURL = systemTerminal
        } else {
            throw UserFacingError("找不到系统终端，请在菜单设置中选择其他终端。")
        }
        guard FileManager.default.fileExists(atPath: appURL.path), let bundle = Bundle(url: appURL), bundle.bundleIdentifier != nil else {
            throw UserFacingError("找不到\(settings.terminalName)，请在菜单设置中重新选择终端应用。")
        }
        let url = try TerminalLaunch.destination(bundleIdentifier: bundle.bundleIdentifier, directory: directory)
        let name = settings.terminalName
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.allowsRunningApplicationSubstitution = false
        NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: configuration) { [weak self] runningApplication, error in
            Task { @MainActor in
                if let error { self?.errorMessage = error.localizedDescription }
                else {
                    Self.logger.notice("Opened terminal, bundle=\(bundle.bundleIdentifier ?? "unknown", privacy: .public), pid=\(runningApplication?.processIdentifier ?? 0)")
                    self?.notify("已用\(name)打开文件夹")
                }
            }
        }
    }

    func notify(_ message: String) {
        notice = message
        noticeTask?.cancel()
        noticeTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            self?.notice = nil
        }
    }

    func saveTemplate(_ template: FileTemplate) {
        if let index = settings.templates.firstIndex(where: { $0.id == template.id }) {
            settings.templates[index] = template
        } else { settings.templates.append(template) }
        notify("模板已保存，右键菜单将自动更新")
    }

    func importTemplate() {
        let panel = NSOpenPanel()
        panel.title = "选择文本文件作为模板"
        panel.message = "导入 UTF-8 文本内容，文件大小不超过 1 MB。"
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size <= 1_048_576 else { throw UserFacingError("模板文件超过 1 MB，请选择较小的文本文件。") }
            let content = try String(contentsOf: url, encoding: .utf8)
            let template = FileTemplate(name: url.deletingPathExtension().lastPathComponent,
                                        fileExtension: url.pathExtension, content: content, iconName: "doc.text")
            guard !template.fileExtension.isEmpty else { throw UserFacingError("模板文件需要扩展名，例如 .txt 或 .md。") }
            saveTemplate(template)
        } catch { errorMessage = error.localizedDescription }
    }

    func addApplications() {
        let panel = NSOpenPanel()
        panel.title = "添加打开方式"
        panel.message = "选择应用，它会出现在 Finder 的「打开方式」子菜单中。"
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.applicationBundle]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        var added = 0
        for url in panel.urls {
            guard let bundle = Bundle(url: url), bundle.bundleIdentifier != nil else { continue }
            if settings.applications.contains(where: { $0.path == url.path }) { continue }
            let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
                ?? url.deletingPathExtension().lastPathComponent
            settings.applications.append(CustomApplication(name: name, path: url.path))
            added += 1
        }
        notify(added > 0 ? "已添加 \(added) 个应用" : "所选应用已经在列表中")
    }

    func chooseFiles(for application: CustomApplication) {
        let panel = NSOpenPanel()
        panel.title = "用\(application.name)打开"
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        openFiles(panel.urls, with: application)
    }

    func openFiles(_ urls: [URL], with application: CustomApplication) {
        let appURL = URL(fileURLWithPath: application.path)
        guard FileManager.default.fileExists(atPath: appURL.path), Bundle(url: appURL) != nil else {
            errorMessage = "找不到\(application.name)，请重新添加这个应用。"
            return
        }
        guard !urls.isEmpty, urls.allSatisfy({ $0.isFileURL && FileManager.default.fileExists(atPath: $0.path) }) else {
            errorMessage = "部分文件已经移动或删除，请重新选择。"
            return
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.allowsRunningApplicationSubstitution = false
        NSWorkspace.shared.open(urls, withApplicationAt: appURL, configuration: configuration) { [weak self] _, error in
            Task { @MainActor in
                if let error { self?.errorMessage = error.localizedDescription }
                else { self?.notify("已用\(application.name)打开 \(urls.count) 个项目") }
            }
        }
    }

    func chooseDirectoryAndCreate(_ template: FileTemplate) {
        let panel = NSOpenPanel()
        panel.title = "选择新文件的位置"
        panel.prompt = "选择文件夹"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        createFile(template, in: url)
    }

    func createFile(_ template: FileTemplate, in directory: URL) {
        let panel = FileCreationPanel(template: template, directory: directory)
        guard let url = panel.runModal() else { return }
        if settings.revealAfterCreation { NSWorkspace.shared.activateFileViewerSelecting([url]) }
        notify("已创建 \(url.lastPathComponent)")
    }

    func addMonitoredFolder() {
        let panel = NSOpenPanel()
        panel.title = "选择显示右键助手的文件夹"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        for url in panel.urls where !settings.monitoredFolders.contains(url.path) {
            settings.monitoredFolders.append(url.path)
        }
    }

    func handle(_ url: URL) {
        Self.logger.notice("Received action URL, action=\(url.host ?? "unknown", privacy: .public)")
        do {
            let request = try ActionRequest(url: url)
            switch request {
            case let .create(templateID, directory):
                guard let template = settings.templates.first(where: { $0.id == templateID && $0.isEnabled }), settings.menuEnabled else {
                    throw UserFacingError("此模板已停用或删除，请重新打开右键菜单。")
                }
                createFile(template, in: directory)
            case let .open(applicationID, files):
                guard let application = settings.applications.first(where: { $0.id == applicationID && $0.isEnabled }), settings.menuEnabled else {
                    throw UserFacingError("此应用已从菜单中移除，请重新打开右键菜单。")
                }
                openFiles(files, with: application)
            case let .copyPaths(files):
                guard settings.menuEnabled, settings.showCopyPath else { return }
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(files.map(\.path).joined(separator: "\n"), forType: .string)
                notify("已复制 \(files.count) 个路径")
            case let .openTerminal(directory):
                guard settings.menuEnabled, settings.showOpenInTerminal else { return }
                try openTerminal(in: directory)
            case .showSettings:
                showSettingsWindow?()
            }
        } catch { errorMessage = error.localizedDescription }
    }
}

struct UserFacingError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}
