// One-time upgrade of this utility's own 1.0.0–1.0.2 settings.
// Compiled with FinderHelperCore by migrate-local-settings.sh.
import Foundation
import CoreFoundation

@main
enum MigrateLocalSettings {
    static func main() throws {
        let domain = "com.youjianzhushou.app"
        let key = ConfigurationStore.defaultsKey
        CFPreferencesSynchronize(domain as CFString, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        guard CFPreferencesCopyValue(key as CFString, domain as CFString,
                                     kCFPreferencesCurrentUser, kCFPreferencesAnyHost) == nil else {
            print("已有新版设置，未覆盖。")
            return
        }
        let legacy = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(
            "Library/Group Containers/group.com.youjianzhushou.shared/Library/Preferences/group.com.youjianzhushou.shared.plist")
        guard FileManager.default.fileExists(atPath: legacy.path) else {
            print("没有旧版设置需要迁移。")
            return
        }
        let plist = try PropertyListSerialization.propertyList(from: Data(contentsOf: legacy), format: nil) as? [String: Any]
        guard let data = plist?[key] as? Data else {
            print("旧版配置未包含设置，未作修改。")
            return
        }
        let settings = try JSONDecoder().decode(AppSettings.self, from: data)
        try ConfigurationStore(preferenceDomain: domain).save(settings)
        guard ConfigurationStore(preferenceDomain: domain).load() == settings else {
            throw ConfigurationStore.StorageError.synchronizationFailed
        }
        print("已保留 \(settings.templates.count) 个模板和 \(settings.applications.count) 个打开方式。旧配置保留不删除。")
    }
}
