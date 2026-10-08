import Foundation
import CoreFoundation

public final class ConfigurationStore {
    public static let shared = ConfigurationStore()
    public static let configurationDidChange = Notification.Name("FinderHelperConfigurationDidChange")
    public static let defaultsKey = "FinderHelper.Settings.v1"

    private let defaults: UserDefaults?
    private let preferenceDomain: String?
    private let readOnly: Bool
    private let lock = NSLock()

    public enum StorageError: LocalizedError {
        case readOnly, synchronizationFailed

        public var errorDescription: String? {
            switch self {
            case .readOnly: return "Finder 扩展只能读取设置，请在右键助手主窗口修改。"
            case .synchronizationFailed: return "无法保存设置，请检查当前用户的配置目录权限。"
            }
        }
    }

    public init(defaults: UserDefaults? = nil, preferenceDomain: String? = nil, readOnly: Bool = false) {
        if let defaults {
            self.defaults = defaults
            self.preferenceDomain = nil
            self.readOnly = readOnly || (Bundle.main.object(forInfoDictionaryKey: "SharedPreferencesReadOnly") as? Bool == true)
        } else if let domain = preferenceDomain ?? (Bundle.main.object(forInfoDictionaryKey: "SharedPreferenceDomain") as? String), !domain.isEmpty {
            self.defaults = nil
            self.preferenceDomain = domain
            self.readOnly = readOnly || (Bundle.main.object(forInfoDictionaryKey: "SharedPreferencesReadOnly") as? Bool == true)
        } else {
            let group = Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String
            self.defaults = group.flatMap { $0.isEmpty ? nil : UserDefaults(suiteName: $0) } ?? .standard
            self.preferenceDomain = nil
            self.readOnly = readOnly || (Bundle.main.object(forInfoDictionaryKey: "SharedPreferencesReadOnly") as? Bool == true)
        }
    }

    public func load() -> AppSettings {
        lock.lock()
        defer { lock.unlock() }
        let data: Data?
        if let domain = preferenceDomain {
            // Explicit scope reads the host's domain, not the extension's container.
            CFPreferencesSynchronize(domain as CFString, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
            data = CFPreferencesCopyValue(Self.defaultsKey as CFString, domain as CFString,
                                          kCFPreferencesCurrentUser, kCFPreferencesAnyHost) as? Data
        } else {
            defaults?.synchronize()
            data = defaults?.data(forKey: Self.defaultsKey)
        }
        guard let data,
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return .default
        }
        return settings
    }

    public func save(_ settings: AppSettings) throws {
        guard !readOnly else { throw StorageError.readOnly }
        let data = try JSONEncoder().encode(settings)
        lock.lock()
        let synchronized: Bool
        if let domain = preferenceDomain {
            CFPreferencesSetValue(Self.defaultsKey as CFString, data as CFData, domain as CFString,
                                  kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
            synchronized = CFPreferencesSynchronize(domain as CFString, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        } else {
            defaults?.set(data, forKey: Self.defaultsKey)
            synchronized = defaults?.synchronize() ?? false
        }
        lock.unlock()
        guard synchronized else { throw StorageError.synchronizationFailed }
        NotificationCenter.default.post(name: Self.configurationDidChange, object: self)
        #if os(macOS)
        DistributedNotificationCenter.default().postNotificationName(
            Self.configurationDidChange, object: nil, userInfo: nil, deliverImmediately: true
        )
        #endif
    }
}
