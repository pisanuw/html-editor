import Foundation

/// Preset widths for the preview pane's responsive / device-size toggle.
enum PreviewWidth: String, CaseIterable, Identifiable, Codable {
    case responsive
    case phone
    case tablet
    case desktop

    var id: String { rawValue }

    var label: String {
        switch self {
        case .responsive: return "Responsive"
        case .phone:      return "Phone"
        case .tablet:     return "Tablet"
        case .desktop:    return "Desktop"
        }
    }

    /// Fixed content width in points, or `nil` to fill the available space.
    var points: Double? {
        switch self {
        case .responsive: return nil
        case .phone:      return 390
        case .tablet:     return 768
        case .desktop:    return 1024
        }
    }
}
