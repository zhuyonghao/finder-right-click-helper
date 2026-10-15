import AppKit
import SwiftUI
import FinderHelperCore

enum Theme {
    static let accent = Color.accentColor
    static let ink = Color.primary
    static let muted = Color.secondary
    static let canvas = Color(nsColor: .windowBackgroundColor)
    static let surface = Color(nsColor: .controlBackgroundColor)
    static let line = Color(nsColor: .separatorColor).opacity(0.5)
    static let green = Color.green

    static func color(for ext: String) -> Color {
        switch ext.lowercased() {
        case "md": return .indigo
        case "json", "yaml", "yml", "html", "swift": return .orange
        case "py": return .blue
        case "css": return .purple
        default: return .green
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var model: AppModel

    private var columnVisibility: Binding<NavigationSplitViewVisibility> {
        Binding(get: { model.sidebarVisible ? .all : .detailOnly },
                set: { model.sidebarVisible = $0 != .detailOnly })
    }

    private var selection: Binding<AppSection?> {
        Binding(get: { model.section }, set: { if let section = $0 { model.section = section } })
    }

    var body: some View {
        NavigationSplitView(columnVisibility: columnVisibility) {
            sidebar
                .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
        } detail: {
            VStack(spacing: 0) {
                if !model.extensionEnabled { activationBanner }
                Group {
                    switch model.section {
                    case .files: TemplatesView()
                    case .applications: ApplicationsView()
                    case .menu: MenuSettingsView()
                    case .help: HelpView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                footer
            }
            .frame(minWidth: 380)
            .background(Theme.canvas)
            .navigationTitle(model.section.rawValue)
            .navigationSubtitle("右键助手")
            .inspector(isPresented: Binding(get: {
                model.inspectorVisible && model.section != .help
            }, set: { if model.section != .help { model.inspectorVisible = $0 } })) {
                ScrollView {
                    MenuPreview().padding(20)
                }
                .background(Theme.canvas)
                .inspectorColumnWidth(min: 250, ideal: 270, max: 320)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if model.section == .files {
                    Button(action: model.importTemplate) {
                        Label("导入模板", systemImage: "square.and.arrow.down")
                    }
                    .help("从文本文件导入模板（⌘O）")
                    Button {
                        model.templateToEdit = FileTemplate(name: "", fileExtension: "txt", iconName: "doc.text")
                    } label: {
                        Label("添加模板", systemImage: "plus")
                    }
                    .help("添加文件模板（⌘N）")
                } else if model.section == .applications {
                    Button(action: model.addApplications) {
                        Label("添加应用", systemImage: "plus")
                    }
                    .help("添加打开文件的应用")
                }
                if model.section != .help {
                    Button { model.inspectorVisible.toggle() } label: {
                        Label("菜单预览", systemImage: "sidebar.right")
                    }
                    .help(model.inspectorVisible ? "隐藏菜单预览" : "显示菜单预览")
                }
            }
        }
        .alert("操作未完成", isPresented: Binding(get: { model.errorMessage != nil }, set: {
            if !$0 { model.errorMessage = nil }
        })) {
            Button("好", role: .cancel) { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "") }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            List(selection: selection) {
                Section("工作空间") {
                    navigationRow(.files, count: model.settings.templates.filter(\.isEnabled).count)
                    navigationRow(.applications, count: model.settings.applications.filter(\.isEnabled).count)
                    navigationRow(.menu)
                }
                Section("帮助") {
                    navigationRow(.help)
                }
            }
            .listStyle(.sidebar)
            .safeAreaInset(edge: .top, spacing: 0) {
                HStack(spacing: 8) {
                    Image(nsImage: NSImage(named: NSImage.applicationIconName) ?? NSImage())
                        .resizable().frame(width: 28, height: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("右键助手").font(.system(size: 13, weight: .semibold))
                        Text("Finder 扩展").font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.vertical, 14)
            }
            Divider()
            VStack(alignment: .leading, spacing: 9) {
                Button(action: model.showExtensionSettings) {
                    HStack(spacing: 6) {
                        Circle().fill(model.extensionEnabled ? Theme.green : .orange).frame(width: 6, height: 6)
                        Text(model.extensionEnabled ? "Finder 扩展已启用" : "启用 Finder 扩展…")
                            .font(.system(size: 11))
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.up.forward").font(.system(size: 9))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("在系统设置中管理 Finder 扩展")
                Text("版本 \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.6")")
                    .font(.system(size: 10)).foregroundStyle(.tertiary)
            }
            .padding(16)
        }
    }

    private func navigationRow(_ section: AppSection, count: Int? = nil) -> some View {
        HStack {
            Label(section.rawValue, systemImage: section.icon)
            Spacer(minLength: 0)
            if let count, count > 0 {
                Text(count, format: .number).font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
        .tag(section)
    }

    private var activationBanner: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "puzzlepiece.extension").foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 3) {
                    Text("启用 Finder 扩展").font(.system(size: 12, weight: .medium))
                    Text("在系统设置中开启，即可使用右键菜单。").font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Button("打开设置…", action: model.showExtensionSettings).controlSize(.small)
            }
            .padding(.horizontal, 20).padding(.vertical, 12)
            Divider()
        }
    }

    private var footer: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 6) {
                Image(systemName: model.notice == nil ? "checkmark.circle" : "checkmark.circle.fill")
                    .foregroundStyle(model.notice == nil ? Theme.muted : Theme.green)
                Text(model.notice ?? "所有更改自动保存")
                    .lineLimit(1).truncationMode(.middle)
                Spacer(minLength: 8)
                Image(systemName: "lock.shield").help("本地运行，无需联网")
            }
            .font(.system(size: 11)).foregroundStyle(.secondary)
            .padding(.horizontal, 20).frame(height: 30)
        }
    }
}

struct PageHeading: View {
    var title: String
    var subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 20, weight: .semibold))
            Text(subtitle).font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct AccentButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) { Label(title, systemImage: icon) }
            .buttonStyle(.borderedProminent)
    }
}

