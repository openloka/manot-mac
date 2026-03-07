import SwiftUI
import SwiftData

enum EditorMode: String, CaseIterable {
    case edit    = "pencil"
    case split   = "rectangle.split.2x1"
    case preview = "eye"

    var label: String {
        switch self {
        case .edit:    return "Edit"
        case .split:   return "Split"
        case .preview: return "Preview"
        }
    }
}

struct EditorView: View {
    @Bindable var note: Note
    @Environment(\.modelContext) private var modelContext

    @State private var editorMode: EditorMode = .edit
    @State private var saveTask: Task<Void, Never>?
    @State private var showWordCount = true

    // MARK: - Computed

    private var wordCount: Int {
        note.content
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }.count
    }

    private var charCount: Int { note.content.count }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            titleBar

            Divider()

            contentArea

            Divider()

            statusBar
        }
        .toolbar {
            editorToolbar
        }
    }

    // MARK: - Title Bar

    private var titleBar: some View {
        HStack {
            TextField("Untitled", text: $note.title)
                .font(.title2.weight(.semibold))
                .textFieldStyle(.plain)
                .onChange(of: note.title) { _, _ in scheduleAutoSave() }

            Spacer()

            // Sync status indicator
            Image(systemName: "checkmark.icloud")
                .foregroundColor(.secondary)
                .font(.caption)
                .help("Synced to iCloud")
        }
        .padding(.horizontal, 28)
        .padding(.top, 20)
        .padding(.bottom, 14)
    }

    // MARK: - Content

    @ViewBuilder
    private var contentArea: some View {
        switch editorMode {
        case .edit:
            syntaxEditor
        case .preview:
            MarkdownPreviewView(content: note.content)
        case .split:
            HSplitView {
                syntaxEditor
                    .frame(minWidth: 200, maxWidth: .infinity, maxHeight: .infinity)
                
                MarkdownPreviewView(content: note.content)
                    .frame(minWidth: 200, maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: - Syntax-Aware Editor

    private var syntaxEditor: some View {
        SyntaxTextEditor(text: $note.content, onChange: {
            scheduleAutoSave()
        })
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Status Bar

    private var statusBar: some View {
        HStack {
            if showWordCount {
                Label("\(wordCount) words", systemImage: "text.word.spacing")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("·")
                    .foregroundStyle(.tertiary)

                Text("\(charCount) characters")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("Auto-saved")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var editorToolbar: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Picker("Mode", selection: $editorMode) {
                ForEach(EditorMode.allCases, id: \.self) { mode in
                    Image(systemName: mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 130)
            .help("Switch between Edit, Split, and Preview modes")
        }

        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                insertMarkdown("**", "**")
            } label: {
                Image(systemName: "bold")
            }
            .help("Bold (⌘B)")
            .keyboardShortcut("b", modifiers: .command)

            Button {
                insertMarkdown("_", "_")
            } label: {
                Image(systemName: "italic")
            }
            .help("Italic (⌘I)")
            .keyboardShortcut("i", modifiers: .command)

            Button {
                insertMarkdown("`", "`")
            } label: {
                Image(systemName: "curlybraces")
            }
            .help("Inline code")

            Divider()

            Menu {
                Button("Export as Markdown (.md)…") {
                    ExportService.exportAsMarkdown(note: note)
                }
                Button("Export as PDF (.pdf)…") {
                    ExportService.exportAsPDF(note: note)
                }
            } label: {
                Label("Export", systemImage: "arrow.up.doc")
            }
            .help("Export note")
        }
    }

    // MARK: - Auto-Save

    private func scheduleAutoSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            if !Task.isCancelled {
                note.updatedAt = Date()
                try? modelContext.save()
            }
        }
    }

    // MARK: - Markdown Insertion Helper

    private func insertMarkdown(_ prefix: String, _ suffix: String) {
        NotificationCenter.default.post(
            name: .insertMarkdown,
            object: nil,
            userInfo: ["prefix": prefix, "suffix": suffix]
        )
    }
}

extension Notification.Name {
    static let insertMarkdown = Notification.Name("insertMarkdown")
}
