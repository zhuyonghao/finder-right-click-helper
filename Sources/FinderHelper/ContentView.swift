import AppKit
import SwiftUI
import FinderHelperCore

enum Theme {
    static let accent = Color(red: 0.91, green: 0.38, blue: 0.19)
    static let ink = Color(red: 0.19, green: 0.22, blue: 0.25)
    static let muted = Color(red: 0.52, green: 0.54, blue: 0.57)
    static let canvas = Color(red: 0.975, green: 0.972, blue: 0.963)
    static let line = Color.black.opacity(0.065)
    static let green = Color(red: 0.22, green: 0.52, blue: 0.38)

    static func color(for ext: String) -> Color {
        switch ext.lowercased() {
        case "md": return Color(red: 0.35, green: 0.45, blue: 0.73)
        case "json", "yaml", "yml": return Color(red: 0.73, green: 0.52, blue: 0.20)
        case "html", "swift": return accent
        case "py": return Color(red: 0.29, green: 0.56, blue: 0.65)
        case "css": return Color(red: 0.58, green: 0.42, blue: 0.72)
        default: return green
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack(spacing: 0) {
            sidebar.frame(width: 208)
            Rectangle().fill(Theme.line).frame(width: 1)
            VStack(spacing: 0) {
                topbar
                HStack(alignment: .top, spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 26) {
                            if !model.extensionEnabled { activationBanner }
                            switch model.section {
                            case .files: TemplatesView()
                            case .applications: ApplicationsView()
                            case .menu: MenuSettingsView()
                            case .help: HelpView()
                            }
                        }
                        .padding(30)
                    }
                    if model.section != .help {
                        Rectangle().fill(Theme.line).frame(width: 1)
                        MenuPreview().frame(width: 254).padding(.horizontal, 20).padding(.top, 32)
                    }
                }
                footer
            }
            .background(Theme.canvas)
        }
        .foregroundStyle(Theme.ink)
        .alert("操作未完成", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button("好", role: .cancel) { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "") }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "cursorarrow.click.2")
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Theme.accent.gradient, in: RoundedRectangle(cornerRadius: 13))
                VStack(alignment: .leading, spacing: 4) {
                    Text("右键助手").font(.system(size: 18, weight: .bold))
                    Text("FINDER, SIMPLIFIED").font(.system(size: 7.5, weight: .semibold)).tracking(0.5).foregroundStyle(Theme.muted)
                }
            }
            .padding(.top, 49).padding(.bottom, 39).padding(.horizontal, 21)

            Text("工作空间").font(.system(size: 10, weight: .medium)).foregroundStyle(Theme.muted).padding(.leading, 26).padding(.bottom, 12)
            ForEach([AppSection.files, .applications, .menu]) { section in
                navigationRow(section)
            }
            Spacer()
            navigationRow(.help)
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 7) {
                    Circle().fill(model.extensionEnabled ? Theme.green : Theme.accent).frame(width: 6, height: 6)
                    Text(model.extensionEnabled ? "Finder 扩展已启用" : "Finder 扩展待启用")
                        .font(.system(size: 11, weight: .medium))
                }
                Text("右键的小事，交给助手。").font(.system(size: 10)).foregroundStyle(Theme.muted)
            }
            .padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.68), in: RoundedRectangle(cornerRadius: 10))
            .padding(16)
            HStack {
                Text("版本 \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.5")")
                Spacer()
                Text("为 macOS 而造")
            }.font(.system(size: 9)).foregroundStyle(Theme.muted).padding(.horizontal, 23).padding(.bottom, 20)
        }
        .background(Color(red: 0.946, green: 0.939, blue: 0.920))
    }

    private func navigationRow(_ section: AppSection) -> some View {
        Button { withAnimation(.easeInOut(duration: 0.15)) { model.section = section } } label: {
            HStack(spacing: 11) {
                Image(systemName: section.icon).font(.system(size: 15)).frame(width: 20)
                Text(section.rawValue).font(.system(size: 13, weight: model.section == section ? .semibold : .regular))
                Spacer()
                if section == .files {
                    Text("\(model.settings.templates.filter(\.isEnabled).count)")
                        .font(.system(size: 10, weight: .medium)).foregroundStyle(model.section == section ? Theme.accent : Theme.muted)
                }
            }
            .padding(.horizontal, 12).frame(height: 42)
            .foregroundStyle(model.section == section ? Theme.accent : Theme.ink.opacity(0.76))
            .background(model.section == section ? Color.white : .clear, in: RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain).padding(.horizontal, 13).padding(.bottom, 5)
    }

    private var topbar: some View {
        HStack(spacing: 7) {
            Image(systemName: "house").font(.system(size: 11))
            Text("工作空间")
            Image(systemName: "chevron.right").font(.system(size: 8, weight: .semibold)).padding(.horizontal, 4)
            Text(model.section.rawValue).foregroundStyle(Theme.ink)
            Spacer()
            Image(systemName: "checkmark.shield").font(.system(size: 11))
            Text("本地运行 · 无需联网").font(.system(size: 10))
        }
        .font(.system(size: 11)).foregroundStyle(Theme.muted)
        .padding(.horizontal, 30).frame(height: 61)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }
    }

    private var activationBanner: some View {
        HStack(alignment: .center, spacing: 11) {
            Image(systemName: "puzzlepiece.extension").font(.system(size: 20)).foregroundStyle(Theme.accent)
            VStack(alignment: .leading, spacing: 4) {
                Text("再一步，让右键更顺手").font(.system(size: 12, weight: .semibold))
                Text("在系统设置中开启 Finder 扩展。").font(.system(size: 10)).foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 4)
            Button("去开启", action: model.showExtensionSettings).buttonStyle(.plain)
                .font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.accent)
        }
        .padding(14).background(Theme.accent.opacity(0.065), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.accent.opacity(0.12)))
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Image(systemName: model.notice == nil ? "arrow.triangle.2.circlepath" : "checkmark.circle.fill")
                .foregroundStyle(model.notice == nil ? Theme.muted : Theme.green)
            Text(model.notice ?? "设置自动保存，菜单随你而变")
            Spacer()
            Text("⌘ ,  菜单设置")
        }
        .font(.system(size: 10)).foregroundStyle(Theme.muted)
        .padding(.horizontal, 30).frame(height: 37)
        .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
    }
}

