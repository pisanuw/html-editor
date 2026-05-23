import SwiftUI

/// A small sheet for jumping to a specific line number in the editor.
struct GoToLineView: View {
    @EnvironmentObject var textViewStore: TextViewStore
    @Binding var isPresented: Bool

    @State private var lineText = ""
    @State private var errorMessage = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 16) {
            Text("Go to Line")
                .font(.headline)

            VStack(alignment: .leading, spacing: 4) {
                TextField("Line number", text: $lineText)
                    .textFieldStyle(.roundedBorder)
                    .focused($focused)
                    .onSubmit { commit() }
                    .frame(width: 200)

                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }

            HStack(spacing: 12) {
                Button("Cancel") { isPresented = false }
                    .keyboardShortcut(.cancelAction)
                Button("Go") { commit() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .onAppear { focused = true }
    }

    private func commit() {
        let trimmed = lineText.trimmingCharacters(in: .whitespaces)
        guard let line = Int(trimmed), line >= 1 else {
            errorMessage = "Enter a positive integer."
            return
        }
        textViewStore.goToLine(line)
        isPresented = false
    }
}
