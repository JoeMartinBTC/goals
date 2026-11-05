import AppKit
import GoalsCore
import SwiftUI

@MainActor
final class SettingsNavigation: ObservableObject {
    enum Tab: Hashable { case cards, display }
    @Published var tab: Tab = .cards
}

struct SettingsRootView: View {
    @ObservedObject var store: GoalStore
    @ObservedObject var settings: GoalSettings
    @ObservedObject var engine: GoalsEngine
    @ObservedObject var autoStart: AutoStart
    @ObservedObject var navigation: SettingsNavigation

    var body: some View {
        VStack(spacing: 0) {
            if let error = store.loadError {
                Text("\(error) Änderungen werden nicht gespeichert, bis die Datei wieder lesbar ist.")
                    .font(.callout)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color(hex: 0xA32D2D))
            }
            if let error = store.saveError {
                Text("\(error) Deine letzten Eingaben stehen nur im Speicher.")
                    .font(.callout)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color(hex: 0xA32D2D))
            }
            Picker("Bereich", selection: $navigation.tab) {
                Text("Zielanzeigen").tag(SettingsNavigation.Tab.cards)
                Text("Anzeige").tag(SettingsNavigation.Tab.display)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 240)
            .padding(.vertical, 12)
            Divider()
            Group {
                switch navigation.tab {
                case .cards:
                    CardsTab(store: store, settings: settings)
                case .display:
                    DisplayTab(store: store, settings: settings, engine: engine, autoStart: autoStart)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            HStack {
                TimelineView(.everyMinute) { _ in
                    Text(engine.statusText).foregroundStyle(.secondary)
                }
                .id(engine.revision)
                Spacer()
                Button("Jetzt zeigen") { engine.showNow() }
                    .disabled(store.enabledCards.isEmpty)
                    .accessibilityIdentifier("btn.showNow")
            }
            .padding(12)
        }
    }
}

private struct CardsTab: View {
    @ObservedObject var store: GoalStore
    @ObservedObject var settings: GoalSettings
    @State private var selection: String?
    @State private var confirmDelete = false

    private var selected: GoalCard? { store.cards.first { $0.id == selection } }

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                List(selection: $selection) {
                    ForEach(store.cards) { card in
                        HStack(spacing: 8) {
                            Toggle("Zielanzeige einschalten", isOn: Binding(
                                get: { card.isEnabled },
                                set: { store.setEnabled(card.id, $0) }))
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .controlSize(.mini)
                            Text(card.title.isEmpty ? "Ohne Überschrift" : card.title)
                                .lineLimit(1)
                                .foregroundStyle(card.isEnabled ? .primary : .secondary)
                        }
                        .tag(card.id)
                    }
                    .onMove { store.move(from: $0, to: $1) }
                }
                .listStyle(.inset)
                Divider()
                HStack(spacing: 8) {
                    Button { selection = store.add().id } label: { Image(systemName: "plus") }
                        .help("Zielanzeige hinzufügen")
                        .accessibilityIdentifier("btn.addCard")
                    Button { confirmDelete = true } label: { Image(systemName: "minus") }
                        .help("Gewählte Zielanzeige löschen")
                        .disabled(selected == nil)
                        .accessibilityIdentifier("btn.removeCard")
                    Spacer()
                }
                .disabled(store.loadError != nil)
                .padding(8)
            }
            .frame(width: 270)
            Divider()
            if let card = selected {
                CardEditor(card: card, store: store, settings: settings)
                    .id(card.id)
            } else {
                Text("Links eine Zielanzeige wählen oder mit Plus eine neue anlegen.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear { selection = selection ?? store.cards.first?.id }
        .onChange(of: store.cards.map(\.id)) { _, ids in
            if let current = selection, !ids.contains(current) { selection = ids.first }
            if selection == nil { selection = ids.first }
        }
        .confirmationDialog("Zielanzeige „\(selected?.title ?? "")“ löschen?", isPresented: $confirmDelete) {
            Button("Löschen", role: .destructive) {
                if let id = selection { store.remove(id) }
            }
        }
    }
}

