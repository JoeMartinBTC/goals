import CoreGraphics
import Foundation

public enum CardSize: String, CaseIterable, Identifiable {
    case small, medium, large, xlarge
    public var id: String { rawValue }

    public var width: CGFloat {
        switch self {
        case .small: return 360
        case .medium: return 480
        case .large: return 640
        case .xlarge: return 900
        }
    }

    public var title: String {
        switch self {
        case .small: return "Klein"
        case .medium: return "Mittel"
        case .large: return "Groß"
        case .xlarge: return "Sehr groß"
        }
    }
}

/// Einstellungen außer den Kartentexten, dauerhaft in UserDefaults.
public final class GoalSettings: ObservableObject {
    public static let displayOptions = [5, 10, 15, 30]
    public static let intervalOptions = [1, 15, 30, 60, 120, 240]
    public static let maxIntervalMinutes = 24 * 60

    private let defaults: UserDefaults
    public var onChange: (() -> Void)?

    @Published public var size: CardSize {
        didSet { defaults.set(size.rawValue, forKey: "size"); onChange?() }
    }
    @Published public var displaySeconds: Int {
        didSet {
            guard Self.displayOptions.contains(displaySeconds) else { displaySeconds = oldValue; return }
            defaults.set(displaySeconds, forKey: "displaySeconds")
            onChange?()
        }
    }
    @Published public var intervalMinutes: Int {
        didSet {
            let clamped = min(max(intervalMinutes, 1), Self.maxIntervalMinutes)
            guard clamped == intervalMinutes else { intervalMinutes = clamped; return }
            defaults.set(intervalMinutes, forKey: "intervalMinutes")
            onChange?()
        }
    }
    @Published public var jitter: Bool {
        didSet { defaults.set(jitter, forKey: "jitter"); onChange?() }
    }
    @Published public var colorMode: ColorMode {
        didSet { defaults.set(colorMode.rawValue, forKey: "colorMode"); onChange?() }
    }
    @Published public var scheme: ColorSchemeKind {
        didSet { defaults.set(scheme.rawValue, forKey: "scheme"); onChange?() }
    }
    /// Versatz der Kartengruppe gegenüber der Mitte des Hauptbildschirms.
    @Published public var positionOffset: CGSize {
        didSet {
            defaults.set(Double(positionOffset.width), forKey: "positionX")
            defaults.set(Double(positionOffset.height), forKey: "positionY")
        }
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        size = CardSize(rawValue: defaults.string(forKey: "size") ?? "") ?? .medium
        let display = defaults.integer(forKey: "displaySeconds")
        displaySeconds = Self.displayOptions.contains(display) ? display : 15
        let interval = defaults.integer(forKey: "intervalMinutes")
        intervalMinutes = (1...Self.maxIntervalMinutes).contains(interval) ? interval : 60
        jitter = defaults.bool(forKey: "jitter")
        colorMode = ColorMode(rawValue: defaults.string(forKey: "colorMode") ?? "") ?? .mono
        scheme = ColorSchemeKind(rawValue: defaults.string(forKey: "scheme") ?? "") ?? .metall
        positionOffset = CGSize(width: defaults.double(forKey: "positionX"), height: defaults.double(forKey: "positionY"))
    }

    public var usesCustomColors: Bool { colorMode == .color && scheme == .eigene }
}
