import AppKit
import SwiftUI
import FinderHelperCore

struct ApplicationsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var deleting: CustomApplication?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageHeading(title: "打开方式", subtitle: "在 Finder 右键菜单中，使用常用应用打开文件和文件夹。")
                if model.settings.applications.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "square.stack.3d.up")
                            .font(.system(size: 32, weight: .light))
                            .foregroundStyle(.secondary)
                        Text("添加常用应用").font(.headline)
                        Text("选择编辑器、设计工具或其他应用，\n即可从右键菜单快速打开文件。")
                            .font(.callout).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button("选择应用…", action: model.addApplications).buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 44)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("我的应用").font(.system(size: 12, weight: .semibold))
                            Spacer()
                            Text("\(model.settings.applications.filter(\.isEnabled).count) 个已启用")
                                .font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 2)
                        VStack(spacing: 0) {
                            ForEach(Array(model.settings.applications.enumerated()), id: \.element.id) { index, application in
                                if index > 0 { Divider().padding(.leading, 54) }
                                applicationRow(application)
                            }
                        }
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.line, lineWidth: 0.5))
                    }
                }
                Text("支持一次选中多个文件。可打开的文件格式由目标应用决定。")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                    .padding(.horizontal, 2)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .confirmationDialog("移除「\(deleting?.name ?? "")」？", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
            Button("从菜单移除", role: .destructive) {
                if let deleting { model.settings.applications.removeAll { $0.id == deleting.id } }
                deleting = nil
            }
        } message: { Text("应用本身不会被卸载。") }
    }

    private func applicationRow(_ application: CustomApplication) -> some View {
        HStack(spacing: 10) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: application.path))
                .resizable().frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 3) {
                Text(application.name).font(.system(size: 13, weight: .medium))
                Text(FileManager.default.fileExists(atPath: application.path) ? application.path : "应用已移动，请重新添加")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.middle).help(application.path)
            }
            Spacer(minLength: 4)
            Button { model.chooseFiles(for: application) } label: {
                Image(systemName: "arrow.up.forward.square").frame(width: 20, height: 20)
            }
            .buttonStyle(.borderless).foregroundStyle(.secondary)
            .help("选择文件并试用").accessibilityLabel("使用\(application.name)打开文件")
            Menu {
                Button("在 Finder 中显示") { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: application.path)]) }
                Button("上移") { move(application, offset: -1) }.disabled(model.settings.applications.first?.id == application.id)
                Button("下移") { move(application, offset: 1) }.disabled(model.settings.applications.last?.id == application.id)
                Divider()
                Button("移除", role: .destructive) { deleting = application }
            } label: { Image(systemName: "ellipsis").frame(width: 20, height: 20) }
                .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                .foregroundStyle(.secondary).help("更多操作").accessibilityLabel("\(application.name)的更多操作")
            Toggle("启用\(application.name)", isOn: Binding(get: {
                model.settings.applications.first(where: { $0.id == application.id })?.isEnabled ?? false
            }, set: { enabled in
                if let index = model.settings.applications.firstIndex(where: { $0.id == application.id }) { model.settings.applications[index].isEnabled = enabled }
            }))
            .toggleStyle(.switch).controlSize(.mini).labelsHidden()
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
    }

    private func move(_ application: CustomApplication, offset: Int) {
        guard let index = model.settings.applications.firstIndex(where: { $0.id == application.id }), model.settings.applications.indices.contains(index + offset) else { return }
        model.settings.applications.swapAt(index, index + offset)
    }
}

