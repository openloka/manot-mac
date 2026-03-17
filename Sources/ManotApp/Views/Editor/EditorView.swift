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
    @EnvironmentObject private var themeManager: ThemeManager

    @State private var editorMode: EditorMode = .edit
    @State private var saveTask: Task<Void, Never>?
    @State private var showWordCount = true
    @State private var headings: [HeadingItem] = []
    @State private var scrollSyncManager = ScrollSyncManager()

    // MARK: - Computed

    private var wordCount: Int {
        note.content
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }.count
    }

    private var charCount: Int { note.content.count }

    // MARK: - Body

    var body: some View {
        ZStack {
            if isZenMode {
                Color(NSColor.textBackgroundColor)
                    .ignoresSafeArea()
            }
            
            VStack(spacing: 0) {
                if isZenMode {
                    zenTitleBar
                } else {
                    titleBar
                    Divider()
                }

                contentArea
                    .frame(maxWidth: isZenMode ? 800 : .infinity)

                if !isZenMode {
                    Divider()
                    statusBar
                }
            }

            if isZenMode {
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
                                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                                .background(Color.primary.opacity(0.05))
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
        }
        .toolbar {
            editorToolbar
        }
        .onAppear {
            parseHeadings(from: note.content)
        }
        .onChange(of: note.content) { _, newContent in
            parseHeadings(from: newContent)
        }
        .onChange(of: editorMode) { _, newMode in
            scrollSyncManager.isEnabled = (newMode == .split)
        }
        .onAppear {
            scrollSyncManager.isEnabled = (editorMode == .split)
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
                    MarkdownPreviewView(
                        content: note.content,
                        scrollSyncManager: scrollSyncManager,
                        onToggleTask: { lineIndex in toggleTask(at: lineIndex) }
                    )
                case .split:
                    HSplitView {
                        syntaxEditor
                            .frame(minWidth: 200, maxWidth: .infinity, maxHeight: .infinity)

                        MarkdownPreviewView(
                            content: note.content,
                            scrollSyncManager: scrollSyncManager,
                            onToggleTask: { lineIndex in toggleTask(at: lineIndex) }
                        )
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
        }, scrollSyncManager: scrollSyncManager)
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
            // Theme toggle
            Button {
                themeManager.cycle()
            } label: {
                Image(systemName: themeManager.current.iconName)
            }
            .help("Appearance: \(themeManager.current.label) – click to switch")
            .keyboardShortcut("t", modifiers: [.command, .shift])

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

    // MARK: - Task Toggle

    /// Toggles the `[ ]` / `[x]` marker on the line at `lineIndex` in `note.content`.
    private func toggleTask(at lineIndex: Int) {
        var lines = note.content.components(separatedBy: "\n")
        guard lineIndex < lines.count else { return }
        let line = lines[lineIndex]
        let indent = String(line.prefix(while: { $0 == " " }))
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        let toggled: String
        if trimmed.hasPrefix("- [ ] ") {
            toggled = indent + "- [x] " + String(trimmed.dropFirst(6))
        } else if trimmed.hasPrefix("- [x] ") || trimmed.hasPrefix("- [X] ") {
            toggled = indent + "- [ ] " + String(trimmed.dropFirst(6))
        } else if trimmed.hasPrefix("* [ ] ") {
            toggled = indent + "* [x] " + String(trimmed.dropFirst(6))
        } else if trimmed.hasPrefix("* [x] ") || trimmed.hasPrefix("* [X] ") {
            toggled = indent + "* [ ] " + String(trimmed.dropFirst(6))
        } else {
            return
        }

        lines[lineIndex] = toggled
        note.content = lines.joined(separator: "\n")
        scheduleAutoSave()
    }

    // MARK: - Example Markdown

    private static let exampleMarkdown = """
    Here’s a complete example Markdown document that demonstrates many common Markdown features (headings, formatting, lists, tables, code blocks, links, images, quotes, etc.).

    # Sample Markdown Document

    Welcome to this **Markdown example**. This document demonstrates common Markdown syntax and features.

    ---

    ## Table of Contents
    1. [Text Formatting](#text-formatting)
    2. [Lists](#lists)
    3. [Links](#links)
    4. [Images](#images)
    5. [Code Blocks](#code-blocks)
    6. [Tables](#tables)
    7. [Blockquotes](#blockquotes)
    8. [Task Lists](#task-lists)

    ---

    ## Text Formatting

    You can style text in different ways:

    - **Bold text**
    - *Italic text*
    - ***Bold and italic***
    - ~~Strikethrough~~
    - `Inline code`

    Example sentence:

    > Markdown makes writing documentation **simple** and *readable*.

    ---

    ## Lists

    ### Unordered List
    - Apple
    - Banana
    - Orange
      - Mandarin
      - Blood orange

    ### Ordered List
    1. Install Markdown editor
    2. Write content
    3. Preview document
    4. Export or publish

    ---

    ## Links

    Example of a link:

    [Visit OpenAI](https://openai.com)

    You can also write automatic links:

    https://github.com

    ---

    ## Images

    Example image syntax:

    ![Markdown Logo](https://upload.wikimedia.org/wikipedia/commons/4/48/Markdown-mark.svg)

    ---

    ## Code Blocks

    Inline code example:

    `npm install`

    Multi-line code block:

    ```javascript
    function greet(name) {
      return `Hello, ${name}!`;
    }

    console.log(greet("World"));
    ```

    Example Bash command:

    ```bash
    git clone https://github.com/example/repo.git
    cd repo
    npm install
    ```

    ---

    ## Tables

    | Name    | Role          | Experience |
    | ------- | ------------- | ---------- |
    | Alice   | Developer     | 5 years    |
    | Bob     | Designer      | 3 years    |
    | Carol   | Product Mgr   | 7 years    |

    ---

    ## Blockquotes

    > Markdown is a lightweight markup language for creating formatted text using a plain-text editor.

    Nested quote:

    > First level quote
    >> Second level quote

    ---

    ## Task Lists
    - [x] Write Markdown example
    - [x] Add formatting examples
    - [ ] Add more advanced sections
    - [ ] Publish documentation

    ---

    ## Horizontal Rule

    You can separate sections using:

    ---

    ## Footnotes

    Here is a statement with a footnote.[^1]

    [^1]: This is the footnote explanation.

    ---

    ## Conclusion

    Markdown is widely used for:
    - Documentation
    - README files
    - Static site generators
    - Note-taking apps

    Because it is simple, portable, and easy to read.

    If you want, I can also show:
    - **Advanced Markdown example (GitHub README style)**
    - **Real project documentation example**
    - **Markdown cheatsheet**
    - **Markdown for blogs or technical docs**
    """

    // MARK: - Zen Mode
    
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
                        TOCButtonRow(heading: heading)
                    }
                }
                .padding(.bottom, 16)
            }
        }
        .background(.ultraThinMaterial)
    }
}

