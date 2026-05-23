import SwiftUI

/// A horizontal strip showing the HTML element ancestry at the cursor position,
/// e.g. html > body > div > p. Sits between the find bar and the editor pane.
struct BreadcrumbBarView: View {
    @ObservedObject var document: DocumentModel

    private var breadcrumbs: [String] {
        HTMLBreadcrumb.path(in: document.htmlText, at: document.cursorOffset)
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(Array(breadcrumbs.enumerated()), id: \.offset) { index, name in
                    if index > 0 {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)
                    }
                    Text(name)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(index == breadcrumbs.count - 1 ? .primary : .secondary)
                }
                if breadcrumbs.isEmpty {
                    Text("(document)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
        }
        .frame(height: 22)
        .background(Color(NSColor.windowBackgroundColor))
        .overlay(Divider(), alignment: .bottom)
    }
}
