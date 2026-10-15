import AppKit
import SwiftUI
import FinderHelperCore

@MainActor
final class FileCreationPanel: NSObject, NSWindowDelegate, ObservableObject {
    let template: FileTemplate
    let directory: URL

    @Published var name = "未命名" {
        didSet {
            if name != oldValue, errorMessage != nil {
                errorMessage = nil
                DispatchQueue.main.async { [weak self] in
                    self?.resizeToFit()
                }
            }
        }
    }
    @Published private(set) var errorMessage: String?

    private let panel: NSPanel
    private var createdURL: URL?
    private var isRunning = false

    init(template: FileTemplate, directory: URL) {
        self.template = template
        self.directory = directory
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 250),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        super.init()
        panel.title = "新建文件"
        panel.identifier = NSUserInterfaceItemIdentifier("fileCreation")
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = false
        panel.level = .modalPanel
        panel.tabbingMode = .disallowed
        panel.delegate = self
    }

    var canCreate: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var extensionLabel: String {
        var value = template.fileExtension.trimmingCharacters(in: .whitespaces)
        if value.hasPrefix(".") { value.removeFirst() }
        return value.isEmpty ? "" : "." + value
    }

    var folderName: String {
        FileManager.default.displayName(atPath: directory.path)
    }

    var showsExtensionSuffix: Bool {
        !extensionLabel.isEmpty &&
        !name.trimmingCharacters(in: .whitespaces).lowercased().hasSuffix(extensionLabel.lowercased())
    }

    func runModal() -> URL? {
        createdURL = nil
        isRunning = true
        panel.contentView = NSHostingView(rootView: FileCreationView(controller: self))
        resizeToFit()
        panel.center()
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)

        defer {
            isRunning = false
            panel.orderOut(nil)
            // The hosted view observes this controller; release it after the modal session.
            panel.contentView = nil
            panel.close()
        }

        NSApp.runModal(for: panel)
        return createdURL
    }

    fileprivate func create() {
        guard isRunning, canCreate else { return }
        do {
            let url = try FileCreator.create(template: template, named: name, in: directory)
            finish(with: url)
        } catch {
            errorMessage = error.localizedDescription
            // Fit multiline errors without moving the dialog's top edge.
            DispatchQueue.main.async { [weak self] in
                self?.resizeToFit()
            }
        }
    }

    fileprivate func cancel() {
        finish(with: nil)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        cancel()
        return true
    }

    private func finish(with url: URL?) {
        guard isRunning else { return }
        createdURL = url
        isRunning = false
        NSApp.stopModal(withCode: url == nil ? .cancel : .OK)
        panel.orderOut(nil)
    }

    private func resizeToFit() {
        guard let contentView = panel.contentView else { return }
        contentView.layoutSubtreeIfNeeded()
        let size = contentView.fittingSize
        guard size.height > 0 else { return }
        let top = panel.frame.maxY
        panel.setContentSize(NSSize(width: 440, height: ceil(size.height)))
        if panel.isVisible {
            panel.setFrameOrigin(NSPoint(x: panel.frame.minX, y: top - panel.frame.height))
        }
    }
}

