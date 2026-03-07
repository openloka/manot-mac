import SwiftUI
import SwiftData

/// Renders a folder row + its children recursively.
/// Each nesting level adds `INDENT_STEP` points of leading padding.
struct FolderRowView: View {
    @Environment(\.modelContext) private var modelContext

    let folder: Folder
    @Binding var selectedNote: Note?
    let depth: Int

    @State private var isExpanded: Bool = true
    @State private var isRenaming: Bool = false
    @State private var renamingText: String = ""
    @State private var isDropTargeted: Bool = false

    // Inline child creation
    @State private var isCreatingNote: Bool = false
    @State private var isCreatingSubfolder: Bool = false
    @State private var newChildName: String = ""

    private let INDENT: CGFloat = 18

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            // ── Folder header row ──
            folderHeader

            // ── Children (shown when expanded) ──
            if isExpanded {
                // Inline new subfolder creation
                if isCreatingSubfolder {
                    NewItemRow(
                        placeholder: "Folder name",
                        text: $newChildName
                    ) { commitSubfolder() } onCancel: {
                        isCreatingSubfolder = false
                    }
                    .padding(.leading, INDENT * CGFloat(depth + 1) + 8)
                    .padding(.trailing, 8)
                }

                // Inline new note creation row
                if isCreatingNote {
                    NewItemRow(
                        placeholder: "Note title",
                        text: $newChildName,
                        icon: "doc.text"
                    ) { commitNote() } onCancel: {
                        isCreatingNote = false
                    }
                    .padding(.leading, INDENT * CGFloat(depth + 1) + 8)
                    .padding(.trailing, 8)
                }

                // Sub-folders (recursive)
                ForEach(folder.sortedSubfolders) { subfolder in
                    FolderRowView(
                        folder: subfolder,
                        selectedNote: $selectedNote,
                        depth: depth + 1
                    )
                }

                // Notes inside this folder
                ForEach(folder.sortedNotes) { note in
                    NoteRowView(
                        note: note,
                        selectedNote: $selectedNote,
                        depth: depth + 1
                    ) {
                        deleteNote(note)
                    }
                    .padding(.horizontal, 8)
                }
            }
        }
    }

    // MARK: - Folder Header Row

    private var folderHeader: some View {
        HStack(spacing: 4) {
            // Indentation
            Spacer().frame(width: INDENT * CGFloat(depth))

            // Expand / collapse chevron
            Button {
                withAnimation(.easeInOut(duration: 0.18)) { isExpanded.toggle() }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .frame(width: 14)
            }
            .buttonStyle(.plain)

            // Folder icon
            Image(systemName: "folder.fill")
                .foregroundColor(.accentColor)
                .font(.callout)

            // Name or rename field
            if isRenaming {
                TextField("Folder name", text: $renamingText)
                    .textFieldStyle(.plain)
                    .font(.callout.weight(.medium))
                    .onSubmit { commitRename() }
                    .onExitCommand { isRenaming = false }
            } else {
                Text(folder.name)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
            }

            Spacer()

            // Note count badge
            if let count = folder.notes?.count, count > 0 {
                Text("\(count)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.trailing, 4)
            }
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isDropTargeted ? Color.accentColor.opacity(0.14) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            NotificationCenter.default.post(name: .focusedFolderChanged, object: folder)
            withAnimation(.easeInOut(duration: 0.18)) { isExpanded.toggle() }
        }
        .contextMenu {
            Button("New Note in \"\(folder.name)\"") {
                // Focus this folder for tracking
                NotificationCenter.default.post(name: .focusedFolderChanged, object: folder)
                startCreatingNote() 
            }
            Button("New Subfolder") {
                NotificationCenter.default.post(name: .focusedFolderChanged, object: folder)
                startCreatingSubfolder()
            }
            Divider()
            Button("Rename") { startRenaming() }
            Divider()
            Button("Delete Folder", role: .destructive) { deleteFolder() }
        }
        .draggable(SidebarItemTransferable(id: folder.id, isFolder: true))
        .dropDestination(for: SidebarItemTransferable.self) { items, _ in
            guard let item = items.first else { return false }
            if item.isFolder {
                if item.id == folder.id { return false }
                moveFolder(id: item.id, toParent: folder)
            } else {
                moveNote(id: item.id, toFolder: folder)
            }
            return true
        } isTargeted: { targeted in
            withAnimation { isDropTargeted = targeted }
        }
    }

    // MARK: - Actions

    private func startCreatingNote() {
        newChildName = ""
        isCreatingNote = true
        if !isExpanded { withAnimation { isExpanded = true } }
    }

    private func commitNote() {
        let title = newChildName.trimmingCharacters(in: .whitespaces)
        let note = Note(
            title: title.isEmpty ? "Untitled" : title,
            content: "",
            folder: folder,
            sortOrder: folder.sortedNotes.count
        )
        modelContext.insert(note)
        selectedNote = note
        isCreatingNote = false
    }

    private func startCreatingSubfolder() {
        newChildName = ""
        isCreatingSubfolder = true
        if !isExpanded { withAnimation { isExpanded = true } }
    }

    private func commitSubfolder() {
        let name = newChildName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { isCreatingSubfolder = false; return }
        let subfolder = Folder(
            name: name,
            parentFolder: folder,
            sortOrder: folder.sortedSubfolders.count
        )
        modelContext.insert(subfolder)
        isCreatingSubfolder = false
    }

    private func startRenaming() {
        renamingText = folder.name
        isRenaming = true
    }

    private func commitRename() {
        let name = renamingText.trimmingCharacters(in: .whitespaces)
        if !name.isEmpty { folder.name = name }
        isRenaming = false
    }

    private func deleteFolder() {
        modelContext.delete(folder)
    }

    private func deleteNote(_ note: Note) {
        modelContext.delete(note)
    }

    private func moveNote(id: UUID, toFolder destination: Folder) {
        let descriptor = FetchDescriptor<Note>(predicate: #Predicate { $0.id == id })
        if let note = try? modelContext.fetch(descriptor).first {
            note.folder = destination
        }
    }

    private func moveFolder(id: UUID, toParent destination: Folder) {
        let descriptor = FetchDescriptor<Folder>(predicate: #Predicate { $0.id == id })
        if let movedFolder = try? modelContext.fetch(descriptor).first {
            // Prevent recursive cycles (cant move folder into its own subfolder)
            var current: Folder? = destination
            while let p = current {
                if p.id == movedFolder.id { return }
                current = p.parentFolder
            }
            movedFolder.parentFolder = destination
        }
    }
}

