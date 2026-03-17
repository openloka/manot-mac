import SwiftUI

struct EmptyStateView: View {
    var body: some View {
        ZStack {
            // Subtle gradient background
            LinearGradient(
                colors: [
                    Color(.windowBackgroundColor),
                    Color(.windowBackgroundColor).opacity(0.95)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                // Icon
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 96, height: 96)
                        .shadow(color: .black.opacity(0.08), radius: 12, y: 4)

                    Image(systemName: "note.text")
                        .font(.system(size: 40, weight: .light))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.accentColor, .accentColor.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                VStack(spacing: 8) {
                    Text("No Note Selected")
                        .font(.title3.bold())
                        .foregroundColor(.primary.opacity(0.85))

                    Text("Select a note from the sidebar,\nor create a new one.")
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                }

                // Shortcut badges
                HStack(spacing: 16) {
                    shortcutBadge(key: "⌘N", label: "New Note", icon: "square.and.pencil")
                    shortcutBadge(key: "⌘⇧N", label: "New Folder", icon: "folder.badge.plus")
                }
                .padding(.top, 4)
            }
            .padding(40)
        }
    }

    @ViewBuilder
    private func shortcutBadge(key: String, label: String, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .light))
                .foregroundColor(.accentColor)

            Text(key)
                .font(.system(.caption, design: .monospaced).bold())
                .foregroundColor(.accentColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(Color.accentColor.opacity(0.1))
                        .overlay(Capsule().stroke(Color.accentColor.opacity(0.2), lineWidth: 0.5))
                )

            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}
