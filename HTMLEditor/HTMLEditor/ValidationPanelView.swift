import SwiftUI

/// Sheet that presents the list of validation issues returned by HTMLValidator.
struct ValidationPanelView: View {
    let issues: [ValidationIssue]
    @Binding var isPresented: Bool

    var errorCount: Int { issues.filter { $0.severity == .error }.count }
    var warningCount: Int { issues.filter { $0.severity == .warning }.count }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("HTML Validation")
                    .font(.headline)
                Spacer()
                if !issues.isEmpty {
                    Text(summaryText)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Button("Close") { isPresented = false }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            if issues.isEmpty {
                Spacer()
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title2)
                    Text("No issues found")
                        .font(.body)
                }
                Spacer()
            } else {
                List(issues) { issue in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: issue.severity == .error
                              ? "xmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundColor(issue.severity == .error ? .red : .orange)
                            .frame(width: 16)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(issue.message)
                                .font(.system(size: 12))
                            Text("Line \(issue.line)")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .frame(width: 420, height: 360)
    }

    private var summaryText: String {
        var parts: [String] = []
        if errorCount > 0 { parts.append("\(errorCount) error\(errorCount == 1 ? "" : "s")") }
        if warningCount > 0 { parts.append("\(warningCount) warning\(warningCount == 1 ? "" : "s")") }
        return parts.joined(separator: ", ")
    }
}
