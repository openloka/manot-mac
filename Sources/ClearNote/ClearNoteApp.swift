import SwiftUI
import SwiftData

@main
struct ClearNoteApp: App {
    let modelContainer: ModelContainer
    @StateObject private var themeManager = ThemeManager()

    init() {
        do {
            let schema = Schema([Note.self, Folder.self])
            // Note: Change to .automatic after adding the iCloud capability in Xcode
            let config = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none
            )
            modelContainer = try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 780, minHeight: 520)
                .environmentObject(themeManager)
                .preferredColorScheme(themeManager.current.colorScheme)
        }
        .modelContainer(modelContainer)
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            AppCommands()
        }
    }
}
