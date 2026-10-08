import Foundation

public enum ActionRequestError: LocalizedError, Equatable {
    case invalidURL
    case unknownAction
    case invalidParameters
    case invalidFileURL

    public var errorDescription: String? {
        switch self {
        case .invalidURL: return "无法识别此右键助手链接。"
        case .unknownAction: return "此链接包含不支持的操作。"
        case .invalidParameters: return "此操作缺少参数，或参数不符合要求。"
        case .invalidFileURL: return "此操作只能访问本机的有效文件路径。"
        }
    }
}

public enum ActionRequest: Equatable, Sendable {
    case create(templateID: String, directory: URL)
    case open(applicationID: String, files: [URL])
    case copyPaths(files: [URL])
    case openTerminal(directory: URL)
    case showSettings

    public func makeURL() throws -> URL {
        var components = URLComponents()
        components.scheme = "finderhelper"
        switch self {
        case let .create(templateID, directory):
            components.host = "create"
            components.queryItems = [URLQueryItem(name: "template", value: templateID), URLQueryItem(name: "directory", value: directory.absoluteString)]
        case let .open(applicationID, files):
            components.host = "open"
            components.queryItems = [URLQueryItem(name: "application", value: applicationID)] + files.map { URLQueryItem(name: "file", value: $0.absoluteString) }
        case let .copyPaths(files):
            components.host = "copy-paths"
            components.queryItems = files.map { URLQueryItem(name: "file", value: $0.absoluteString) }
        case let .openTerminal(directory):
            components.host = "terminal"
            components.queryItems = [URLQueryItem(name: "directory", value: directory.absoluteString)]
        case .showSettings:
            components.host = "settings"
        }
        guard let url = components.url else { throw ActionRequestError.invalidURL }
        _ = try Self(url: url)
        return url
    }

    public init(url: URL) throws {
        guard url.absoluteString.utf8.count <= 1_048_576,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == "finderhelper",
              components.user == nil, components.password == nil, components.port == nil,
              components.fragment == nil, components.path.isEmpty,
              let action = components.host else {
            throw ActionRequestError.invalidURL
        }
        let items = components.queryItems ?? []

        func validateKeys(_ allowed: Set<String>) throws {
            guard items.allSatisfy({ allowed.contains($0.name) && $0.value != nil }) else {
                throw ActionRequestError.invalidParameters
            }
        }
        func single(_ key: String) throws -> String {
            let matching = items.filter { $0.name == key }
            guard matching.count == 1, let value = matching.first?.value, !value.isEmpty else {
                throw ActionRequestError.invalidParameters
            }
            return value
        }
        func identifier(_ key: String) throws -> String {
            let value = try single(key)
            guard value.utf8.count <= 256,
                  !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !value.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains) else {
                throw ActionRequestError.invalidParameters
            }
            return value
        }
        func fileURL(_ value: String) throws -> URL {
            guard let file = URL(string: value), LocalFileURL.isValid(file) else {
                throw ActionRequestError.invalidFileURL
            }
            return file
        }
        func files() throws -> [URL] {
            let values = items.filter { $0.name == "file" }
            guard !values.isEmpty, values.count <= 1_024 else { throw ActionRequestError.invalidParameters }
            return try values.map {
                guard let value = $0.value else { throw ActionRequestError.invalidParameters }
                return try fileURL(value)
            }
        }

        switch action {
        case "create":
            try validateKeys(["template", "directory"])
            self = .create(templateID: try identifier("template"), directory: try fileURL(single("directory")))
        case "open":
            try validateKeys(["application", "file"])
            self = .open(applicationID: try identifier("application"), files: try files())
        case "copy-paths":
            try validateKeys(["file"])
            self = .copyPaths(files: try files())
        case "terminal":
            try validateKeys(["directory"])
            self = .openTerminal(directory: try fileURL(single("directory")))
        case "settings":
            guard components.query == nil else { throw ActionRequestError.invalidParameters }
            self = .showSettings
        default:
            throw ActionRequestError.unknownAction
        }
    }
}
