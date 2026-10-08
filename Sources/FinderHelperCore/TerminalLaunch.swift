import Foundation

/// Directory handoff only: never constructs a shell command from a file path.
public enum TerminalLaunch {
    public static func destination(bundleIdentifier: String?, directory: URL) throws -> URL {
        guard LocalFileURL.isValid(directory) else { throw ActionRequestError.invalidFileURL }
        switch bundleIdentifier {
        case "dev.warp.Warp-Stable", "dev.warp.Warp-Preview":
            var components = URLComponents()
            components.scheme = bundleIdentifier == "dev.warp.Warp-Preview" ? "warppreview" : "warp"
            components.host = "action"
            components.path = "/new_window"
            components.queryItems = [URLQueryItem(name: "path", value: directory.path)]
            guard let url = components.url else { throw ActionRequestError.invalidURL }
            return url
        default:
            // Terminal, Ghostty and iTerm2 handle folder URLs natively. Other
            // user-selected apps must also support receiving folders via macOS.
            return directory
        }
    }
}
