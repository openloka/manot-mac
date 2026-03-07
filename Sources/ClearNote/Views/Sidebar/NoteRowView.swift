import SwiftUI

struct NoteRowView: View {
    let note: Note

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(note.title.isEmpty ? "Untitled" : note.title)
                .font(.callout.weight(.medium))
                .lineLimit(1)
                .foregroundColor(.primary)

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
        .padding(.vertical, 4)
        .draggable(NoteTransferable(id: note.id))
    }

    private var formattedDate: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(note.updatedAt) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            formatter.dateStyle = .none
            return formatter.string(from: note.updatedAt)
        } else if calendar.isDateInYesterday(note.updatedAt) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .none
            return formatter.string(from: note.updatedAt)
        }
    }
}
