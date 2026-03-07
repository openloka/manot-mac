import SwiftUI
import SwiftData

struct FolderRowView: View {
    @Environment(\.modelContext) private var modelContext
    let folder: Folder
    @Binding var selectedNote: Note?
    @Binding var renamingFolder: Folder?
    @Binding var renamingFolderName: String
    let onDelete: () -> Void

    @State private var isExpanded = true

    var isRenaming: Bool { renamingFolder?.id == folder.id }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            // Sub-folders
            ForEach(folder.sortedSubfolders) { subfolder in
                FolderRowView(
                    folder: subfolder,
                    selectedNote: $selectedNote,
                    renamingFolder: $renamingFolder,
                    renamingFolderName: $renamingFolderName,
                    onDelete: {
                        modelContext.delete(subfolder)
                    }
                )
            }
            // Notes in folder
            ForEach(folder.sortedNotes) { note in
                NoteRowView(note: note)
                    .tag(note)
                    .contextMenu {
                        Button("Delete Note", role: .destructive) {
                            if selectedNote?.id == note.id { selectedNote = nil }
                            modelContext.delete(note)
                        }
                    }
            }
        } label: {
            Label {
                if isRenaming {
                    TextField("Folder name", text: $renamingFolderName)
                        .onSubmit {
                            commitRename()
                        }
                        .onExitCommand {
                            renamingFolder = nil
                        }
                } else {
                    Text(folder.name)
                        .fontWeight(.medium)
                }
            } icon: {
                Image(systemName: isExpanded ? "folder.open" : "folder")
                    .foregroundColor(.accentColor)
            }
        }
        .contextMenu {
            Button("New Note in Folder") {
                createNote()
            }
            Button("New Subfolder") {
                createSubfolder()
            }
            Divider()
            Button("Rename") {
                startRename()
            }
            Divider()
            Button("Delete Folder", role: .destructive) {
                onDelete()
            }
        }
        .dropDestination(for: NoteTransferable.self) { items, _ in
            guard let transferable = items.first else { return false }
            moveNote(withID: transferable.id, toFolder: folder)
            return true
        }
    }

    // MARK: - Actions

    private func createNote() {
        let note = Note(
            title: "Untitled Note",
            content: "",
            folder: folder,
            sortOrder: folder.notes?.count ?? 0
        )
        modelContext.insert(note)
        selectedNote = note
    }

    private func createSubfolder() {
        let subfolder = Folder(
            name: "New Folder",
            parentFolder: folder,
            sortOrder: folder.subfolders?.count ?? 0
        )
        modelContext.insert(subfolder)
        isExpanded = true
        renamingFolderName = subfolder.name
        renamingFolder = subfolder
    }

    private func startRename() {
        renamingFolderName = folder.name
        renamingFolder = folder
    }

    private func commitRename() {
        let trimmed = renamingFolderName.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            folder.name = trimmed
        }
        renamingFolder = nil
    }

    private func moveNote(withID noteID: UUID, toFolder destination: Folder) {
        // Find the note in all folders and move it
        let descriptor = FetchDescriptor<Note>(predicate: #Predicate { $0.id == noteID })
        if let note = try? modelContext.fetch(descriptor).first {
            note.folder = destination
            note.sortOrder = destination.notes?.count ?? 0
        }
    }
}
