import Foundation

/// Finder sends back a copied menu item; only its integer tag identifies the
/// captured request. Keep recent menus independent so a second menu cannot
/// replace the context of an earlier one.
public final class MenuActionRegistry {
    private struct Entry {
        let request: ActionRequest
        let createdAt: Date
    }
    private var entries: [Int: Entry] = [:]
    private var nextTag = 1
    private let capacity: Int
    private let lifetime: TimeInterval
    private let lock = NSLock()

    public init(capacity: Int = 4096, lifetime: TimeInterval = 900) {
        precondition(capacity > 0 && lifetime > 0)
        self.capacity = capacity
        self.lifetime = lifetime
    }

    public func register(_ request: ActionRequest, now: Date = Date()) -> Int {
        lock.lock()
        defer { lock.unlock() }
        entries = entries.filter { now.timeIntervalSince($0.value.createdAt) < lifetime }
        if entries.count >= capacity, let oldest = entries.keys.min() {
            entries.removeValue(forKey: oldest)
        }
        let tag = nextTag
        nextTag += 1
        entries[tag] = Entry(request: request, createdAt: now)
        return tag
    }

    public func request(for tag: Int, now: Date = Date()) -> ActionRequest? {
        lock.lock()
        defer { lock.unlock() }
        guard let entry = entries[tag] else { return nil }
        guard now.timeIntervalSince(entry.createdAt) < lifetime else {
            entries.removeValue(forKey: tag)
            return nil
        }
        return entry.request
    }
}
