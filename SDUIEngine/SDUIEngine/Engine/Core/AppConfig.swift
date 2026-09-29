import Foundation

/// Hardcoded-дефолты глобальных переменных приложения.
/// Значения задаются здесь, НЕ в настройках Xcode.
/// Рантайм-переопределение — через GlobalVariablesStore (сервис).
enum AppConfig {
    static let baseURL = "http://192.168.2.104:8023/ords/yakiev"
    static let userID  = "demo_user"

    /// Дефолтные глобальные переменные (имя без @ -> значение).
    static let defaults: [String: String] = [
        "BASE_URL": baseURL,
        "USERID":   userID,
        // будущие: "ORGID", "SESSIONID", ...
    ]
}