private struct FileCreationView: View {
    @ObservedObject var controller: FileCreationPanel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                FileBadge(template: controller.template)
                    .frame(width: 38, height: 38)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 3) {
                    Text("新建\(controller.template.name)")
                        .font(.system(size: 15, weight: .semibold))
                    Text("输入名称，文件将保存到当前文件夹。")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text("名称：")
                        .frame(width: 44, alignment: .trailing)
                    FilenameTextField(
                        text: $controller.name,
                        onSubmit: controller.create,
                        onCancel: controller.cancel
                    )
                    .frame(height: 24)
                    .accessibilityLabel("文件名称")
                    if controller.showsExtensionSuffix {
                        Text(controller.extensionLabel)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: 96, alignment: .leading)
                            .fixedSize(horizontal: true, vertical: false)
                            .help("文件扩展名由模板决定：\(controller.extensionLabel)")
                    }
                }

                HStack(alignment: .top, spacing: 8) {
                    Text("位置：")
                        .frame(width: 44, alignment: .trailing)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Image(systemName: "folder")
                                .foregroundStyle(.secondary)
                            Text(controller.folderName)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer(minLength: 0)
                        }
                        Text(controller.directory.path)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .help(controller.directory.path)
                    .accessibilityLabel("保存位置：\(controller.directory.path)")
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("同名文件会自动添加序号。")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    if let error = controller.errorMessage {
                        Label(error, systemImage: "exclamationmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityLabel("创建失败：\(error)")
                    }
                }
                .padding(.leading, 52)
            }

            HStack(spacing: 8) {
                Spacer()
                ModalActionButton(title: "取消", isDefault: false, action: controller.cancel)
                    .frame(width: 72, height: 24)
                ModalActionButton(
                    title: "创建",
                    isDefault: true,
                    isEnabled: controller.canCreate,
                    action: controller.create
                )
                .frame(width: 72, height: 24)
            }
        }
        .font(.system(size: 13))
        .padding(24)
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private struct ModalActionButton: NSViewRepresentable {
    let title: String
    let isDefault: Bool
    var isEnabled = true
    var action: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }

    func makeNSView(context: Context) -> ModalNSButton {
        let button = ModalNSButton(title: title, target: context.coordinator, action: #selector(Coordinator.performAction(_:)))
        button.setButtonType(.momentaryPushIn)
        button.bezelStyle = .rounded
        button.controlSize = .regular
        button.font = .systemFont(ofSize: NSFont.systemFontSize)
        button.isDefaultAction = isDefault
        button.keyEquivalent = isDefault ? "\r" : "\u{1b}"
        button.keyEquivalentModifierMask = []
        button.isEnabled = isEnabled
        button.setAccessibilityLabel(title)
        return button
    }

    func updateNSView(_ nsView: ModalNSButton, context: Context) {
        context.coordinator.action = action
        nsView.title = title
        nsView.isEnabled = isEnabled
        nsView.installDefaultButtonIfNeeded()
    }

    final class Coordinator: NSObject {
        var action: () -> Void

        init(action: @escaping () -> Void) {
            self.action = action
        }

        @objc func performAction(_ sender: NSButton) {
            guard sender.isEnabled else { return }
            action()
        }
    }
}

private final class ModalNSButton: NSButton {
    var isDefaultAction = false

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        installDefaultButtonIfNeeded()
    }

    func installDefaultButtonIfNeeded() {
        guard isDefaultAction, let window, let buttonCell = cell as? NSButtonCell else { return }
        // Establish the default cell before first display rather than relying on
        // SwiftUI's modal keyboard shortcut bridge to update the native button.
        window.defaultButtonCell = buttonCell
        needsDisplay = true
    }
}

private struct FilenameTextField: NSViewRepresentable {
    @Binding var text: String
    var onSubmit: () -> Void
    var onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> InitialSelectionTextField {
        let field = InitialSelectionTextField(string: text)
        field.delegate = context.coordinator
        field.font = .systemFont(ofSize: NSFont.systemFontSize)
        field.bezelStyle = .roundedBezel
        field.isBezeled = true
        field.isEditable = true
        field.isSelectable = true
        field.usesSingleLineMode = true
        field.cell?.isScrollable = true
        field.setAccessibilityLabel("文件名称")
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return field
    }

    func updateNSView(_ nsView: InitialSelectionTextField, context: Context) {
        context.coordinator.parent = self
        if nsView.stringValue != text { nsView.stringValue = text }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: FilenameTextField

        init(_ parent: FilenameTextField) {
            self.parent = parent
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            parent.text = field.stringValue
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            // Let the input method finish or cancel marked Chinese text first.
            if textView.hasMarkedText() { return false }
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onSubmit()
                return true
            }
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                parent.onCancel()
                return true
            }
            return false
        }
    }
}

private final class InitialSelectionTextField: NSTextField {
    private var didSelectInitialName = false

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window, !didSelectInitialName else { return }
        DispatchQueue.main.async { [weak self, weak window] in
            guard let self, let window, self.window === window, !self.didSelectInitialName else { return }
            window.makeFirstResponder(self)
            self.selectText(nil)
            // NSText uses UTF-16 ranges, including for Chinese file names.
            self.currentEditor()?.selectedRange = NSRange(location: 0, length: (self.stringValue as NSString).length)
            self.didSelectInitialName = true
        }
    }
}
