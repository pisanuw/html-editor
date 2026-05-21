import SwiftUI

/// A simple manager for the snippet library: a list on the left, an editor on
/// the right. Edits bind straight into the store, which persists on change.
struct SnippetsView: View {
    @EnvironmentObject var store: SnippetStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedID: UUID?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                List(selection: $selectedID) {
                    ForEach(store.library.snippets) { snippet in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(snippet.name.isEmpty ? "Untitled" : snippet.name)
                                .fontWeight(.medium)
                            Text(snippet.trigger)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .tag(snippet.id)
                    }
                    .onDelete { store.remove(at: $0) }
                }
                .frame(width: 220)

                Divider()
                detail
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding()
            }

            Divider()
            HStack {
                Button {
                    store.add()
                    selectedID = store.library.snippets.last?.id
                } label: {
                    Label("Add", systemImage: "plus")
                }
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(8)
        }
        .frame(width: 660, height: 440)
    }

    @ViewBuilder
    private var detail: some View {
        if let id = selectedID,
           let index = store.library.snippets.firstIndex(where: { $0.id == id }) {
            let binding = Binding(
                get: { store.library.snippets[index] },
                set: { store.library.snippets[index] = $0 }
            )
            VStack(alignment: .leading, spacing: 10) {
                TextField("Name", text: binding.name)
                TextField("Trigger", text: binding.trigger)
                Text("Body")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextEditor(text: binding.body)
                    .font(.system(.body, design: .monospaced))
                    .border(Color(NSColor.separatorColor))
            }
        } else {
            Text("Select a snippet, or add a new one.")
                .foregroundColor(.secondary)
        }
    }
}
