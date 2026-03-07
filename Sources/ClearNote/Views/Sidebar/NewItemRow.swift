import SwiftUI

/// Reusable inline input row for creating new folders or notes.
struct NewItemRow: View {
    let placeholder: String
    @Binding var text: String
    var icon: String = "folder.fill"
    let onCommit: () -> Void
    let onCancel: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.callout)
                .foregroundStyle(Color.accentColor)
                .frame(width: 14)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.callout.weight(.medium))
                .focused($isFocused)
                .onSubmit { onCommit() }
                .onExitCommand { onCancel() }

            Spacer()
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 8)
        .onAppear {
            isFocused = true
        }
    }
}