private struct CardEditor: View {
    let card: GoalCard
    @ObservedObject var store: GoalStore
    @ObservedObject var settings: GoalSettings

    private static let previewWidth: CGFloat = 520

    private func text(_ path: WritableKeyPath<GoalCard, String>) -> Binding<String> {
        Binding(
            get: { store.cards.first { $0.id == card.id }?[keyPath: path] ?? "" },
            set: { value in
                guard var current = store.cards.first(where: { $0.id == card.id }) else { return }
                current[keyPath: path] = value
                store.update(current)
            })
    }

    private func color(_ path: WritableKeyPath<CardColors, String>, fallback: UInt32) -> Binding<Color> {
        Binding(
            get: {
                let value = store.cards.first { $0.id == card.id }?.colors?[keyPath: path]
                return Color(hex: value.flatMap(Palettes.parseHex) ?? fallback)
            },
            set: { value in
                guard var current = store.cards.first(where: { $0.id == card.id }) else { return }
                var colors = current.colors ?? CardColors(background: Palettes.hexString(Palettes.mono.background),
                                                          title: Palettes.hexString(Palettes.mono.title),
                                                          text: Palettes.hexString(Palettes.mono.text))
                colors[keyPath: path] = value.hexText
                current.colors = colors
                store.update(current)
            })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                field("Überschrift") {
                    TextField("Überschrift", text: text(\.title)).labelsHidden()
                        .accessibilityIdentifier("field.title")
                }
                field("Unterüberschrift") {
                    TextField("Unterüberschrift", text: text(\.subtitle)).labelsHidden()
                        .accessibilityIdentifier("field.subtitle")
                }
                field("Erklärung") {
                    TextEditor(text: text(\.detail))
                        .font(.body)
                        .frame(height: 96)
                        .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Color.secondary.opacity(0.35)))
                        .accessibilityIdentifier("field.detail")
                }
                if settings.usesCustomColors {
                    HStack(spacing: 18) {
                        ColorPicker("Hintergrund", selection: color(\.background, fallback: Palettes.mono.background), supportsOpacity: false)
                        ColorPicker("Überschrift", selection: color(\.title, fallback: Palettes.mono.title), supportsOpacity: false)
                        ColorPicker("Text", selection: color(\.text, fallback: Palettes.mono.text), supportsOpacity: false)
                    }
                }
                field("Vorschau in der Größe „\(settings.size.title)“") { preview }
            }
            .disabled(store.loadError != nil)
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var preview: some View {
        let current = store.cards.first { $0.id == card.id } ?? card
        let index = store.enabledCards.firstIndex { $0.id == card.id } ?? 0
        let palette = Palettes.palette(index: index, mode: settings.colorMode, scheme: settings.scheme, custom: current.colors)
        let scale = min(1, Self.previewWidth / settings.size.width)
        let height = CardMeasure.height(of: current, size: settings.size)
        return GoalCardView(card: current, palette: palette, size: settings.size)
            .scaleEffect(scale, anchor: .topLeading)
            .frame(width: settings.size.width * scale, height: height * scale, alignment: .topLeading)
    }

    private func field<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.callout).foregroundStyle(.secondary)
            content()
        }
    }
}

private struct DisplayTab: View {
    @ObservedObject var store: GoalStore
    @ObservedObject var settings: GoalSettings
    @ObservedObject var engine: GoalsEngine
    @ObservedObject var autoStart: AutoStart
    @State private var customInterval = false

    private static let customTag = -1

    private var intervalSelection: Binding<Int> {
        Binding(
            get: {
                customInterval || !GoalSettings.intervalOptions.contains(settings.intervalMinutes)
                    ? Self.customTag : settings.intervalMinutes
            },
            set: { value in
                customInterval = value == Self.customTag
                if value != Self.customTag { settings.intervalMinutes = value }
            })
    }

