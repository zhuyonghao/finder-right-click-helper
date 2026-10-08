import AppKit
import SwiftUI
import FinderHelperCore

struct ApplicationsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var deleting: CustomApplication?

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            PageHeading(title: "好文件，配好工具。", subtitle: "把常用应用放进右键菜单，文件与文件夹都能一键交给它。")
            AccentButton(title: "添加应用", icon: "plus", action: model.addApplications)
            HStack {
                Text("我的应用").font(.system(size: 13, weight: .semibold))
                Spacer()
                Text("\(model.settings.applications.filter(\.isEnabled).count) 个已启用").font(.system(size: 11)).foregroundStyle(Theme.muted)
            }
            if model.settings.applications.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "square.stack.3d.up").font(.system(size: 37, weight: .light)).foregroundStyle(Theme.accent)
                    Text("让常用应用触手可及").font(.system(size: 15, weight: .semibold))
                    Text("添加编辑器、设计工具或其他应用。\n下次选中文件，右键就能快速打开。")
                        .font(.system(size: 12)).foregroundStyle(Theme.muted).lineSpacing(6).multilineTextAlignment(.center)
                    Button("选择应用…", action: model.addApplications).buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 45)
                .background(.white, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line))
            } else {
                VStack(spacing: 10) {
                    ForEach(model.settings.applications) { application in applicationRow(application) }
                }
            }
            Label("支持一次选中多个文件；能否打开取决于目标应用支持的格式。", systemImage: "info.circle")
                .font(.system(size: 11)).foregroundStyle(Theme.muted)
        }
        .confirmationDialog("移除「\(deleting?.name ?? "")」？", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
            Button("从菜单移除", role: .destructive) {
                if let deleting { model.settings.applications.removeAll { $0.id == deleting.id } }
                deleting = nil
            }
        } message: { Text("应用本身不会被卸载。") }
    }

    private func applicationRow(_ application: CustomApplication) -> some View {
        HStack(spacing: 12) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: application.path)).resizable().frame(width: 42, height: 42)
            VStack(alignment: .leading, spacing: 5) {
                Text(application.name).font(.system(size: 12, weight: .semibold))
                Text(FileManager.default.fileExists(atPath: application.path) ? application.path : "应用已移动，请重新添加")
                    .font(.system(size: 9)).foregroundStyle(Theme.muted).lineLimit(1).truncationMode(.middle).help(application.path)
            }
            Spacer(minLength: 0)
            Button { model.chooseFiles(for: application) } label: { Image(systemName: "arrow.up.forward.square") }
                .buttonStyle(.plain).foregroundStyle(Theme.muted).help("选择文件并试用")
            Menu {
                Button("在 Finder 中显示") { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: application.path)]) }
                Button("上移") { move(application, offset: -1) }.disabled(model.settings.applications.first?.id == application.id)
                Button("下移") { move(application, offset: 1) }.disabled(model.settings.applications.last?.id == application.id)
                Divider()
                Button("移除", role: .destructive) { deleting = application }
            } label: { Image(systemName: "ellipsis").frame(width: 16) }
                .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
            Toggle("启用\(application.name)", isOn: Binding(get: {
                model.settings.applications.first(where: { $0.id == application.id })?.isEnabled ?? false
            }, set: { enabled in
                if let index = model.settings.applications.firstIndex(where: { $0.id == application.id }) { model.settings.applications[index].isEnabled = enabled }
            })).toggleStyle(.switch).controlSize(.mini).labelsHidden()
        }
        .padding(16).background(.white, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line))
    }

    private func move(_ application: CustomApplication, offset: Int) {
        guard let index = model.settings.applications.firstIndex(where: { $0.id == application.id }), model.settings.applications.indices.contains(index + offset) else { return }
        model.settings.applications.swapAt(index, index + offset)
    }
}