struct TemplatesView: View {
    @EnvironmentObject private var model: AppModel
    @State private var search = ""
    @State private var selectedID: FileTemplate.ID?
    @State private var deleting: FileTemplate?
    @FocusState private var searchFocused: Bool

    private var filtered: [FileTemplate] {
        model.settings.templates.filter {
            search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) || $0.fileExtension.localizedCaseInsensitiveContains(search)
        }
    }

    private var selectedTemplate: FileTemplate? {
        filtered.first { $0.id == selectedID }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 18) {
                PageHeading(title: "文件模板", subtitle: "管理 Finder 右键菜单中的新建文件类型。")
                HStack {
                    Text("\(model.settings.templates.count) 个模板 · \(model.settings.templates.filter(\.isEnabled).count) 个已启用")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                    Spacer(minLength: 8)
                    searchField
                }
            }
            .padding(20)
            Divider()
            if filtered.isEmpty {
                ContentUnavailableView(search.isEmpty ? "尚无文件模板" : "没有找到模板", systemImage: "doc.text.magnifyingglass", description: Text(search.isEmpty ? "点击工具栏中的加号，或导入文本文件。" : "试试其他名称或扩展名。"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                templateTable
            }
            Divider()
            HStack(spacing: 8) {
                Button {
                    if let template = selectedTemplate { model.chooseDirectoryAndCreate(template) }
                } label: { Label("新建文件…", systemImage: "doc.badge.plus") }
                .disabled(selectedTemplate == nil)
                Button("编辑…") { model.templateToEdit = selectedTemplate }
                    .disabled(selectedTemplate == nil)
                Spacer(minLength: 0)
                Text("双击模板以编辑").font(.system(size: 11)).foregroundStyle(.secondary)
            }
            .controlSize(.small).padding(.horizontal, 20).padding(.vertical, 10)
        }
        .background(Theme.surface)
        .sheet(item: $model.templateToEdit) { template in
            TemplateEditor(template: template) { model.saveTemplate($0) }
        }
        .confirmationDialog("删除「\(deleting?.name ?? "")」模板？", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
            Button("删除模板", role: .destructive) {
                if let deleting { model.settings.templates.removeAll { $0.id == deleting.id } }
                deleting = nil
            }
        } message: { Text("已创建的文件不会受到影响。") }
        .onChange(of: search) { _, _ in
            if !filtered.contains(where: { $0.id == selectedID }) { selectedID = nil }
        }
        .background {
            Button("搜索模板") { searchFocused = true }
                .keyboardShortcut("f").hidden()
        }
    }

    private var searchField: some View {
        HStack(spacing: 5) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("搜索模板", text: $search)
                .textFieldStyle(.plain).focused($searchFocused)
                .accessibilityLabel("搜索模板")
            if !search.isEmpty {
                Button { search = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                    .buttonStyle(.plain).accessibilityLabel("清除搜索")
            }
        }
        .font(.system(size: 12)).padding(.horizontal, 7).padding(.vertical, 5)
        .background(Theme.canvas, in: RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.line))
        .frame(width: 160)
    }

    private var templateTable: some View {
        Table(filtered, selection: $selectedID) {
            TableColumn("模板名称") { template in
                HStack(spacing: 9) {
                    FileBadge(template: template)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(template.name).font(.system(size: 13)).lineLimit(1)
                        Text(template.content.isEmpty ? "空白文件" : "包含预设内容")
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 7)
            }.width(min: 140, ideal: 220)
            TableColumn("类型") { template in
                Text(".\(template.fileExtension)").font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
            }.width(55)
            TableColumn("启用") { template in
                Toggle("启用\(template.name)", isOn: enabledBinding(for: template))
                    .labelsHidden().toggleStyle(.switch).controlSize(.mini)
            }.width(48)
            TableColumn("") { template in
                Menu { templateActions(template) } label: {
                    Image(systemName: "ellipsis").frame(width: 22, height: 22)
                }
                .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                .help("\(template.name)的更多操作")
                .accessibilityLabel("\(template.name)的更多操作")
            }.width(28)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .contextMenu(forSelectionType: String.self) { ids in
            if let template = filtered.first(where: { ids.contains($0.id) }) {
                templateActions(template)
            }
        } primaryAction: { ids in
            model.templateToEdit = filtered.first { ids.contains($0.id) }
        }
    }

    @ViewBuilder
    private func templateActions(_ template: FileTemplate) -> some View {
        Button("新建文件…") { model.chooseDirectoryAndCreate(template) }
        Button("编辑模板…") { model.templateToEdit = template }
        Divider()
        Button("上移") { move(template, by: -1) }.disabled(model.settings.templates.first?.id == template.id)
        Button("下移") { move(template, by: 1) }.disabled(model.settings.templates.last?.id == template.id)
        Divider()
        Button("删除模板…", role: .destructive) { deleting = template }
    }

    private func enabledBinding(for template: FileTemplate) -> Binding<Bool> {
        Binding(get: { model.settings.templates.first { $0.id == template.id }?.isEnabled ?? false }, set: { value in
            if let index = model.settings.templates.firstIndex(where: { $0.id == template.id }) {
                model.settings.templates[index].isEnabled = value
            }
        })
    }

    private func move(_ template: FileTemplate, by offset: Int) {
        guard let index = model.settings.templates.firstIndex(where: { $0.id == template.id }) else { return }
        let target = index + offset
        guard model.settings.templates.indices.contains(target) else { return }
        model.settings.templates.swapAt(index, target)
    }
}