    private var schemeSelection: Binding<ColorSchemeKind> {
        Binding(get: { settings.scheme }, set: {
            settings.scheme = $0
            settings.colorMode = .color
        })
    }

    private var modeSelection: Binding<ColorMode> {
        Binding(get: { settings.colorMode }, set: { settings.colorMode = $0 })
    }

    var body: some View {
        Form {
            Section("Zielanzeigen") {
                Picker("Größe", selection: $settings.size) {
                    ForEach(CardSize.allCases) { Text("\($0.title) · \(Int($0.width))").tag($0) }
                }
                .pickerStyle(.segmented)
                Picker("Anzeigedauer", selection: $settings.displaySeconds) {
                    ForEach(GoalSettings.displayOptions, id: \.self) { Text("\($0) s").tag($0) }
                }
                .pickerStyle(.segmented)
            }
            Section("Takt") {
                Picker("Alle", selection: intervalSelection) {
                    ForEach(GoalSettings.intervalOptions, id: \.self) { Text(TimeText.minutes($0)).tag($0) }
                    Text("Eigener Wert").tag(Self.customTag)
                }
                .pickerStyle(.segmented)
                if intervalSelection.wrappedValue == Self.customTag {
                    HStack {
                        TextField("Minuten", value: $settings.intervalMinutes, format: .number)
                            .frame(width: 80)
                            .accessibilityIdentifier("field.interval")
                        Stepper("Minuten", value: $settings.intervalMinutes, in: 1...GoalSettings.maxIntervalMinutes, step: 5)
                    }
                }
                Toggle("Takt streuen (± 20 %)", isOn: $settings.jitter)
            }
            Section("Farbe") {
                Picker("Modus", selection: modeSelection) {
                    ForEach(ColorMode.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                Picker("Schema", selection: schemeSelection) {
                    Section("Verlauf je Zielanzeige") {
                        ForEach(ColorSchemeKind.perCard) { Text($0.title).tag($0) }
                    }
                    Section("Verlauf über die ganze Fläche") {
                        ForEach(ColorSchemeKind.wholeArea) { Text($0.title).tag($0) }
                    }
                    Divider()
                    Text(ColorSchemeKind.eigene.title).tag(ColorSchemeKind.eigene)
                }
                .pickerStyle(.menu)
                if settings.usesCustomColors {
                    Text("Eigene Farben stellst du je Zielanzeige im Bereich „Zielanzeigen“ ein.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            Section("App") {
                Toggle("Beim Anmelden starten", isOn: Binding(get: { autoStart.isOn }, set: { autoStart.set($0) }))
                HStack {
                    Text("Position der Zielanzeigen")
                    Spacer()
                    Button("Zurück zur Mitte") { engine.resetPosition() }
                }
                HStack {
                    Text(store.fileURL.path)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button("Im Finder zeigen") { NSWorkspace.shared.activateFileViewerSelecting([store.fileURL]) }
                }
            }
        }
        .formStyle(.grouped)
    }
}

/// Einstellungsfenster, eines für die ganze App.
@MainActor
final class SettingsWindowController {
    let navigation = SettingsNavigation()
    private let content: () -> AnyView
    private var window: NSWindow?

    init(content: @escaping (SettingsNavigation) -> AnyView) {
        let navigation = navigation
        self.content = { content(navigation) }
    }

    func show(tab: SettingsNavigation.Tab = .cards) {
        navigation.tab = tab
        let w = window ?? makeWindow()
        window = w
        NSApp.activate(ignoringOtherApps: true)
        w.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 880, height: 680),
                         styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        w.title = "Goals"
        w.isReleasedWhenClosed = false
        w.minSize = NSSize(width: 760, height: 560)
        w.contentView = NSHostingView(rootView: content())
        if !w.setFrameUsingName("GoalsSettings") { w.center() }
        w.setFrameAutosaveName("GoalsSettings")
        return w
    }
}
