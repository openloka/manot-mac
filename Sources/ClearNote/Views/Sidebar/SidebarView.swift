import SwiftUI
import SwiftData

struct SidebarView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(filter: #Predicate<Folder> { $0.parentFolder == nil }, sort: \.sortOrder)
    private var rootFolders: [Folder]

    @Query(filter: #Predicate<Note> { $0.folder == nil }, sort: \.updatedAt, order: .reverse)
    private var unfolderedNotes: [Note]

    @Binding var selectedNote: Note?
    @Binding var searchText: String

    @State private var renamingFolder: Folder?
    @State private var renamingFolderName = ""
    @State private var isCreatingFolder = false
    @State private var newFolderName = ""
    @FocusState private var folderFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Divider().opacity(0.5)

            if searchText.isEmpty {
                mainList
            } else {
                SearchResultsView(searchText: searchText, selectedNote: $selectedNote)
            }
        }
        .toolbar {
            sidebarToolbar
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.caption)
                .foregroundColor(.secondary)

            TextField("Search", text: $searchText)
                .textFieldStyle(.plain)
                .font(.callout)

            if !searchText.isEmpty {
                Button {
                    withAnimation(.easeOut(duration: 0.15)) { searchText = "" }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
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
                .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
        )
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
    }

    // MARK: - Main Folder / Note List

    private var mainList: some View {
        List(selection: $selectedNote) {
            // Inline new-folder creation row
            if isCreatingFolder {
                newFolderRow
            }

            // Root folders
            ForEach(rootFolders) { folder in
                FolderRowView(
                    folder: folder,
                    selectedNote: $selectedNote,
                    renamingFolder: $renamingFolder,
                    renamingFolderName: $renamingFolderName,
                    onDelete: { deleteFolder(folder) }
                )
            }

            // Unfiled notes at root level
            if !unfolderedNotes.isEmpty {
                Section {
                    ForEach(unfolderedNotes) { note in
                        NoteRowView(note: note)
                            .tag(note)
                            .contextMenu {
                                Button("Delete Note", role: .destructive) { deleteNote(note) }
                            }
                    }
                } header: {
                    Label("Unfiled", systemImage: "tray")
                        .font(.caption.uppercaseSmallCaps())
                        .foregroundColor(.secondary)
                }
            }

            // Empty state
            if rootFolders.isEmpty && unfolderedNotes.isEmpty {
                emptyListState
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private var newFolderRow: some View {
        HStack {
            Image(systemName: "folder.badge.plus")
                .foregroundColor(.accentColor)
            TextField("Folder name", text: $newFolderName)
                .focused($folderFieldFocused)
                .onSubmit { commitNewFolder() }
                .onExitCommand { cancelNewFolder() }
        }
        .listRowBackground(Color.accentColor.opacity(0.08))
    }

    @ViewBuilder
    private var emptyListState: some View {
        VStack(spacing: 10) {
            Image(systemName: "note.text.badge.plus")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
            Text("No notes yet")
                .font(.callout)
                .foregroundStyle(.secondary)
            Text("Press ⌘N to create your first note")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var sidebarToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            Button(action: { createNote(in: nil) }) {
                Image(systemName: "square.and.pencil")
            }
            .help("New Note (⌘N)")
            .keyboardShortcut("n", modifiers: .command)

            Button(action: startCreatingFolder) {
                Image(systemName: "folder.badge.plus")
            }
            .help("New Folder (⌘⇧N)")
            .keyboardShortcut("n", modifiers: [.command, .shift])
        }
    }

    // MARK: - Actions

    func createNote(in folder: Folder?) {
        let count = folder?.notes?.count ?? unfolderedNotes.count
        let note = Note(title: "Untitled", content: "", folder: folder, sortOrder: count)
        modelContext.insert(note)
        selectedNote = note
    }

    func startCreatingFolder() {
        newFolderName = ""
        withAnimation { isCreatingFolder = true }
        folderFieldFocused = true
    }

    func commitNewFolder() {
        let name = newFolderName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { cancelNewFolder(); return }
        let folder = Folder(name: name, sortOrder: rootFolders.count)
        modelContext.insert(folder)
        withAnimation { isCreatingFolder = false }
    }

    func cancelNewFolder() {
        withAnimation { isCreatingFolder = false }
    }

    func deleteFolder(_ folder: Folder) {
        if selectedNote?.folder?.id == folder.id { selectedNote = nil }
        modelContext.delete(folder)
    }

    func deleteNote(_ note: Note) {
        if selectedNote?.id == note.id { selectedNote = nil }
        modelContext.delete(note)
    }
}
