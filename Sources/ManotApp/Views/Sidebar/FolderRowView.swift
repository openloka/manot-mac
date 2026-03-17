import SwiftUI
import SwiftData

/// Renders a folder row + its children recursively.
/// Each nesting level adds `INDENT_STEP` points of leading padding.
struct FolderRowView: View {
    @Environment(\.modelContext) private var modelContext

    let folder: Folder
    @Binding var selectedNote: Note?
    @Binding var focusedFolder: Folder?
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
        VStack(alignment: .leading, spacing: 4) {
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
                        focusedFolder: $focusedFolder,
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
        HStack(spacing: 6) {
            // Indentation
            Spacer().frame(width: INDENT * CGFloat(depth))

            // Expand / collapse chevron
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { isExpanded.toggle() }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .frame(width: 14)
            }
            .buttonStyle(.plain)

            // Folder icon
            Image(systemName: "folder.fill")
                .foregroundColor(.accentColor)
                .font(.system(size: 14, weight: .medium))

            // Name or rename field
            if isRenaming {
                TextField("Folder name", text: $renamingText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .onSubmit { commitRename() }
                    .onExitCommand { isRenaming = false }
            } else {
                Text(folder.name)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .lineLimit(1)
            }

            Spacer()

            // Note count badge
            if let count = folder.notes?.count, count > 0 {
                Text("\(count)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.primary.opacity(0.06), in: Capsule())
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background {
            if isDropTargeted || focusedFolder?.id == folder.id {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.05), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
            } else {
                Color.clear
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            focusedFolder = folder
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { isExpanded.toggle() }
        }
        .contextMenu {
            Button("New Note in \"\(folder.name)\"") {
                // Focus this folder for tracking
                focusedFolder = folder
                startCreatingNote() 
            }
            Button("New Subfolder") {
                focusedFolder = folder
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

