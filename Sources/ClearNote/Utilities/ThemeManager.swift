import SwiftUI
import Combine

/// Manages the app-wide appearance preference (light, dark, or system).
/// The selection is persisted in UserDefaults so it survives app restarts.
@MainActor
final class ThemeManager: ObservableObject {

    enum AppTheme: String, CaseIterable, Identifiable {
        case light  = "light"
        case dark   = "dark"

        var id: String { rawValue }

        var label: String {
            switch self {
            case .light:  return "Light"
            case .dark:   return "Dark"
            }
        }

        var iconName: String {
            switch self {
            case .light:  return "sun.max"
            case .dark:   return "moon"
            }
        }

        /// The SwiftUI `ColorScheme` value to pass to `.preferredColorScheme()`.
        var colorScheme: ColorScheme? {
            switch self {
            case .light:  return .light
            case .dark:   return .dark
            }
        }
    }

    private static let userDefaultsKey = "clearNoteAppTheme"

    @Published var current: AppTheme {
        didSet {
            UserDefaults.standard.set(current.rawValue, forKey: Self.userDefaultsKey)
            applyToNSApp()
        }
    }

    init() {
        let stored = UserDefaults.standard.string(forKey: Self.userDefaultsKey) ?? ""
        current = AppTheme(rawValue: stored) ?? .light
        applyToNSApp()
    }

    /// Cycle through Light ↔ Dark on each call.
    func cycle() {
        switch current {
        case .light:  current = .dark
        case .dark:   current = .light
        }
    }

    /// Explicitly sync the application and its windows to the current theme.
    /// This fixes the "mixed theme" bug where some views (like Sidebar) follow
    /// the system but others (like Detail view materials) get stuck in Light/Dark.
    func applyToNSApp() {
        let appearance: NSAppearance? = switch current {
        case .light:  NSAppearance(named: .aqua)
        case .dark:   NSAppearance(named: .darkAqua)
        }
        
        // Apply globally
        NSApp.appearance = appearance
        
        // Also force-update all windows to ensure materials (frosted glass) refresh
        for window in NSApp.windows {
            window.appearance = appearance
        }
    }
}
