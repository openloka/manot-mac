import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(filter: #Predicate<Folder> { $0.parentFolder == nil }, sort: \.sortOrder)
    private var rootFolders: [Folder]

    @Query(filter: #Predicate<Note> { $0.folder == nil }, sort: \.updatedAt, order: .reverse)
    private var unfolderedNotes: [Note]

    @State private var selectedNote: Note?
    @State private var searchText = ""
    @State private var columnVisibility = NavigationSplitViewVisibility.all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(
                selectedNote: $selectedNote,
                searchText: $searchText
            )
            .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
        } detail: {
            if let note = selectedNote {
                EditorView(note: note)
                    .id(note.id) // force reinit when selection changes
            } else {
                EmptyStateView()
            }
        }
        .navigationSplitViewStyle(.balanced)
        .onAppear {
            if selectedNote == nil {
                // Auto-select most recently modified note
                let allNotes = rootFolders.flatMap { $0.sortedNotes } + Array(unfolderedNotes)
                selectedNote = allNotes.sorted { $0.updatedAt > $1.updatedAt }.first
            }
        }
    }
}
