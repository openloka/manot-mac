import SwiftUI

/// Note row with manual selection highlight (no system blue).
struct NoteRowView: View {
    let note: Note
    @Binding var selectedNote: Note?
    var depth: Int = 0
    var onDelete: () -> Void

    private let INDENT: CGFloat = 18
    private var isSelected: Bool { selectedNote?.id == note.id }

    var body: some View {
        HStack(spacing: 6) {
            // Indentation
            Spacer().frame(width: INDENT * CGFloat(depth))

            // Note icon
            Image(systemName: "doc.text")
                .font(.caption)
                .foregroundColor(isSelected ? .accentColor : .secondary)
                .frame(width: 14)

            VStack(alignment: .leading, spacing: 2) {
                Text(note.title.isEmpty ? "Untitled" : note.title)
                    .font(.callout)
                    .lineLimit(1)
                    .foregroundStyle(.primary)

                HStack(spacing: 4) {
                    Text(formattedDate)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    if !note.contentPreview.isEmpty {
                        Text("·")
                            .font(.caption2)
                            .foregroundStyle(.quaternary)
                        Text(note.contentPreview)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isSelected
                      ? Color.accentColor.opacity(0.14)
                      : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            selectedNote = note
        }
        .contextMenu {
            Button("Delete Note", role: .destructive) { onDelete() }
        }
        .draggable(SidebarItemTransferable(id: note.id, isFolder: false))
    }

    // Smart date: today → time, yesterday → "Yesterday", else → short date
    private var formattedDate: String {
        let cal = Calendar.current
        if cal.isDateInToday(note.updatedAt) {
            let f = DateFormatter()
            f.dateStyle = .none
            f.timeStyle = .short
            return f.string(from: note.updatedAt)
        } else if cal.isDateInYesterday(note.updatedAt) {
            return "Yesterday"
        } else {
            let f = DateFormatter()
            f.dateStyle = .short
            f.timeStyle = .none
            return f.string(from: note.updatedAt)
        }
    }
}
