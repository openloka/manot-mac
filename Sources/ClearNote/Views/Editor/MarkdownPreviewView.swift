import SwiftUI

struct MarkdownPreviewView: View {
    let content: String
    var scrollSyncManager: ScrollSyncManager?
    var onToggleTask: ((Int) -> Void)?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if let scrollSyncManager = scrollSyncManager {
                    ScrollViewExtractor { scrollView in
                        scrollSyncManager.previewScrollView = scrollView
                    }
                    .frame(width: 0, height: 0)
                }
                
                VStack(alignment: .leading, spacing: 0) {
                    if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Nothing to preview yet.")
                            .foregroundStyle(.tertiary)
                            .italic()
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 60)
                    } else {
                        renderedContent
                            .padding(.bottom, 40)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .environment(\.openURL, OpenURLAction { url in
                let stringURL = url.absoluteString
                if stringURL.hasPrefix("#") {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("jumpToHeadingID"),
                        object: nil,
                        userInfo: ["headingID": String(stringURL.dropFirst())]
                    )
                    return .handled
                }
                return .systemAction
            })
            .onReceive(NotificationCenter.default.publisher(for: .jumpToRange)) { notification in
                if let range = notification.userInfo?["range"] as? NSRange {
                    let nsString = content as NSString
                    let lines = nsString.components(separatedBy: "\n")
                    var currentOffset = 0
                    for (index, line) in lines.enumerated() {
                        let lineLength = (line as NSString).length
                        if range.location >= currentOffset && range.location <= currentOffset + lineLength {
                            withAnimation {
                                proxy.scrollTo(index, anchor: .top)
                            }
                            break
                        }
                        currentOffset += lineLength + 1
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("jumpToHeadingID"))) { notification in
                if let headingID = notification.userInfo?["headingID"] as? String {
                    let nsString = content as NSString
                    let lines = nsString.components(separatedBy: "\n")
                    for (index, line) in lines.enumerated() {
                        let trimmed = line.trimmingCharacters(in: .whitespaces)
                        if trimmed.hasPrefix("#") {
                            let pattern = "^(#{1,6})\\s+(.+)$"
                            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
                            if let match = regex.firstMatch(in: trimmed, range: NSRange(location: 0, length: (trimmed as NSString).length)) {
                                let titleText = (trimmed as NSString).substring(with: match.range(at: 2))
                                let generatedID = titleText.lowercased().replacingOccurrences(of: " ", with: "-")
                                if generatedID == headingID {
                                    withAnimation {
                                        proxy.scrollTo(index, anchor: .top)
                                    }
                                    break
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var renderedContent: some View {
        let blocks = parseBlocks(from: content)
        VStack(alignment: .leading, spacing: 6) {
            ForEach(blocks) { block in
                switch block.type {
                case .code(let lang):
                    multiLineCodeBlock(block.content, language: lang)
                        .id(block.offset)
                case .table(let rows):
                    tableBlockView(rows)
                        .id(block.offset)
                case .normal:
                    lineView(for: block.content, offset: block.offset)
                        .id(block.offset)
                }
            }
        }
    }

    private func parseBlocks(from text: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        let lines = (text as NSString).components(separatedBy: "\n")
        
        var inCodeBlock = false
        var currentCodeLanguage = ""
        var currentCodeContent = ""
        var startLineIndex = 0
        
        var inTableBlock = false
        var currentTableRows: [[String]] = []
        
        var normalLinesBuffer: [(Int, String)] = []
        
        func flushNormalLines() {
            for (index, line) in normalLinesBuffer {
                blocks.append(MarkdownBlock(offset: index, content: line, type: .normal))
            }
            normalLinesBuffer.removeAll()
        }
        
        func flushTableBlock() {
            if !currentTableRows.isEmpty {
                blocks.append(MarkdownBlock(offset: startLineIndex, content: "", type: .table(rows: currentTableRows)))
                currentTableRows.removeAll()
            }
            inTableBlock = false
        }
        
        func parseTableRow(_ line: String) -> [String]? {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.contains("|") else { return nil }
            let trimmedParts = trimmed.split(separator: "|", omittingEmptySubsequences: false).map { String($0).trimmingCharacters(in: .whitespaces) }
            
            var row = trimmedParts
            if trimmed.hasPrefix("|") && !row.isEmpty {
                row.removeFirst()
            }
            if trimmed.hasSuffix("|") && !row.isEmpty {
                row.removeLast()
            }
            guard !row.isEmpty else { return nil }
            return row
        }
        
        for (index, line) in lines.enumerated() {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            if inCodeBlock {
                if trimmedLine.hasPrefix("```") {
                    blocks.append(MarkdownBlock(offset: startLineIndex, content: currentCodeContent, type: .code(language: currentCodeLanguage)))
                    inCodeBlock = false
                } else {
                    if !currentCodeContent.isEmpty {
                        currentCodeContent += "\n"
                    }
                    currentCodeContent += line
                }
            } else {
                if trimmedLine.hasPrefix("```") {
                    if inTableBlock { flushTableBlock() }
                    flushNormalLines()
                    inCodeBlock = true
                    currentCodeLanguage = String(trimmedLine.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                    currentCodeContent = ""
                    startLineIndex = index
                } else if let row = parseTableRow(line) {
                    flushNormalLines()
                    if !inTableBlock {
                        inTableBlock = true
                        startLineIndex = index
                    }
                    currentTableRows.append(row)
                } else {
                    if inTableBlock {
                        flushTableBlock()
                    }
                    normalLinesBuffer.append((index, line))
                }
            }
        }
        
        if inCodeBlock {
            blocks.append(MarkdownBlock(offset: startLineIndex, content: currentCodeContent, type: .code(language: currentCodeLanguage)))
        } else if inTableBlock {
            flushTableBlock()
        } else {
            flushNormalLines()
        }
        
        return blocks
    }

    @ViewBuilder
    private func lineView(for line: String, offset: Int = 0) -> some View {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let indentLevel = line.prefix(while: { $0 == " " }).count / 2
        
        if line.hasPrefix("# ") {
            Text(markdownInline(String(line.dropFirst(2))))
                .font(.largeTitle.bold())
                .padding(.top, 20)
                .padding(.bottom, 4)
        } else if line.hasPrefix("## ") {
            Text(markdownInline(String(line.dropFirst(3))))
                .font(.title.bold())
                .padding(.top, 16)
                .padding(.bottom, 2)
        } else if line.hasPrefix("### ") {
            Text(markdownInline(String(line.dropFirst(4))))
                .font(.title2.bold())
                .padding(.top, 12)
        } else if line.hasPrefix("#### ") {
            Text(markdownInline(String(line.dropFirst(5))))
                .font(.title3.bold())
                .padding(.top, 8)
        } else if line.hasPrefix("    ") {
            codeBlockLine(line)
        } else if trimmed == "---" || trimmed == "***" || trimmed == "___" {
            Divider().padding(.vertical, 8)
        } else if trimmed.hasPrefix("- [ ] ") || trimmed.hasPrefix("* [ ] ") {
            TaskItemRow(
                text: markdownInline(String(trimmed.dropFirst(6))),
                checked: false,
                indent: indentLevel,
                onToggle: { onToggleTask?(offset) }
            )
        } else if trimmed.hasPrefix("- [x] ") || trimmed.hasPrefix("* [x] ") || trimmed.hasPrefix("- [X] ") || trimmed.hasPrefix("* [X] ") {
            TaskItemRow(
                text: markdownInline(String(trimmed.dropFirst(6))),
                checked: true,
                indent: indentLevel,
                onToggle: { onToggleTask?(offset) }
            )
        } else if trimmed.hasPrefix(">>") {
            blockquoteLine(String(trimmed.dropFirst(3)), level: 2)
        } else if trimmed.hasPrefix("> ") {
            blockquoteLine(String(trimmed.dropFirst(2)), level: 1)
        } else if let range = trimmed.range(of: "^[-*+]\\s+", options: .regularExpression) {
            let text = String(trimmed[range.upperBound...])
            listItemLine(text, indent: indentLevel)
        } else if let range = trimmed.range(of: "^\\d+\\.\\s+", options: .regularExpression) {
            let prefix = String(trimmed[..<range.upperBound]).trimmingCharacters(in: .whitespaces)
            let text = String(trimmed[range.upperBound...])
            orderedListItemLine(prefix, text: text, indent: indentLevel)
        } else if trimmed.range(of: "^\\[\\^.*\\]:", options: .regularExpression) != nil {
            footnoteLine(trimmed)
        } else if trimmed.isEmpty {
            Spacer().frame(height: 8)
        } else {
            let containsLink = line.contains("](") || line.contains("http://") || line.contains("https://")
            if containsLink {
                LinkTextLine(attributed: markdownInline(line))
            } else {
                Text(markdownInline(line))
                    .font(.body)
                    .lineSpacing(3)
                    .textSelection(.enabled)
            }
        }
    }

    @ViewBuilder
    private func codeBlockLine(_ line: String) -> some View {
        let code = line.hasPrefix("    ") ? String(line.dropFirst(4)) : line
        Text(syntaxHighlight(code, language: ""))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.textBackgroundColor).opacity(0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                    )
            )
            .padding(.vertical, 4)
            .textSelection(.enabled)
    }

    @ViewBuilder
    private func multiLineCodeBlock(_ code: String, language: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if !language.isEmpty {
                Text(language.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
            }
            Text(syntaxHighlight(code, language: language))
                .padding(.horizontal, 16)
                .padding(.vertical, language.isEmpty ? 12 : 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.textBackgroundColor).opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                )
        )
        .padding(.vertical, 4)
    }

    private func syntaxHighlight(_ code: String, language: String) -> AttributedString {
        var attrStr = AttributedString(code)
        attrStr.font = .system(.body, design: .monospaced)
        attrStr.foregroundColor = .primary

        let nsCode = code as NSString
        let fullRange = NSRange(location: 0, length: nsCode.length)
        
        let lang = language.lowercased()
        
        // Base highlighting for strings
        if let regex = try? NSRegularExpression(pattern: "(\"[^\"]*\"|'[^']*'|`[^`]*`)") {
            for match in regex.matches(in: code, range: fullRange) {
                if let range = Range(match.range, in: attrStr) {
                    attrStr[range].foregroundColor = .systemOrange
                }
            }
        }

        // Language specific
        if lang == "javascript" || lang == "js" {
            let keywords = ["function", "const", "let", "var", "if", "else", "for", "while", "return", "import", "export", "from", "class", "default", "new", "await", "async"]
            let keywordPattern = "\\b(\(keywords.joined(separator: "|")))\\b"
            if let regex = try? NSRegularExpression(pattern: keywordPattern) {
                for match in regex.matches(in: code, range: fullRange) {
                    if let range = Range(match.range, in: attrStr) {
                        attrStr[range].foregroundColor = .systemPink
                    }
                }
            }
            
            let buildInsPattern = "\\b(console|alert|window|document|Math|Object|Array)\\b"
            if let regex = try? NSRegularExpression(pattern: buildInsPattern) {
                for match in regex.matches(in: code, range: fullRange) {
                    if let range = Range(match.range, in: attrStr) {
                        attrStr[range].foregroundColor = .systemTeal
                    }
                }
            }
        } else if lang == "swift" {
            let keywords = ["func", "let", "var", "if", "else", "guard", "return", "class", "struct", "enum", "extension", "import", "public", "private", "some", "any", "await", "async"]
            let keywordPattern = "\\b(\(keywords.joined(separator: "|")))\\b"
            if let regex = try? NSRegularExpression(pattern: keywordPattern) {
                for match in regex.matches(in: code, range: fullRange) {
                    if let range = Range(match.range, in: attrStr) {
                        attrStr[range].foregroundColor = .systemPink
                    }
                }
            }
        }
        // Add more languages as needed...
        
        return attrStr
    }

    @ViewBuilder
    private func blockquoteLine(_ text: String, level: Int = 1) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ForEach(0..<level, id: \.self) { _ in
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(width: 3)
            }
            Text(markdownInline(text))
                .font(.body.italic())
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func listItemLine(_ text: String, indent: Int) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(indent % 2 == 0 ? "•" : "◦")
                .foregroundColor(.accentColor)
            Text(markdownInline(text))
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.leading, CGFloat(indent * 20))
    }

    @ViewBuilder
    private func orderedListItemLine(_ prefix: String, text: String, indent: Int) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(prefix)
                .foregroundColor(.accentColor)
                .font(.body.monospacedDigit())
            Text(markdownInline(text))
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.leading, CGFloat(indent * 20))
    }

    // taskItemLine replaced by TaskItemRow struct below

    @ViewBuilder
    private func footnoteLine(_ line: String) -> some View {
        Text(markdownInline(line))
            .font(.footnote)
            .foregroundColor(.secondary)
            .padding(.leading, 8)
            .padding(.top, 4)
    }

    @ViewBuilder
    private func tableBlockView(_ rows: [[String]]) -> some View {
        let validRows = rows.filter { row in 
            !row.allSatisfy { $0.allSatisfy { c in c == "-" || c == ":" } }
        }
        let maxCols = validRows.map { $0.count }.max() ?? 0
        
        if validRows.isEmpty {
            EmptyView()
        } else {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                ForEach(0..<validRows.count, id: \.self) { rowIndex in
                    let row = validRows[rowIndex]
                    GridRow {
                        ForEach(0..<maxCols, id: \.self) { colIndex in
                            if colIndex < row.count {
                                Text(markdownInline(row[colIndex]))
                                    .font(rowIndex == 0 ? .body.bold() : .body)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                Color.clear.frame(height: 1)
                            }
                        }
                    }
                    if rowIndex == 0 {
                        Divider()
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.textBackgroundColor).opacity(0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                    )
            )
            .padding(.vertical, 8)
        }
    }

    private func markdownInline(_ text: String) -> AttributedString {
        var str = AttributedString()
        
        // This regex catches code elements like `this` to extract the text
        let inlineCodePattern = "`([^`]+)`"
        
        if let regex = try? NSRegularExpression(pattern: inlineCodePattern) {
            let nsString = text as NSString
            let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsString.length))
            
            if matches.isEmpty {
                // Standard default string if no code elements present
                str = (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(text)
            } else {
                var lastRangeEnd = 0
                for match in matches {
                    let textBefore = nsString.substring(with: NSRange(location: lastRangeEnd, length: match.range.location - lastRangeEnd))
                    if !textBefore.isEmpty {
                        if let attrText = try? AttributedString(markdown: textBefore, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
                            str.append(attrText)
                        } else {
                            str.append(AttributedString(textBefore))
                        }
                    }
                    
                    let rawCodeText = nsString.substring(with: match.range(at: 1))
                    // Add space padding to the inline code
                    var codeAttr = AttributedString(" \(rawCodeText) ")
                    codeAttr.font = .system(.body, design: .monospaced)
                    codeAttr.foregroundColor = .primary
                    codeAttr.backgroundColor = Color.secondary.opacity(0.15)
                    str.append(codeAttr)
                    
                    lastRangeEnd = match.range.location + match.range.length
                }
                
                if lastRangeEnd < nsString.length {
                    let trailingText = nsString.substring(from: lastRangeEnd)
                    if let attrTrailing = try? AttributedString(markdown: trailingText, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
                        str.append(attrTrailing)
                    } else {
                        str.append(AttributedString(trailingText))
                    }
                }
            }
        } else {
            str = (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(text)
        }
        
        return str
    }
}

