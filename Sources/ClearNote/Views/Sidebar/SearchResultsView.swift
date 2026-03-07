import SwiftUI
import SwiftData

struct SearchResultsView: View {
    @Environment(\.modelContext) private var modelContext
    let searchText: String
    @Binding var selectedNote: Note?

    @Query private var allNotes: [Note]

    init(searchText: String, selectedNote: Binding<Note?>) {
        self.searchText = searchText
        self._selectedNote = selectedNote
        // Fetch all notes – we'll filter in-view for simplicity
        self._allNotes = Query(sort: \.updatedAt, order: .reverse)
    }

    var filteredNotes: [Note] {
        let query = searchText.lowercased()
        return allNotes.filter {
            $0.title.lowercased().contains(query) ||
            $0.content.lowercased().contains(query)
        }
    }

    var body: some View {
        List(selection: $selectedNote) {
            if filteredNotes.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                ForEach(filteredNotes) { note in
                    NoteRowView(note: note)
                        .tag(note)
                }
            }
        }
        .listStyle(.sidebar)
    }
}
