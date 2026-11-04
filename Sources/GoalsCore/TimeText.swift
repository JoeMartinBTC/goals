import Foundation

/// Zeitangaben für Menü und Einstellungen.
public enum TimeText {
    /// „15 Min.“, „1 Std.“, „1 Std. 30 Min.“
    public static func minutes(_ value: Int) -> String {
        let hours = value / 60
        let rest = value % 60
        if hours == 0 { return "\(rest) Min." }
        return rest == 0 ? "\(hours) Std." : "\(hours) Std. \(rest) Min."
    }

    /// Restzeit, auf die angefangene Minute aufgerundet.
    public static func remaining(seconds: TimeInterval) -> String {
        minutes(max(Int((seconds / 60).rounded(.up)), 1))
    }
}
