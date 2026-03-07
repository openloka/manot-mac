import SwiftUI

/// Codable transferable used to drag items in the sidebar
struct SidebarItemTransferable: Transferable, Codable, Sendable {
    let id: UUID
    let isFolder: Bool

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .data)
    }
}