struct MenuSettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PageHeading(title: "菜单设置", subtitle: "选择 Finder 右键菜单中的功能和生效范围。")
                .padding(.horizontal, 24).padding(.top, 24).padding(.bottom, 6)
            Form {
                Section("右键菜单") {
                    settingToggle("启用右键助手", detail: "控制 Finder 中的全部助手菜单", binding: $model.settings.menuEnabled)
                    settingToggle("复制路径", detail: "多选时每个路径单独一行", binding: $model.settings.showCopyPath)
                    settingToggle("在终端中打开", detail: "在当前文件夹打开所选终端", binding: $model.settings.showOpenInTerminal)
                }
                Section {
                    Picker("默认终端", selection: Binding(get: {
                        model.settings.terminalApplication?.path ?? ""
                    }, set: { path in
                        model.settings.terminalApplication = model.terminalChoices.first { $0.path == path }
                    })) {
                        Text("系统终端").tag("")
                        ForEach(model.terminalChoices) { application in
                            Text(application.name).tag(application.path)
                        }
                    }
                    HStack {
                        Text(model.settings.terminalApplication?.path ?? "使用 macOS 自带终端")
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                            .lineLimit(2).truncationMode(.middle)
                            .help(model.settings.terminalApplication?.path ?? "使用 macOS 自带终端")
                        Spacer(minLength: 8)
                        Button("选择其他…", action: model.chooseTerminalApplication)
                        Button("试用…", action: model.chooseDirectoryAndOpenTerminal)
                    }
                } header: {
                    Text("终端工具")
                } footer: {
                    Text("自动列出已安装的 Ghostty、iTerm2 和 Warp。其他终端需支持打开文件夹。")
                }
                Section("创建文件") {
                    settingToggle("创建后在 Finder 中显示", detail: "定位并选中刚刚创建的文件", binding: $model.settings.revealAfterCreation)
                }
                Section {
                    settingToggle("所有文件夹", detail: "包含本机目录和已挂载的磁盘", binding: Binding(get: { model.settings.monitoredFolders.isEmpty }, set: { all in
                        model.settings.monitoredFolders = all ? [] : [FileManager.default.homeDirectoryForCurrentUser.path]
                    }))
                    if !model.settings.monitoredFolders.isEmpty {
                        ForEach(model.settings.monitoredFolders, id: \.self) { path in
                            HStack(spacing: 8) {
                                Image(systemName: "folder").foregroundStyle(.secondary)
                                Text(path).font(.system(size: 11)).lineLimit(1).truncationMode(.middle).help(path)
                                Spacer()
                                Button {
                                    model.settings.monitoredFolders.removeAll { $0 == path }
                                } label: { Image(systemName: "minus.circle") }
                                .buttonStyle(.borderless).foregroundStyle(.secondary)
                                .disabled(model.settings.monitoredFolders.count == 1)
                                .help("至少保留一个文件夹，或开启「所有文件夹」")
                                .accessibilityLabel("移除文件夹\(path)")
                            }
                        }
                        Button(action: model.addMonitoredFolder) { Label("添加文件夹…", systemImage: "plus") }
                    }
                } header: {
                    Text("生效范围")
                } footer: {
                    Text("系统管理的目录或由其他扩展接管的位置，可能不会显示自定义菜单。")
                }
            }
            .formStyle(.grouped)
            .toggleStyle(.switch)
            .controlSize(.small)
        }
        .onAppear { model.refreshTerminalApplications() }
    }

    private func settingToggle(_ title: String, detail: String, binding: Binding<Bool>) -> some View {
        Toggle(isOn: binding) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 13))
                Text(detail).font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
    }
}

struct MenuPreview: View {
    @EnvironmentObject private var model: AppModel
    private var templates: [FileTemplate] { model.settings.templates.filter(\.isEnabled) }
    private var apps: [CustomApplication] { model.settings.applications.filter(\.isEnabled) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("菜单预览").font(.system(size: 12, weight: .semibold))
                Spacer()
                HStack(spacing: 4) {
                    Circle().fill(model.settings.menuEnabled ? Theme.green : Theme.muted).frame(width: 5, height: 5)
                    Text(model.settings.menuEnabled ? "实时" : "已暂停").font(.system(size: 10))
                }
                .foregroundStyle(.secondary)
            }
            HStack(spacing: 9) {
                Image(systemName: "folder.fill").font(.system(size: 27)).foregroundStyle(.cyan)
                VStack(alignment: .leading, spacing: 3) {
                    Text("我的工作文件夹").font(.system(size: 12, weight: .medium))
                    Text("Finder 右键菜单").font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 2)
            VStack(alignment: .leading, spacing: 0) {
                previewRow("新建文件夹", icon: "folder.badge.plus", faded: true)
                Divider().padding(.horizontal, 7).padding(.vertical, 4)
                if model.settings.menuEnabled {
                    HStack(spacing: 8) {
                        Image(systemName: "cursorarrow.click").frame(width: 16).foregroundStyle(.secondary)
                        Text("右键助手").fontWeight(.semibold)
                        Spacer()
                    }
                    .font(.system(size: 12)).padding(.horizontal, 8).padding(.vertical, 6)
                    if !templates.isEmpty {
                        previewRow("新建文件", icon: "doc.badge.plus", chevron: true)
                        ForEach(templates.prefix(4)) { template in
                            HStack {
                                Text(template.name).lineLimit(1)
                                Spacer(minLength: 2)
                                Text(".\(template.fileExtension)")
                                    .font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
                            }
                            .font(.system(size: 12)).padding(.leading, 32).padding(.trailing, 8).padding(.vertical, 5)
                        }
                        if templates.count > 4 {
                            Text("另有 \(templates.count - 4) 个模板…")
                                .font(.system(size: 11)).foregroundStyle(.secondary)
                                .padding(.leading, 32).padding(.vertical, 5)
                        }
                    }
                    previewRow(apps.isEmpty ? "打开方式" : "打开方式 · \(apps.count) 个应用", icon: "square.stack.3d.up", chevron: true)
                    if model.settings.showCopyPath { previewRow("复制路径", icon: "doc.on.clipboard") }
                    if model.settings.showOpenInTerminal { previewRow(model.settings.terminalMenuTitle, icon: "terminal") }
                    Divider().padding(.horizontal, 7).padding(.vertical, 4)
                    previewRow("右键助手设置…", icon: "gearshape")
                } else {
                    Text("助手菜单已暂停").font(.system(size: 12)).foregroundStyle(.secondary).padding(10)
                }
            }
            .padding(5)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.line, lineWidth: 0.5))
            .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
            Text("预览展示当前配置。实际菜单会根据所选文件或文件夹调整。")
                .font(.system(size: 11)).foregroundStyle(.secondary).lineSpacing(3)
        }
    }

    private func previewRow(_ title: String, icon: String, chevron: Bool = false, faded: Bool = false) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).frame(width: 16).foregroundStyle(.secondary)
            Text(title).lineLimit(1)
            Spacer(minLength: 1)
            if chevron { Image(systemName: "chevron.right").font(.system(size: 9, weight: .semibold)).foregroundStyle(.secondary) }
        }
        .font(.system(size: 12)).foregroundStyle(faded ? Theme.muted : Theme.ink)
        .padding(.horizontal, 8).padding(.vertical, 6)
    }
}

