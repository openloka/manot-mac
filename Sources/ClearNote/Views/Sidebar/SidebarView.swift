import SwiftUI
import SwiftData

struct SidebarView: View {
    @Environment(\.modelContext) private var modelContext

    // Root-level folders only (no parent)
    @Query(filter: #Predicate<Folder> { $0.parentFolder == nil }, sort: \.sortOrder)
    private var rootFolders: [Folder]

    // Root-level notes only (no folder)
    @Query(filter: #Predicate<Note> { $0.folder == nil }, sort: \.sortOrder)
    private var rootNotes: [Note]

    @Binding var selectedNote: Note?
    @Binding var searchText: String

    @State private var isCreatingRootFolder = false
    @State private var newRootFolderName = ""

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Divider().opacity(0.4)

            if searchText.isEmpty {
                treeView
            } else {
                SearchResultsView(searchText: searchText, selectedNote: $selectedNote)
            }
        }
        .toolbar { sidebarToolbar }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("Search", text: $searchText)
                .textFieldStyle(.plain)
                .font(.callout)

            if !searchText.isEmpty {
                Button {
                    withAnimation(.easeOut(duration: 0.15)) { searchText = "" }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
    }

    // MARK: - Tree View

    private var treeView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 1) {

                // ── Inline new-root-folder row ──
                if isCreatingRootFolder {
                    NewItemRow(placeholder: "Folder name", text: $newRootFolderName) {
                        commitRootFolder()
                    } onCancel: {
                        isCreatingRootFolder = false
                    }
                    .padding(.horizontal, 8)
                }

                // ── Root folders ──
                ForEach(rootFolders) { folder in
                    FolderRowView(
                        folder: folder,
                        selectedNote: $selectedNote,
                        depth: 0
                    )
                }

                // ── Root notes ──
                ForEach(rootNotes) { note in
                    NoteRowView(
                        note: note,
                        selectedNote: $selectedNote,
                        depth: 0
                    ) {
                        deleteNote(note)
                    }
                    .padding(.horizontal, 8)
                }

                // ── Bottom root-level drop zone ──
                rootDropZone

                // ── Empty state ──
                if rootFolders.isEmpty && rootNotes.isEmpty && !isCreatingRootFolder {
                    emptyState
                }
            }
            .padding(.vertical, 6)
        }
        .scrollContentBackground(.hidden)
        .background(.ultraThinMaterial)
    }

    // Transparent drop zone at the bottom to move notes back to root level
    @ViewBuilder
    private var rootDropZone: some View {
        Color.clear
            .frame(maxWidth: .infinity, minHeight: 80)
            .dropDestination(for: NoteTransferable.self) { items, _ in
                guard let item = items.first else { return false }
                moveNote(id: item.id, toFolder: nil)
                return true
            }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "note.text.badge.plus")
                .font(.system(size: 30))
                .foregroundStyle(.tertiary)
            Text("No notes yet")
                .font(.callout)
                .foregroundStyle(.secondary)
            Text("Press ⌘N to create a note")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var sidebarToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            Button { createNote(in: nil) } label: {
                Image(systemName: "square.and.pencil")
            }
            .help("New Note (⌘N)")
            .keyboardShortcut("n", modifiers: .command)

            Button { startCreatingRootFolder() } label: {
                Image(systemName: "folder.badge.plus")
            }
            .help("New Folder (⌘⇧N)")
            .keyboardShortcut("n", modifiers: [.command, .shift])
        }
    }

    // MARK: - Actions

    func createNote(in folder: Folder?) {
        let note = Note(title: "Untitled", content: "", folder: folder, sortOrder: 0)
        modelContext.insert(note)
        selectedNote = note
    }

    func startCreatingRootFolder() {
        newRootFolderName = ""
        isCreatingRootFolder = true
    }

    func commitRootFolder() {
        let name = newRootFolderName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { isCreatingRootFolder = false; return }
        let folder = Folder(name: name, parentFolder: nil, sortOrder: rootFolders.count)
        modelContext.insert(folder)
        isCreatingRootFolder = false
    }

    func deleteNote(_ note: Note) {
        if selectedNote?.id == note.id { selectedNote = nil }
        modelContext.delete(note)
    }

    func moveNote(id: UUID, toFolder folder: Folder?) {
        let descriptor = FetchDescriptor<Note>(predicate: #Predicate { $0.id == id })
        if let note = try? modelContext.fetch(descriptor).first {
            note.folder = folder
        }
    }
}
