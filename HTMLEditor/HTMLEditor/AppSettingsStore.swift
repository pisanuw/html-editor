import SwiftUI
import Combine

/// Persists `EditorSettings` to `UserDefaults` and publishes changes. When the
/// settings change it pushes the active palette into `EditorTheme` so the
/// highlighter picks up the new colors.
final class AppSettingsStore: ObservableObject {
    @Published var settings: EditorSettings { didSet { apply() } }
    @Published var showMinimap: Bool = true

    private let key = "HTMLEditor.settings"

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let restored = EditorSettings.decoded(from: data) {
            settings = restored
        } else {
            settings = .default
        }
        EditorTheme.current = ThemeLibrary.palette(named: settings.themeName)
        EditorTheme.fontSize = CGFloat(settings.fontSize)
    }

    var palette: ThemePalette { ThemeLibrary.palette(named: settings.themeName) }

    private func apply() {
        EditorTheme.current = palette
        EditorTheme.fontSize = CGFloat(settings.fontSize)
        if let data = settings.encoded() {
            UserDefaults.standard.set(data, forKey: key)
        }
        // Tell open editors to restyle / re-measure.
        NotificationCenter.default.post(name: .editorSettingsChanged, object: nil)
    }
}

extension Notification.Name {
    static let editorSettingsChanged = Notification.Name("HTMLEditor.editorSettingsChanged")
}