struct MenuSettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            PageHeading(title: "你的右键，你做主。", subtitle: "只留下需要的功能，让每一次操作都刚刚好。")
            settingsGroup("右键菜单") {
                settingRow("启用右键助手", detail: "控制 Finder 中的全部助手菜单", icon: "cursorarrow.click", binding: $model.settings.menuEnabled)
                Divider().padding(.leading, 46)
                settingRow("复制路径", detail: "多选时每个路径单独一行", icon: "doc.on.clipboard", binding: $model.settings.showCopyPath)
                Divider().padding(.leading, 46)
                settingRow("在终端中打开", detail: "在当前文件夹打开你选择的终端", icon: "terminal", binding: $model.settings.showOpenInTerminal)
            }
            settingsGroup("终端工具") {
                HStack(spacing: 12) {
                    Image(systemName: "terminal").foregroundStyle(Theme.accent).frame(width: 24)
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
                    .font(.system(size: 12)).frame(maxWidth: 310)
                    Spacer(minLength: 0)
                    Button("选择其他…", action: model.chooseTerminalApplication).controlSize(.small)
                }.padding(15)
                Divider().padding(.leading, 46)
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(model.settings.terminalApplication?.path ?? "使用 macOS 自带终端")
                            .lineLimit(2).truncationMode(.middle)
                        Text("自动列出已安装的 Ghostty、iTerm2 和 Warp。其他终端需支持打开文件夹。")
                    }.font(.system(size: 10)).foregroundStyle(Theme.muted)
                    Spacer(minLength: 0)
                    Button("试用…", action: model.chooseDirectoryAndOpenTerminal).controlSize(.small)
                }.padding(15)
            }
            settingsGroup("创建文件") {
                settingRow("创建后在 Finder 中显示", detail: "定位并选中刚刚创建的文件", icon: "folder.badge.gearshape", binding: $model.settings.revealAfterCreation)
            }
            settingsGroup("生效范围") {
                settingRow("所有文件夹", detail: "包含本机目录和已挂载的磁盘", icon: "externaldrive", binding: Binding(get: { model.settings.monitoredFolders.isEmpty }, set: { all in
                    model.settings.monitoredFolders = all ? [] : [FileManager.default.homeDirectoryForCurrentUser.path]
                }))
                if !model.settings.monitoredFolders.isEmpty {
                    Divider()
                    ForEach(model.settings.monitoredFolders, id: \.self) { path in
                        HStack(spacing: 8) {
                            Image(systemName: "folder").foregroundStyle(Theme.accent)
                            Text(path).font(.system(size: 10)).lineLimit(1).truncationMode(.middle).help(path)
                            Spacer()
                            Button {
                                model.settings.monitoredFolders.removeAll { $0 == path }
                            } label: { Image(systemName: "minus.circle") }
                            .buttonStyle(.plain).foregroundStyle(Theme.muted)
                            .disabled(model.settings.monitoredFolders.count == 1)
                            .help("至少保留一个文件夹，或开启「所有文件夹」")
                        }.padding(.horizontal, 15).padding(.vertical, 8)
                    }
                    Button(action: model.addMonitoredFolder) { Label("添加文件夹", systemImage: "plus").font(.system(size: 11)) }
                        .buttonStyle(.plain).foregroundStyle(Theme.accent).padding(15)
                }
            }
            Text("系统管理的目录或由其他扩展接管的位置，可能不会显示自定义菜单。")
                .font(.system(size: 10)).foregroundStyle(Theme.muted).lineSpacing(4)
        }
        .onAppear { model.refreshTerminalApplications() }
    }

    private func settingsGroup<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.system(size: 12, weight: .semibold))
            VStack(alignment: .leading, spacing: 0, content: content)
                .background(.white, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line))
        }
    }

    private func settingRow(_ title: String, detail: String, icon: String, binding: Binding<Bool>) -> some View {
        HStack(spacing: 11) {
            Image(systemName: icon).font(.system(size: 17)).foregroundStyle(Theme.muted).frame(width: 24)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.system(size: 12, weight: .medium))
                Text(detail).font(.system(size: 10)).foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 2)
            Toggle(title, isOn: binding).labelsHidden().toggleStyle(.switch).controlSize(.small)
        }.padding(15)
    }
}

