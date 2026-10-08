import Foundation

public struct FileTemplate: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var fileExtension: String
    public var content: String
    public var iconName: String
    public var isEnabled: Bool

    public init(
        id: String = UUID().uuidString,
        name: String,
        fileExtension: String,
        content: String = "",
        iconName: String = "doc",
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.fileExtension = fileExtension
        self.content = content
        self.iconName = iconName
        self.isEnabled = isEnabled
    }

    public static let builtIns: [FileTemplate] = [
        FileTemplate(id: "text", name: "文本文档", fileExtension: "txt", iconName: "doc.text"),
        FileTemplate(id: "markdown", name: "Markdown", fileExtension: "md", content: "# {{filename}}\n\n", iconName: "text.alignleft"),
        FileTemplate(id: "json", name: "JSON", fileExtension: "json", content: "{\n  \n}\n", iconName: "curlybraces"),
        FileTemplate(id: "html", name: "HTML", fileExtension: "html", content: "<!DOCTYPE html>\n<html lang=\"zh-CN\">\n<head>\n  <meta charset=\"UTF-8\">\n  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">\n  <title>{{filename}}</title>\n</head>\n<body>\n  \n</body>\n</html>\n", iconName: "chevron.left.forwardslash.chevron.right"),
        FileTemplate(id: "python", name: "Python", fileExtension: "py", content: "#!/usr/bin/env python3\n# Created {{date}}\n\n", iconName: "terminal"),
        FileTemplate(id: "shell", name: "Shell 脚本", fileExtension: "sh", content: "#!/bin/zsh\n# Created {{date}}\n\n", iconName: "terminal", isEnabled: false),
        FileTemplate(id: "swift", name: "Swift", fileExtension: "swift", content: "import Foundation\n\n", iconName: "swift", isEnabled: false)
    ]
}

public struct CustomApplication: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var path: String
    public var isEnabled: Bool

    public init(id: String = UUID().uuidString, name: String, path: String, isEnabled: Bool = true) {
        self.id = id
        self.name = name
        self.path = path
        self.isEnabled = isEnabled
    }
}

public struct AppSettings: Codable, Equatable, Sendable {
    public var templates: [FileTemplate]
    public var applications: [CustomApplication]
    public var menuEnabled: Bool
    public var showCopyPath: Bool
    public var showOpenInTerminal: Bool
    public var terminalApplication: CustomApplication?
    public var revealAfterCreation: Bool
    public var monitoredFolders: [String]

    public init(
        templates: [FileTemplate] = FileTemplate.builtIns,
        applications: [CustomApplication] = [],
        menuEnabled: Bool = true,
        showCopyPath: Bool = true,
        showOpenInTerminal: Bool = true,
        terminalApplication: CustomApplication? = nil,
        revealAfterCreation: Bool = true,
        monitoredFolders: [String] = []
    ) {
        self.templates = templates
        self.applications = applications
        self.menuEnabled = menuEnabled
        self.showCopyPath = showCopyPath
        self.showOpenInTerminal = showOpenInTerminal
        self.terminalApplication = terminalApplication
        self.revealAfterCreation = revealAfterCreation
        self.monitoredFolders = monitoredFolders
    }

    public static let `default` = AppSettings()

    public var terminalName: String { terminalApplication?.name ?? "系统终端" }
    public var terminalMenuTitle: String {
        terminalApplication.map { "在 \($0.name) 中打开" } ?? "在终端中打开"
    }

    private enum CodingKeys: String, CodingKey {
        case templates, applications, menuEnabled, showCopyPath, showOpenInTerminal, terminalApplication, revealAfterCreation, monitoredFolders
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = Self.default
        templates = try container.decodeIfPresent([FileTemplate].self, forKey: .templates) ?? defaults.templates
        applications = try container.decodeIfPresent([CustomApplication].self, forKey: .applications) ?? defaults.applications
        menuEnabled = try container.decodeIfPresent(Bool.self, forKey: .menuEnabled) ?? defaults.menuEnabled
        showCopyPath = try container.decodeIfPresent(Bool.self, forKey: .showCopyPath) ?? defaults.showCopyPath
        showOpenInTerminal = try container.decodeIfPresent(Bool.self, forKey: .showOpenInTerminal) ?? defaults.showOpenInTerminal
        terminalApplication = try container.decodeIfPresent(CustomApplication.self, forKey: .terminalApplication)
        revealAfterCreation = try container.decodeIfPresent(Bool.self, forKey: .revealAfterCreation) ?? defaults.revealAfterCreation
        monitoredFolders = try container.decodeIfPresent([String].self, forKey: .monitoredFolders) ?? defaults.monitoredFolders
    }
}
