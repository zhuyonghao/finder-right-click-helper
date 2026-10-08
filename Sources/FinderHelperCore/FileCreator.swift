import Foundation

public enum FileCreationError: LocalizedError, Equatable {
    case invalidName
    case invalidExtension
    case invalidDirectory
    case nameTooLong
    case tooManyCollisions

    public var errorDescription: String? {
        switch self {
        case .invalidName: return "请输入有效的文件名，不能包含斜杠、冒号或控制字符。"
        case .invalidExtension: return "扩展名只能包含字母、数字、下划线、连字符和分隔用的点。"
        case .invalidDirectory: return "目标必须是本机上已存在的文件夹。"
        case .nameTooLong: return "文件名过长，请缩短后重试。"
        case .tooManyCollisions: return "同名文件过多，请换一个文件名。"
        }
    }
}

public enum FileCreator {
    public static func create(template: FileTemplate, named name: String, in directory: URL) throws -> URL {
        guard LocalFileURL.isValid(directory) else { throw FileCreationError.invalidDirectory }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw FileCreationError.invalidDirectory
        }

        guard !name.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains),
              !name.contains("/"), !name.contains("\\"), !name.contains(":"),
              !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw FileCreationError.invalidName
        }
        let cleanName = name.trimmingCharacters(in: .whitespaces)
        guard cleanName != ".", cleanName != ".." else { throw FileCreationError.invalidName }
        let fileExtension = try validatedExtension(template.fileExtension)
        let suffix = fileExtension.isEmpty ? "" : "." + fileExtension
        let stem = !suffix.isEmpty && cleanName.lowercased().hasSuffix(suffix.lowercased())
            ? String(cleanName.dropLast(suffix.count)) : cleanName
        guard !stem.isEmpty, stem != ".", stem != ".." else { throw FileCreationError.invalidName }

        let now = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.calendar = Calendar(identifier: .gregorian)
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: now)
        let dateTimeString = ISO8601DateFormatter().string(from: now)

        for index in 0..<10_000 {
            let candidate = stem + (index == 0 ? "" : " \(index + 1)") + suffix
            guard candidate.utf8.count <= 255 else { throw FileCreationError.nameTooLong }
            let target = directory.appendingPathComponent(candidate, isDirectory: false)
            // Render in one pass so a placeholder-looking filename remains literal.
            let content = render(template.content, values: [
                "{{date}}": dateString,
                "{{datetime}}": dateTimeString,
                "{{filename}}": candidate
            ])
            do {
                // O_EXCL semantics avoid both overwrites and a check-then-write race.
                try Data(content.utf8).write(to: target, options: .withoutOverwriting)
                return target
            } catch {
                let nsError = error as NSError
                if (nsError.domain == NSCocoaErrorDomain && nsError.code == CocoaError.fileWriteFileExists.rawValue)
                    || (nsError.domain == NSPOSIXErrorDomain && nsError.code == 17) {
                    continue
                }
                throw error
            }
        }
        throw FileCreationError.tooManyCollisions
    }

    private static func validatedExtension(_ value: String) throws -> String {
        guard !value.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains) else {
            throw FileCreationError.invalidExtension
        }
        var fileExtension = value.trimmingCharacters(in: .whitespaces)
        if fileExtension.hasPrefix(".") { fileExtension.removeFirst() }
        guard !fileExtension.isEmpty || value.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw FileCreationError.invalidExtension
        }
        if fileExtension.isEmpty { return "" }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-")
        guard fileExtension.utf8.count <= 64,
              fileExtension.split(separator: ".", omittingEmptySubsequences: false).allSatisfy({
                  !$0.isEmpty && $0.unicodeScalars.allSatisfy(allowed.contains)
              }) else {
            throw FileCreationError.invalidExtension
        }
        return fileExtension
    }

    private static func render(_ template: String, values: [String: String]) -> String {
        let expression = try! NSRegularExpression(pattern: #"\{\{(?:date|datetime|filename)\}\}"#)
        let source = template as NSString
        let matches = expression.matches(in: template, range: NSRange(location: 0, length: source.length))
        let output = NSMutableString(string: template)
        for match in matches.reversed() {
            let token = source.substring(with: match.range)
            output.replaceCharacters(in: match.range, with: values[token] ?? token)
        }
        return output as String
    }
}

enum LocalFileURL {
    static func isValid(_ url: URL) -> Bool {
        guard url.isFileURL,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == "file",
              components.host == nil || components.host == "" || components.host == "localhost",
              components.user == nil, components.password == nil, components.port == nil,
              components.query == nil, components.fragment == nil,
              components.path.hasPrefix("/"),
              !components.path.unicodeScalars.contains(where: { $0.value == 0 }),
              !components.path.split(separator: "/", omittingEmptySubsequences: false).contains(where: { $0 == "." || $0 == ".." }) else {
            return false
        }
        return true
    }
}