struct MarkdownBlock: Identifiable {
    var id: Int { offset }
    let offset: Int
    let content: String
    let type: BlockType

    enum BlockType {
        case code(language: String)
        case table(rows: [[String]])
        case normal
    }
}

/// An interactive task-list item for the Markdown preview.
/// Tapping the checkbox triggers `onToggle`, which the parent uses to
/// rewrite the underlying Markdown source ([ ] ↔ [x]).
/// The checkbox icon bounces via a spring and the label fades its
/// colour + strikethrough when the `checked` state changes.
struct TaskItemRow: View {
    let text: AttributedString
    let checked: Bool
    let indent: Int
    let onToggle: () -> Void

    @State private var bounceScale: CGFloat = 1.0

    var body: some View {
        Button(action: {
            bounceScale = 1.0
            withAnimation(.spring(response: 0.25, dampingFraction: 0.4)) {
                bounceScale = 1.35
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                    bounceScale = 1.0
                }
            }
            onToggle()
        }) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: checked ? "checkmark.square.fill" : "square")
                    .font(.system(size: 15))
                    .foregroundColor(checked ? .accentColor : .secondary)
                    .scaleEffect(bounceScale)
                    .animation(.spring(response: 0.3, dampingFraction: 0.5), value: checked)
                    .padding(.top, 2)
                Text(text)
                    .font(.body)
                    .foregroundColor(checked ? .secondary : .primary)
                    .strikethrough(checked, color: .secondary)
                    .animation(.easeInOut(duration: 0.22), value: checked)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.leading, CGFloat(indent * 20))
            .padding(.vertical, 3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }
}

/// A Text view that shows a pointing-hand cursor when the user hovers anywhere
/// over it. Used for lines that contain markdown hyperlinks, because SwiftUI's
/// Text on macOS does not automatically change the cursor for inline link spans.
struct LinkTextLine: View {

    let attributed: AttributedString
    @State private var isHovered = false

    var body: some View {
        Text(attributed)
            .font(.body)
            .lineSpacing(3)
            .onHover { hovering in
                isHovered = hovering
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
    }
}
