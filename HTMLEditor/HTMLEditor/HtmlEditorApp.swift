import SwiftUI

@main
struct HtmlEditorApp: App {
    @StateObject private var document = DocumentModel()
    @StateObject private var textViewStore = TextViewStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(document)
                .environmentObject(textViewStore)
                .frame(minWidth: 900, minHeight: 600)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New")       { document.newDocument()    }.keyboardShortcut("n")
                Button("Open…")     { document.openDocument()   }.keyboardShortcut("o")
                Divider()
                Button("Save")      { document.saveDocument()   }.keyboardShortcut("s")
                Button("Save As…")  { document.saveDocumentAs() }.keyboardShortcut("S")
            }
        }
    }
}
