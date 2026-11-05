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

/// Einstellungen nur im Speicher, für Tests und Prüfmodi. Eine echte Ablage ließe eine Datei in den Preferences liegen,
/// denn cfprefsd schreibt verzögert, auch noch nach dem Löschen. So entsteht gar keine Datei, und die echten Einstellungen bleiben unberührt.
public final class MemoryDefaults: UserDefaults {
    private var values: [String: Any] = [:]

    public init() {
        super.init(suiteName: "goals-im-speicher")!
    }

    public override func object(forKey defaultName: String) -> Any? { values[defaultName] }
    public override func string(forKey defaultName: String) -> String? { values[defaultName] as? String }
    public override func integer(forKey defaultName: String) -> Int { values[defaultName] as? Int ?? 0 }
    public override func bool(forKey defaultName: String) -> Bool { values[defaultName] as? Bool ?? false }
    public override func double(forKey defaultName: String) -> Double { values[defaultName] as? Double ?? 0 }
    public override func set(_ value: Any?, forKey defaultName: String) { values[defaultName] = value }
    public override func set(_ value: Int, forKey defaultName: String) { values[defaultName] = value }
    public override func set(_ value: Bool, forKey defaultName: String) { values[defaultName] = value }
    public override func set(_ value: Double, forKey defaultName: String) { values[defaultName] = value }
    public override func removeObject(forKey defaultName: String) { values[defaultName] = nil }
}

/// Einstellungen außer den Zielanzeigentexten, dauerhaft in UserDefaults.
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
    /// Versatz der Zielanzeigengruppe gegenüber der Mitte des Hauptbildschirms.
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
