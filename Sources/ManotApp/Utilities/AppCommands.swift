import SwiftUI
import SwiftData

/// App-level menu commands (File menu additions)
struct AppCommands: Commands {
    var body: some Commands {
        CommandGroup(after: .newItem) {
            Divider()
            Button("Export as Markdown…") {
                // Handled via EditorView toolbar
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])
        }
    }
}
