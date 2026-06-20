//
//  AppSettings.swift
//  Orbit Tasks
//  Global user settings (local-only) persisted to UserDefaults.
//  Uses HexColor helpers (no Color(hex:) extension to avoid ambiguity).
//
//  Swift 6 • iOS 17+
//

import SwiftUI
import Combine

@MainActor
final class AppSettings: ObservableObject {

    // MARK: - Types

    enum Appearance: String, CaseIterable, Identifiable {
        case system, light, dark
        var id: String { rawValue }

        var label: String {
            switch self {
            case .system: return "System"
            case .light: return "Light"
            case .dark: return "Dark"
            }
        }

        var colorScheme: ColorScheme? {
            switch self {
            case .system: return nil
            case .light: return .light
            case .dark: return .dark
            }
        }
    }

    enum TextSize: String, CaseIterable, Identifiable {
        case xSmall, small, medium, large, xLarge, xxLarge, accessibility1, accessibility2
        var id: String { rawValue }

        var label: String {
            switch self {
            case .xSmall: return "Extra Small"
            case .small: return "Small"
            case .medium: return "Medium"
            case .large: return "Large"
            case .xLarge: return "Extra Large"
            case .xxLarge: return "XX Large"
            case .accessibility1: return "Accessibility 1"
            case .accessibility2: return "Accessibility 2"
            }
        }

        var dynamicTypeSize: DynamicTypeSize {
            switch self {
            case .xSmall: return .xSmall
            case .small: return .small
            case .medium: return .medium
            case .large: return .large
            case .xLarge: return .xLarge
            case .xxLarge: return .xxLarge
            case .accessibility1: return .accessibility1
            case .accessibility2: return .accessibility2
            }
        }
    }

    enum Palette: String, CaseIterable, Identifiable {
        case nebula, aurora, solar, graphite, rose
        var id: String { rawValue }

        var label: String {
            switch self {
            case .nebula: return "Nebula"
            case .aurora: return "Aurora"
            case .solar: return "Solar"
            case .graphite: return "Graphite"
            case .rose: return "Rose"
            }
        }

        // Hex strings (#RRGGBB)
        var accentHex: String {
            switch self {
            case .nebula: return "#7C5CFF"
            case .aurora: return "#22C55E"
            case .solar: return "#F97316"
            case .graphite: return "#A3A3A3"
            case .rose: return "#FB7185"
            }
        }

        var backgroundTopHex: String {
            switch self {
            case .nebula: return "#0B1020"
            case .aurora: return "#071A12"
            case .solar: return "#140B08"
            case .graphite: return "#0B0B0D"
            case .rose: return "#160A10"
            }
        }

        var backgroundBottomHex: String {
            switch self {
            case .nebula: return "#24114A"
            case .aurora: return "#0A2A22"
            case .solar: return "#3A1210"
            case .graphite: return "#151518"
            case .rose: return "#3B0D23"
            }
        }
    }

    // MARK: - Keys

    private enum Keys {
        static let appearance = "orbit.appearance"
        static let textSize = "orbit.textSize"
        static let palette = "orbit.palette"

        static let use24HourTime = "orbit.use24HourTime"
        static let hapticsEnabled = "orbit.hapticsEnabled"
        static let themedBackground = "orbit.themedBackground"

        static let useCustomAccent = "orbit.useCustomAccent"
        static let customAccentHex = "orbit.customAccentHex"
    }

    // MARK: - Storage

    private let defaults: UserDefaults
    private var isLoading: Bool = true

    // MARK: - Published values (defaults first for definite initialization)

    @Published var appearance: Appearance = .system {
        didSet {
            guard !isLoading else { return }
            defaults.set(appearance.rawValue, forKey: Keys.appearance)
        }
    }

    @Published var textSize: TextSize = .medium {
        didSet {
            guard !isLoading else { return }
            defaults.set(textSize.rawValue, forKey: Keys.textSize)
        }
    }

    @Published var palette: Palette = .nebula {
        didSet {
            guard !isLoading else { return }
            defaults.set(palette.rawValue, forKey: Keys.palette)

            // Keep customAccentHex aligned with palette when custom accent is OFF.
            if !useCustomAccent {
                // Setting customAccentHex will persist via its didSet
                customAccentHex = palette.accentHex
            }
        }
    }

    @Published var use24HourTime: Bool = DateHelpers.localePrefers24HourTime() {
        didSet {
            guard !isLoading else { return }
            defaults.set(use24HourTime, forKey: Keys.use24HourTime)
        }
    }

    @Published var hapticsEnabled: Bool = true {
        didSet {
            guard !isLoading else { return }
            defaults.set(hapticsEnabled, forKey: Keys.hapticsEnabled)
        }
    }

    @Published var themedBackground: Bool = true {
        didSet {
            guard !isLoading else { return }
            defaults.set(themedBackground, forKey: Keys.themedBackground)
        }
    }

    @Published var useCustomAccent: Bool = false {
        didSet {
            guard !isLoading else { return }
            defaults.set(useCustomAccent, forKey: Keys.useCustomAccent)

            if !useCustomAccent {
                customAccentHex = palette.accentHex
            }
        }
    }

    @Published var customAccentHex: String = Palette.nebula.accentHex {
        didSet {
            guard !isLoading else { return }
            defaults.set(customAccentHex, forKey: Keys.customAccentHex)
        }
    }

    // MARK: - Derived

    var preferredColorScheme: ColorScheme? { appearance.colorScheme }
    var dynamicTypeSize: DynamicTypeSize { textSize.dynamicTypeSize }

    var accentColor: Color {
        if useCustomAccent, let c = HexColor.color(customAccentHex) {
            return c
        }
        return HexColor.color(palette.accentHex) ?? .accentColor
    }

    var backgroundGradient: LinearGradient {
        let top = HexColor.color(palette.backgroundTopHex) ?? Color.black
        let bottom = HexColor.color(palette.backgroundBottomHex) ?? Color.black
        return LinearGradient(colors: [top, bottom], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    // MARK: - Init

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.isLoading = true

        // Pull persisted values (if any)
        if let raw = defaults.string(forKey: Keys.appearance),
           let v = Appearance(rawValue: raw) {
            appearance = v
        }

        if let raw = defaults.string(forKey: Keys.textSize),
           let v = TextSize(rawValue: raw) {
            textSize = v
        }

        if let raw = defaults.string(forKey: Keys.palette),
           let v = Palette(rawValue: raw) {
            palette = v
        }

        use24HourTime = defaults.object(forKey: Keys.use24HourTime) as? Bool ?? use24HourTime
        hapticsEnabled = defaults.object(forKey: Keys.hapticsEnabled) as? Bool ?? hapticsEnabled
        themedBackground = defaults.object(forKey: Keys.themedBackground) as? Bool ?? themedBackground

        useCustomAccent = defaults.object(forKey: Keys.useCustomAccent) as? Bool ?? useCustomAccent
        customAccentHex = defaults.string(forKey: Keys.customAccentHex) ?? customAccentHex

        // Normalize for consistency:
        if !useCustomAccent {
            customAccentHex = palette.accentHex
        }

        self.isLoading = false
    }

    // MARK: - Actions

    func resetToDefaults() {
        appearance = .system
        textSize = .medium
        palette = .nebula

        use24HourTime = DateHelpers.localePrefers24HourTime()
        hapticsEnabled = true
        themedBackground = true

        useCustomAccent = false
        customAccentHex = Palette.nebula.accentHex
    }
}
