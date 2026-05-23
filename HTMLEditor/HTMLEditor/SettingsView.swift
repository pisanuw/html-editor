import SwiftUI

/// The app Settings panel: indent width, editor font size, and color theme.
/// Bindings write straight into the store, which persists and restyles editors.
struct SettingsView: View {
    @EnvironmentObject var store: AppSettingsStore

    var body: some View {
        Form {
            Picker("Theme", selection: themeBinding) {
                ForEach(ThemeLibrary.all) { palette in
                    Text(palette.name).tag(palette.name)
                }
            }

            Stepper(value: indentBinding, in: 1...8) {
                Text("Indent width: \(store.settings.indentWidth) spaces")
            }

            HStack {
                Text("Font size")
                Slider(value: fontBinding, in: 9...28, step: 1)
                Text("\(Int(store.settings.fontSize)) pt")
                    .monospacedDigit()
                    .frame(width: 44, alignment: .trailing)
            }

            Toggle("Word wrap", isOn: wordWrapBinding)
            Toggle("Auto-save (2 s after last edit)", isOn: autoSaveBinding)
        }
        .padding(20)
        .frame(width: 380)
    }

    private var themeBinding: Binding<String> {
        Binding(get: { store.settings.themeName },
                set: { store.settings.themeName = $0 })
    }
    private var indentBinding: Binding<Int> {
        Binding(get: { store.settings.indentWidth },
                set: { store.settings.indentWidth = $0 })
    }
    private var fontBinding: Binding<Double> {
        Binding(get: { store.settings.fontSize },
                set: { store.settings.fontSize = $0 })
    }
    private var wordWrapBinding: Binding<Bool> {
        Binding(get: { store.settings.wordWrap },
                set: { store.settings.wordWrap = $0 })
    }
    private var autoSaveBinding: Binding<Bool> {
        Binding(get: { store.settings.autoSave },
                set: { store.settings.autoSave = $0 })
    }
}