struct FileBadge: View {
    let template: FileTemplate

    var body: some View {
        Image(systemName: template.iconName)
            .font(.system(size: 21, weight: .regular))
            .foregroundStyle(Theme.color(for: template.fileExtension))
            .frame(width: 28, height: 30)
            .accessibilityHidden(true)
    }
}

struct TemplateEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State var template: FileTemplate
    var onSave: (FileTemplate) -> Void

    private var valid: Bool {
        !template.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !template.fileExtension.isEmpty &&
        template.fileExtension.range(of: "^[A-Za-z0-9][A-Za-z0-9._-]{0,31}$", options: .regularExpression) != nil &&
        !template.fileExtension.contains("..") && !template.fileExtension.hasSuffix(".") &&
        template.content.utf8.count <= 1_048_576
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(template.name.isEmpty ? "添加文件模板" : "编辑文件模板")
                .font(.system(size: 17, weight: .semibold))
            Form {
                TextField("模板名称：", text: $template.name, prompt: Text("例如：会议记录"))
                TextField("扩展名：", text: $template.fileExtension, prompt: Text("md"))
                Toggle("显示在右键菜单", isOn: $template.isEnabled)
            }
            .textFieldStyle(.roundedBorder)
            VStack(alignment: .leading, spacing: 8) {
                Text("预设内容").font(.system(size: 12, weight: .medium))
                TextEditor(text: $template.content)
                    .font(.system(size: 12, design: .monospaced))
                    .padding(6).frame(height: 210)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.line))
                    .accessibilityLabel("模板预设内容")
                Text("可用变量：{{date}} 日期、{{datetime}} 时间、{{filename}} 文件名。留空可创建空白文件。")
                    .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Spacer()
                Button("取消") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("保存") {
                    template.name = template.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    onSave(template)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction).disabled(!valid)
            }
        }
        .padding(24).frame(width: 500).background(Theme.canvas)
    }
}