struct PageHeading: View {
    var title: String
    var subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title).font(.system(size: 27, weight: .bold))
            Text(subtitle).font(.system(size: 12)).foregroundStyle(Theme.muted).lineSpacing(4)
        }
    }
}

struct AccentButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon).font(.system(size: 11, weight: .semibold))
                .padding(.horizontal, 13).frame(height: 33)
                .foregroundStyle(.white).background(Theme.accent, in: RoundedRectangle(cornerRadius: 7))
        }.buttonStyle(.plain)
    }
}

struct TemplatesView: View {
    @EnvironmentObject private var model: AppModel
    @State private var search = ""
    @State private var editing: FileTemplate?
    @State private var deleting: FileTemplate?

    private var filtered: [FileTemplate] {
        model.settings.templates.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) || $0.fileExtension.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            PageHeading(title: "从一个新文件开始。", subtitle: "告别先打开应用再保存。在 Finder 里，右键即刻创建。")
            HStack(spacing: 8) {
                AccentButton(title: "添加模板", icon: "plus") {
                    editing = FileTemplate(name: "", fileExtension: "txt", content: "", iconName: "doc.text")
                }
                Button(action: model.importTemplate) { Label("导入文件", systemImage: "square.and.arrow.down").font(.system(size: 11)) }
                    .buttonStyle(.bordered).controlSize(.large)
                Spacer(minLength: 0)
            }
            VStack(spacing: 14) {
                HStack {
                    Text("文件模板").font(.system(size: 13, weight: .semibold))
                    Text("\(model.settings.templates.count)").font(.system(size: 10, weight: .medium)).foregroundStyle(Theme.muted)
                        .padding(.horizontal, 7).padding(.vertical, 3).background(.black.opacity(0.04), in: Capsule())
                    Spacer()
                    HStack(spacing: 5) {
                        Image(systemName: "magnifyingglass").font(.system(size: 10))
                        TextField("搜索模板", text: $search).textFieldStyle(.plain).font(.system(size: 11)).frame(width: 95)
                    }.foregroundStyle(Theme.muted)
                }
                if filtered.isEmpty {
                    ContentUnavailableView(search.isEmpty ? "创建你的第一个模板" : "没有找到模板", systemImage: "doc.text.magnifyingglass", description: Text(search.isEmpty ? "添加空白模板，或从文本文件导入。" : "试试其他名称或扩展名。"))
                        .frame(minHeight: 170)
                } else {
                    VStack(spacing: 10) {
                        ForEach(filtered) { template in templateRow(template) }
                    }
                }
            }
            HStack(alignment: .top, spacing: 9) {
                Image(systemName: "lightbulb").foregroundStyle(Theme.accent)
                Text("不只是空白文件。为模板加入常用内容，下次创建时便能直接开始。")
                    .lineSpacing(4).foregroundStyle(Theme.muted)
            }.font(.system(size: 11)).padding(.top, 2)
        }
        .sheet(item: $editing) { template in TemplateEditor(template: template) { model.saveTemplate($0) } }
        .confirmationDialog("删除「\(deleting?.name ?? "")」模板？", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
            Button("删除模板", role: .destructive) {
                if let deleting { model.settings.templates.removeAll { $0.id == deleting.id } }
                deleting = nil
            }
        } message: { Text("已创建的文件不会受到影响。") }
    }

    private func templateRow(_ template: FileTemplate) -> some View {
        HStack(spacing: 13) {
            FileBadge(template: template)
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 7) {
                    Text(template.name).font(.system(size: 12, weight: .semibold))
                    Text(".\(template.fileExtension)").font(.system(size: 9, design: .monospaced)).foregroundStyle(Theme.muted)
                }
                Text(template.content.isEmpty ? "空白文件，更多可能" : "包含预设内容，开箱即用")
                    .font(.system(size: 10)).foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 2)
            Button { model.chooseDirectoryAndCreate(template) } label: { Image(systemName: "doc.badge.plus") }
                .buttonStyle(.plain).foregroundStyle(Theme.muted).help("选择文件夹并创建文件")
            Menu {
                Button("编辑模板") { editing = template }
                Button("上移") { move(template, by: -1) }.disabled(model.settings.templates.first?.id == template.id)
                Button("下移") { move(template, by: 1) }.disabled(model.settings.templates.last?.id == template.id)
                Divider()
                Button("删除模板", role: .destructive) { deleting = template }
            } label: { Image(systemName: "ellipsis").frame(width: 18) }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().foregroundStyle(Theme.muted)
            Toggle("启用\(template.name)", isOn: Binding(get: {
                model.settings.templates.first(where: { $0.id == template.id })?.isEnabled ?? false
            }, set: { value in
                if let index = model.settings.templates.firstIndex(where: { $0.id == template.id }) { model.settings.templates[index].isEnabled = value }
            })).labelsHidden().toggleStyle(.switch).controlSize(.mini).padding(.leading, 3)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(.white, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line))
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
        Image(systemName: template.iconName).font(.system(size: 20, weight: .regular))
            .foregroundStyle(Theme.color(for: template.fileExtension))
            .frame(width: 42, height: 46)
            .background(Theme.color(for: template.fileExtension).opacity(0.085), in: RoundedRectangle(cornerRadius: 8))
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
            HStack {
                Text(template.name.isEmpty ? "添加文件模板" : "编辑文件模板").font(.system(size: 21, weight: .bold))
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary) }.buttonStyle(.plain)
            }
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("模板名称").font(.system(size: 11, weight: .medium))
                    TextField("例如：会议记录", text: $template.name).textFieldStyle(.roundedBorder)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("扩展名（不含点）").font(.system(size: 11, weight: .medium))
                    TextField("md", text: $template.fileExtension).textFieldStyle(.roundedBorder)
                }.frame(width: 150)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("预设内容").font(.system(size: 11, weight: .medium))
                TextEditor(text: $template.content).font(.system(size: 12, design: .monospaced))
                    .padding(8).frame(height: 205)
                    .background(.white, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line))
                Text("支持 {{date}} 日期、{{datetime}} 时间与 {{filename}} 文件名；留空即创建空白文件。")
                    .font(.system(size: 10)).foregroundStyle(Theme.muted).lineSpacing(4)
            }
            HStack {
                Toggle("显示在右键菜单", isOn: $template.isEnabled).font(.system(size: 11))
                Spacer()
                Button("取消") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("保存模板") {
                    template.name = template.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    onSave(template)
                    dismiss()
                }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction).disabled(!valid)
            }
        }
        .padding(28).frame(width: 540).background(Theme.canvas).tint(Theme.accent)
    }
}