struct TOCButtonRow: View {
    let heading: HeadingItem
    @State private var isHovered = false

    var body: some View {
        Button {
            // Jump in editor (edit/split mode)
            NotificationCenter.default.post(
                name: NSNotification.Name("jumpToRange"),
                object: nil,
                userInfo: ["range": heading.range]
            )
            // Jump in preview (preview/split mode)
            let headingID = heading.text
                .lowercased()
                .replacingOccurrences(of: " ", with: "-")
            NotificationCenter.default.post(
                name: NSNotification.Name("jumpToHeadingID"),
                object: nil,
                userInfo: ["headingID": headingID]
            )
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "link")
                    .font(.system(size: 10))
                    .foregroundColor(.accentColor)
                    .opacity(isHovered ? 1 : 0)
                Text(heading.text)
                    .font(.system(size: 13, weight: heading.level == 1 ? .semibold : .regular, design: .rounded))
                    .foregroundColor(isHovered ? .accentColor : (heading.level == 1 ? .primary : .secondary))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 4)
            .padding(.leading, CGFloat((heading.level - 1) * 12))
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.accentColor.opacity(isHovered ? 0.08 : 0))
            )
            // onHover lives INSIDE the label so .buttonStyle(.plain) cannot
            // intercept and reset the cursor before our handler fires.
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.1)) {
                    isHovered = hovering
                }
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }
}
