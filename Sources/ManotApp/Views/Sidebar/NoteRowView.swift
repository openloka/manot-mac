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
        HStack(spacing: 10) {
            // Indentation
            Spacer().frame(width: INDENT * CGFloat(depth))

            // Note icon
            Image(systemName: "doc.plaintext.fill")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(isSelected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.tertiary))
                .frame(width: 14)

            VStack(alignment: .leading, spacing: 3) {
                Text(note.title.isEmpty ? "Untitled" : note.title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .foregroundStyle(isSelected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.primary))

                HStack(spacing: 6) {
                    Text(formattedDate)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)

                    if !note.contentPreview.isEmpty {
                        Text("•")
                            .font(.system(size: 9, weight: .black))
                            .foregroundStyle(.tertiary)
                        Text(note.contentPreview)
                            .font(.system(size: 11, weight: .regular, design: .rounded))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background {
            if isSelected {
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