struct MenuPreview: View {
    @EnvironmentObject private var model: AppModel
    private var templates: [FileTemplate] { model.settings.templates.filter(\.isEnabled) }
    private var apps: [CustomApplication] { model.settings.applications.filter(\.isEnabled) }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("菜单预览").font(.system(size: 11, weight: .semibold))
                Spacer()
                Text("实时").font(.system(size: 9)).foregroundStyle(Theme.green)
                    .padding(.horizontal, 7).padding(.vertical, 3).background(Theme.green.opacity(0.08), in: Capsule())
            }
            VStack(spacing: 0) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10).fill(Color(red: 0.90, green: 0.925, blue: 0.914))
                    VStack(spacing: 7) {
                        Image(systemName: "folder.fill").font(.system(size: 39)).foregroundStyle(Color(red: 0.50, green: 0.70, blue: 0.79))
                            .shadow(color: .black.opacity(0.04), radius: 3, y: 3)
                        Text("我的工作文件夹").font(.system(size: 10)).foregroundStyle(Theme.ink.opacity(0.65))
                    }
                }.frame(height: 111)
                VStack(alignment: .leading, spacing: 1) {
                    previewRow("新建文件夹", icon: "folder.badge.plus", faded: true)
                    Divider().padding(.vertical, 5)
                    if model.settings.menuEnabled {
                        HStack {
                            Image(systemName: "cursorarrow.click").frame(width: 15)
                            Text("右键助手").fontWeight(.semibold)
                            Spacer()
                        }.font(.system(size: 11)).foregroundStyle(Theme.accent).padding(8)
                            .background(Theme.accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 5))
                        if !templates.isEmpty {
                            previewRow("新建文件", icon: "doc.badge.plus", chevron: true)
                            ForEach(templates.prefix(4)) { template in
                                HStack {
                                    Text(template.name)
                                    Spacer(minLength: 2)
                                    Text(".\(template.fileExtension)").font(.system(size: 8, design: .monospaced)).foregroundStyle(Theme.muted)
                                }.font(.system(size: 10)).padding(.leading, 31).padding(.trailing, 8).padding(.vertical, 5)
                            }
                            if templates.count > 4 {
                                Text("另有 \(templates.count - 4) 个模板…").font(.system(size: 9)).foregroundStyle(Theme.muted).padding(.leading, 31).padding(.vertical, 4)
                            }
                        }
                        previewRow(apps.isEmpty ? "打开方式" : "打开方式 · \(apps.count) 个应用", icon: "square.stack.3d.up", chevron: true)
                        if model.settings.showCopyPath { previewRow("复制路径", icon: "doc.on.clipboard") }
                        if model.settings.showOpenInTerminal { previewRow(model.settings.terminalMenuTitle, icon: "terminal") }
                        Divider().padding(.vertical, 4)
                        previewRow("右键助手设置…", icon: "gearshape")
                    } else {
                        Text("助手菜单已暂停").font(.system(size: 11)).foregroundStyle(Theme.muted).padding(10)
                    }
                }
                .padding(8).background(.white, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(.black.opacity(0.07)))
                .shadow(color: .black.opacity(0.055), radius: 10, y: 5)
                .padding(.horizontal, 9).padding(.top, -12)
            }
            Text("预览仅展示菜单配置。实际菜单会根据所选文件或文件夹调整。")
                .font(.system(size: 10)).foregroundStyle(Theme.muted).lineSpacing(5).padding(.horizontal, 3)
            Spacer(minLength: 20)
        }
    }

    private func previewRow(_ title: String, icon: String, chevron: Bool = false, faded: Bool = false) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).frame(width: 15).foregroundStyle(Theme.muted)
            Text(title).lineLimit(1)
            Spacer(minLength: 1)
            if chevron { Image(systemName: "chevron.right").font(.system(size: 8, weight: .semibold)).foregroundStyle(Theme.muted) }
        }
        .font(.system(size: 10)).foregroundStyle(faded ? Theme.muted : Theme.ink)
        .padding(.horizontal, 8).padding(.vertical, 7)
    }
}

struct HelpView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            PageHeading(title: "准备好，让操作少几步。", subtitle: "三步配置好，在熟悉的 Finder 里继续工作。")
            helpStep(1, title: "开启 Finder 扩展", detail: "将右键助手放入「应用程序」后打开。在系统设置的扩展管理中，开启「右键助手」的 Finder 扩展。") {
                Button("打开扩展设置", action: model.showExtensionSettings).buttonStyle(.borderedProminent)
            }
            helpStep(2, title: "配置你需要的功能", detail: "在「新建文件」中添加模板，在「打开方式」中选择常用应用。所有设置自动保存。") {
                Button("去配置模板") { model.section = .files }.buttonStyle(.bordered)
            }
            helpStep(3, title: "回到 Finder，试试右键", detail: "在生效范围内的文件夹空白处右键，选择「右键助手 → 新建文件」。选中文件后，还可以用自定义应用打开或复制路径。") {
                Button("打开个人文件夹") { NSWorkspace.shared.open(FileManager.default.homeDirectoryForCurrentUser) }.buttonStyle(.bordered)
            }
            VStack(alignment: .leading, spacing: 13) {
                Label("菜单没有出现？", systemImage: "wrench.and.screwdriver").font(.system(size: 13, weight: .semibold))
                Text("先确认扩展开关已开启、菜单设置中的生效范围包含当前文件夹，再关闭并重新打开 Finder 窗口。系统保护目录及其他扩展管理的位置可能不支持。")
                Text("设置由主程序保存，Finder 扩展仅有读取右键助手设置的权限。新建文件、打开方式和复制路径无需开启「完全磁盘访问权限」或「自动化」。")
                HStack {
                    Circle().fill(model.extensionEnabled ? Theme.green : Theme.accent).frame(width: 6, height: 6)
                    Text(model.extensionEnabled ? "系统报告：扩展已启用" : "系统报告：扩展尚未启用")
                    Spacer()
                    Button("刷新状态", action: model.refreshExtensionStatus).buttonStyle(.bordered)
                }.padding(.top, 3)
            }
            .font(.system(size: 11)).foregroundStyle(Theme.muted).lineSpacing(5)
            .padding(20).background(.white, in: RoundedRectangle(cornerRadius: 12))
        }.frame(maxWidth: 680, alignment: .leading)
    }

    private func helpStep<Content: View>(_ number: Int, title: String, detail: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .top, spacing: 17) {
            Text(String(format: "%02d", number)).font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(Theme.accent).frame(width: 37, height: 37)
                .background(Theme.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 10) {
                Text(title).font(.system(size: 15, weight: .semibold))
                Text(detail).font(.system(size: 12)).foregroundStyle(Theme.muted).lineSpacing(5)
                content().font(.system(size: 11)).padding(.top, 2)
            }
        }
    }
}