struct HelpView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageHeading(title: "使用指南", subtitle: "完成以下设置，即可在 Finder 中使用右键助手。")
                VStack(alignment: .leading, spacing: 0) {
                    helpStep(1, title: "开启 Finder 扩展", detail: "将右键助手放入「应用程序」后打开。在系统设置的扩展管理中，开启「右键助手」的 Finder 扩展。") {
                        Button("打开扩展设置…", action: model.showExtensionSettings).buttonStyle(.borderedProminent)
                    }
                    Divider().padding(.leading, 48)
                    helpStep(2, title: "配置需要的功能", detail: "在「新建文件」中添加模板，在「打开方式」中选择常用应用。所有设置自动保存。") {
                        Button("配置模板") { model.section = .files }.buttonStyle(.bordered)
                    }
                    Divider().padding(.leading, 48)
                    helpStep(3, title: "回到 Finder，试试右键", detail: "在生效范围内的文件夹空白处右键，选择「右键助手 → 新建文件」。选中文件后，还可以用自定义应用打开或复制路径。") {
                        Button("打开个人文件夹") { NSWorkspace.shared.open(FileManager.default.homeDirectoryForCurrentUser) }.buttonStyle(.bordered)
                    }
                }
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.line, lineWidth: 0.5))
                VStack(alignment: .leading, spacing: 10) {
                    Label("菜单没有出现？", systemImage: "questionmark.circle").font(.system(size: 13, weight: .semibold)).foregroundStyle(.primary)
                    Text("确认扩展开关已开启、生效范围包含当前文件夹，再关闭并重新打开 Finder 窗口。系统保护目录及其他扩展管理的位置可能不支持。")
                    Text("设置由主程序保存，Finder 扩展只读取设置。新建文件、打开方式和复制路径无需开启「完全磁盘访问权限」或「自动化」。")
                    HStack(spacing: 6) {
                        Circle().fill(model.extensionEnabled ? Theme.green : Theme.muted).frame(width: 6, height: 6)
                        Text(model.extensionEnabled ? "Finder 扩展已启用" : "Finder 扩展尚未启用")
                        Spacer()
                        Button("刷新状态", action: model.refreshExtensionStatus).buttonStyle(.bordered)
                    }
                    .padding(.top, 4)
                }
                .font(.system(size: 11)).foregroundStyle(.secondary).lineSpacing(3)
                .padding(.horizontal, 2)
            }
            .controlSize(.small)
            .frame(maxWidth: 680, alignment: .leading)
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func helpStep<Content: View>(_ number: Int, title: String, detail: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)").font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary).frame(width: 22, height: 22)
                .background(.quaternary, in: Circle())
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(detail).font(.system(size: 12)).foregroundStyle(.secondary).lineSpacing(3)
                content().padding(.top, 2)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
