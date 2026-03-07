import SwiftUI

/// Codable transferable used to drag notes between folders
struct NoteTransferable: Transferable, Codable, Sendable {
    let id: UUID

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .data)
    }
}
