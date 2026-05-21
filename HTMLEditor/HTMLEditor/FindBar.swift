import SwiftUI
import Combine

/// UI state for the find/replace bar. Search logic lives in `FindEngine`
/// (pure) and is applied to the live editor through `TextViewStore`.
final class FindState: ObservableObject {
    @Published var isVisible = false
    @Published var query = ""
    @Published var replacement = ""
    @Published var caseSensitive = false
    @Published var wholeWord = false
    @Published var useRegex = false
    @Published var status = ""
    @Published var showingResults = false

    var options: FindOptions {
        FindOptions(caseSensitive: caseSensitive, wholeWord: wholeWord, useRegex: useRegex)
    }

    func reset() {
        status = ""
    }
}

extension Notification.Name {
    /// Posted when the find query/options/visibility change so editors can
    /// refresh their "highlight every match" overlay.
    static let findHighlightChanged = Notification.Name("HTMLEditor.findHighlightChanged")
}

/// A find/replace bar shown above the editor. Mirrors familiar editor controls:
/// previous/next navigation, case/word/regex toggles, and replace actions.
struct FindBarView: View {
    @EnvironmentObject var findState: FindState
    @EnvironmentObject var textViewStore: TextViewStore
    @FocusState private var findFieldFocused: Bool

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                TextField("Find", text: $findState.query)
                    .textFieldStyle(.roundedBorder)
                    .focused($findFieldFocused)
                    .onSubmit { findNext() }
                    .onChange(of: findState.query) { _, _ in updateCount() }
                    .frame(minWidth: 160)

                toggle("Aa", help: "Case sensitive", isOn: $findState.caseSensitive)
                toggle("W", help: "Whole word", isOn: $findState.wholeWord)
                toggle(".*", help: "Regular expression", isOn: $findState.useRegex)

                Button(action: findPrevious) { Image(systemName: "chevron.up") }
                    .help("Previous match")
                Button(action: findNext) { Image(systemName: "chevron.down") }
                    .help("Next match")

                Button(action: { findState.showingResults = true }) {
                    Image(systemName: "list.bullet.rectangle")
                }
                .help("Find across all tabs")

                Text(findState.status)
                    .foregroundColor(.secondary)
                    .font(.system(size: 11))
                    .frame(minWidth: 90, alignment: .leading)

                Spacer()

                Button("Done") { close() }
                    .keyboardShortcut(.cancelAction)
            }

            HStack(spacing: 8) {
                TextField("Replace", text: $findState.replacement)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { replaceCurrent() }
                    .frame(minWidth: 160)

                Button("Replace", action: replaceCurrent)
                Button("Replace All", action: replaceAll)
                Spacer()
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(NSColor.windowBackgroundColor))
        .overlay(Divider(), alignment: .bottom)
        .onChange(of: findState.caseSensitive) { _, _ in updateCount() }
        .onChange(of: findState.wholeWord) { _, _ in updateCount() }
        .onChange(of: findState.useRegex) { _, _ in updateCount() }
        .onAppear { findFieldFocused = true }
    }

    private func toggle(_ label: String, help: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) { Text(label).font(.system(size: 11, design: .monospaced)) }
            .toggleStyle(.button)
            .help(help)
    }

    // MARK: - Actions

    private func findNext() {
        guard !findState.query.isEmpty else { findState.status = ""; return }
        report(textViewStore.find(findState.query, options: findState.options, forward: true))
    }

    private func findPrevious() {
        guard !findState.query.isEmpty else { findState.status = ""; return }
        report(textViewStore.find(findState.query, options: findState.options, forward: false))
    }

    private func replaceCurrent() {
        guard !findState.query.isEmpty else { return }
        report(textViewStore.replaceCurrentThenFind(findState.query,
                                                     with: findState.replacement,
                                                     options: findState.options))
    }

    private func replaceAll() {
        guard !findState.query.isEmpty else { return }
        let count = textViewStore.replaceAll(findState.query,
                                             with: findState.replacement,
                                             options: findState.options)
        findState.status = count == 0 ? "Not found" : "Replaced \(count)"
    }

    private func updateCount() {
        NotificationCenter.default.post(name: .findHighlightChanged, object: nil)
        guard !findState.query.isEmpty else { findState.status = ""; return }
        let total = textViewStore.count(of: findState.query, options: findState.options)
        findState.status = total == 0 ? "Not found" : "\(total) found"
    }

    private func report(_ result: (current: Int, total: Int)?) {
        if let result {
            findState.status = "\(result.current) of \(result.total)"
        } else {
            findState.status = "Not found"
        }
    }

    private func close() {
        findState.isVisible = false
        findState.reset()
        NotificationCenter.default.post(name: .findHighlightChanged, object: nil)
    }
}
