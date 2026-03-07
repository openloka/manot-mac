import SwiftData
import Foundation

@Model
final class Folder {
    var id: UUID = UUID()
    var name: String = ""
    var createdAt: Date = Date()
    var sortOrder: Int = 0

    // Relationships
    @Relationship(deleteRule: .nullify, inverse: \Folder.parentFolder)
    var subfolders: [Folder]? = []

    var parentFolder: Folder?

    @Relationship(deleteRule: .cascade, inverse: \Note.folder)
    var notes: [Note]? = []

    init(name: String, parentFolder: Folder? = nil, sortOrder: Int = 0) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
        self.sortOrder = sortOrder
        self.parentFolder = parentFolder
        self.subfolders = []
        self.notes = []
    }

    var sortedSubfolders: [Folder] {
        subfolders?.sorted { $0.sortOrder < $1.sortOrder } ?? []
    }

    var sortedNotes: [Note] {
        notes?.sorted { $0.sortOrder < $1.sortOrder } ?? []
    }
}
