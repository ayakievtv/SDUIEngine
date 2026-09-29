import Foundation

final class GlobalVariablesStore: @unchecked Sendable {
    static let shared = GlobalVariablesStore()

    private var storage: [String: String]
    private let lock = NSLock()

    /// @TOKEN: буква/подчёркивание, затем буквы/цифры/подчёркивания
    private static let tokenRegex = try! NSRegularExpression(pattern: "@[A-Za-z_][A-Za-z0-9_]*")

    init(defaults: [String: String] = AppConfig.defaults) {
        storage = Self.normalize(defaults)
    }

    func all() -> [String: String] {
        lock.lock(); defer { lock.unlock() }
        return storage
    }

    func set(_ value: String, for name: String) {
        lock.lock(); defer { lock.unlock() }
        storage[Self.token(name)] = value
    }

    func override(from dict: [String: String]) {
        lock.lock(); defer { lock.unlock() }
        for (key, value) in Self.normalize(dict) { storage[key] = value }
    }

    /// Подставляет значения вместо всех известных @TOKEN в строке.
    /// Неизвестные токены остаются как есть.
    func resolve(_ string: String) -> String {
        guard string.contains("@") else { return string }

        let snapshot = all()
        let ns = string as NSString
        var result = ""
        var last = 0

        for match in Self.tokenRegex.matches(in: string, range: NSRange(location: 0, length: ns.length)) {
            result += ns.substring(with: NSRange(location: last, length: match.range.location - last))
            let raw = ns.substring(with: match.range)
            result += snapshot[raw.uppercased()] ?? raw
            last = match.range.location + match.range.length
        }
        result += ns.substring(from: last)
        return result
    }

    private static func token(_ name: String) -> String {
        name.hasPrefix("@") ? name.uppercased() : "@\(name.uppercased())"
    }
    private static func normalize(_ dict: [String: String]) -> [String: String] {
        dict.reduce(into: [:]) { $0[token($1.key)] = $1.value }
    }
}
