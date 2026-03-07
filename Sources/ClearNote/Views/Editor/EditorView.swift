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
    @Binding var isZenMode: Bool
    @Environment(\.modelContext) private var modelContext

    @State private var editorMode: EditorMode = .edit
    @State private var saveTask: Task<Void, Never>?
    @State private var showWordCount = true
    @State private var headings: [HeadingItem] = []

    // MARK: - Computed

    private var wordCount: Int {
        note.content
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }.count
    }

    private var charCount: Int { note.content.count }

    // MARK: - Body

    var body: some View {
        Group {
            if isZenMode {
                zenModeView
            } else {
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
        }
        .onAppear {
            parseHeadings(from: note.content)
        }
        .onChange(of: note.content) { _, newContent in
            parseHeadings(from: newContent)
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
        HStack(spacing: 0) {
            Group {
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if !isZenMode && !headings.isEmpty {
                Divider()
                TableOfContentsView(headings: headings)
                    .frame(width: 220)
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
                withAnimation { isZenMode = true }
            } label: {
                Image(systemName: "arrow.up.backward.and.arrow.down.forward")
            }
            .help("Zen Mode")
            .keyboardShortcut("z", modifiers: [.command, .shift])

            Button {
                let textToInsert = (note.content.isEmpty ? "" : "\n\n") + EditorView.exampleMarkdown
                note.content += textToInsert
                scheduleAutoSave()
            } label: {
                Image(systemName: "wand.and.stars")
            }
            .help("Insert Example Markdown")

            Divider()

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

    // MARK: - Example Markdown

    private static let exampleMarkdown = """
    # Welcome to ClearNote
    This is an **advanced** Markdown editor built for speed and aesthetics.

    ## Features
    - **Syntax Highlighting** for both inline `code` and multiline code blocks
    - **Table of Contents** navigation pane automatically generated
    - Live and Split **Preview** modes with elegant typography
    - Cloud Sync supported

    ### Code Support
    Here is a multiline block with `javascript` highlighting enabled:

    ```javascript
    function greet() {
        console.log("Hello, World!");
        alert('Welcome!');
    }
    ```

    And here is one for `swift`:
    
    ```swift
    @MainActor
    func updateUI() {
        let editor = EditorView()
        print(editor)
    }
    ```

    ### Focus on Typography
    Enjoy native feeling formatting elements:
    > "Design is not just what it looks like and feels like. Design is how it works."
    
    You can even mix **_bold and italic_** text properly.
    """

    // MARK: - Zen Mode
    
    private var zenModeView: some View {
        ZStack {
            Color(NSColor.windowBackgroundColor)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                zenTitleBar
                
                contentArea
                    .frame(maxWidth: 800)
            }
            
            VStack {
                HStack {
                    Spacer()
                    Button {
                        withAnimation { isZenMode = false }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.down.right.and.arrow.up.left")
                            Text("EXIT ZEN MODE")
                        }
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                            .background(Color.white.opacity(0.05))
                    )
                    .padding(20)
                }
                Spacer()
            }
            
            VStack {
                Spacer()
                zenToolbar
                    .padding(.bottom, 40)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var zenTitleBar: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "text.alignleft")
                Text("DRAFTING: \(note.title.uppercased()).MD")
            }
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundColor(.secondary)
            
            TextField("Untitled", text: $note.title)
                .font(.system(size: 32, weight: .bold, design: .default))
                .textFieldStyle(.plain)
                .onChange(of: note.title) { _, _ in scheduleAutoSave() }
        }
        .padding(.horizontal, 40)
        .padding(.top, 60)
        .padding(.bottom, 20)
        .frame(maxWidth: 800)
    }

    private var zenToolbar: some View {
        HStack(spacing: 16) {
            HStack(spacing: 4) {
                Text("WORDS")
                    .foregroundColor(.secondary)
                Text("\(wordCount)")
                    .foregroundColor(.blue)
            }
            .font(.system(size: 10, weight: .bold, design: .rounded))

            Divider()
                .frame(height: 12)

            Button {
                insertMarkdown("**", "**")
            } label: {
                Image(systemName: "bold")
                    .font(.system(size: 13, weight: .bold))
            }
            .buttonStyle(.plain)
            .help("Bold")

            Button {
                insertMarkdown("_", "_")
            } label: {
                Image(systemName: "italic")
                    .font(.system(size: 13, weight: .bold))
            }
            .buttonStyle(.plain)
            .help("Italic")

            Button {
                insertMarkdown("[", "](url)")
            } label: {
                Image(systemName: "link")
                    .font(.system(size: 13, weight: .bold))
            }
            .buttonStyle(.plain)
            .help("Link")
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
        )
    }

    // MARK: - Parsing Headings
    
    private func parseHeadings(from text: String) {
        var items: [HeadingItem] = []
        let pattern = "^(#{1,6})\\s+(.+)$"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else { return }
        let nsString = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsString.length))
        
        for match in matches {
            if match.numberOfRanges == 3 {
                 let levelText = nsString.substring(with: match.range(at: 1))
                 let titleText = nsString.substring(with: match.range(at: 2))
                 items.append(HeadingItem(level: levelText.count, text: titleText, range: match.range))
            }
        }
        headings = items
    }
}

extension Notification.Name {
    static let insertMarkdown = Notification.Name("insertMarkdown")
    static let jumpToRange = Notification.Name("jumpToRange")
}

struct HeadingItem: Identifiable, Hashable {
    let id = UUID()
    let level: Int
    let text: String
    let range: NSRange
}

struct TableOfContentsView: View {
    let headings: [HeadingItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Outline")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(headings) { heading in
                        Button {
                            NotificationCenter.default.post(
                                name: NSNotification.Name("jumpToRange"),
                                object: nil,
                                userInfo: ["range": heading.range]
                            )
                        } label: {
                            Text(heading.text)
                                .font(.system(size: 13, weight: heading.level == 1 ? .semibold : .regular, design: .rounded))
                                .foregroundColor(heading.level == 1 ? .primary : .secondary)
                                .lineLimit(1)
                                .padding(.vertical, 4)
                                .padding(.leading, CGFloat((heading.level - 1) * 12))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.bottom, 16)
            }
        }
        .background(.ultraThinMaterial)
    }
}
