import SwiftUI

/// Shows matches for the current find query across every open tab, grouped by
/// document. Selecting a result switches to that tab and selects the match.
struct FindResultsView: View {
    @EnvironmentObject var workspace: Workspace
    @EnvironmentObject var findState: FindState
    @EnvironmentObject var textViewStore: TextViewStore
    @Environment(\.dismiss) private var dismiss

    private struct DocResults: Identifiable {
        let id: UUID
        let title: String
        let hits: [MultiFileSearch.Hit]
    }

    private var results: [DocResults] {
        guard !findState.query.isEmpty else { return [] }
        return workspace.documents.compactMap { doc in
            let hits = MultiFileSearch.hits(in: doc.htmlText, query: findState.query, options: findState.options)
            return hits.isEmpty ? nil : DocResults(id: doc.id, title: doc.windowTitle, hits: hits)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(findState.query.isEmpty ? "Find across tabs" : "Results for “\(findState.query)”")
                    .font(.headline)
                Spacer()
                Text("\(totalCount) in \(results.count) file(s)")
                    .foregroundColor(.secondary)
                    .font(.system(size: 11))
            }
            .padding(10)
            Divider()

            if results.isEmpty {
                Spacer()
                Text(findState.query.isEmpty ? "Type a query in the find bar." : "No matches.")
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                List {
                    ForEach(results) { group in
                        Section(group.title) {
                            ForEach(Array(group.hits.enumerated()), id: \.offset) { _, hit in
                                Button {
                                    open(docID: group.id, range: hit.range)
                                } label: {
                                    HStack(spacing: 8) {
                                        Text("\(hit.line)")
                                            .foregroundColor(.secondary)
                                            .monospacedDigit()
                                            .frame(width: 40, alignment: .trailing)
                                        Text(hit.lineText)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }

            Divider()
            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(8)
        }
        .frame(width: 640, height: 460)
    }

    private var totalCount: Int { results.reduce(0) { $0 + $1.hits.count } }

    private func open(docID: UUID, range: NSRange) {
        workspace.focus(docID, selection: range)
        DispatchQueue.main.async { textViewStore.select(range) }
        dismiss()
    }
}
