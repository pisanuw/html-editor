import Foundation

/// User-configurable editor settings. Pure model + JSON codec; the UI layer
/// persists it and applies the values to the text view and highlighter.
struct EditorSettings: Codable, Equatable {
    var indentWidth: Int
    var fontSize: Double
    var themeName: String
    var wordWrap: Bool
    var autoSave: Bool

    static let `default` = EditorSettings(
        indentWidth: 2, fontSize: 13,
        themeName: ThemeLibrary.defaultName,
        wordWrap: true, autoSave: false
    )

    /// Clamp values to sane ranges (used after decoding or editing).
    var sanitized: EditorSettings {
        EditorSettings(
            indentWidth: min(max(indentWidth, 1), 8),
            fontSize: min(max(fontSize, 9), 28),
            themeName: ThemeLibrary.palette(named: themeName).name,
            wordWrap: wordWrap,
            autoSave: autoSave
        )
    }

    func encoded() -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(self)
    }

    static func decoded(from data: Data) -> EditorSettings? {
        guard let s = try? JSONDecoder().decode(EditorSettings.self, from: data) else { return nil }
        return s.sanitized
    }
}
