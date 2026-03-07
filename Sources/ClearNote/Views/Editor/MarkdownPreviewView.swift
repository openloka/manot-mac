import SwiftUI

struct MarkdownPreviewView: View {
    let content: String

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
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
                case .normal:
                    lineView(for: block.content)
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
        
        var normalLinesBuffer: [(Int, String)] = []
        
        func flushNormalLines() {
            for (index, line) in normalLinesBuffer {
                blocks.append(MarkdownBlock(offset: index, content: line, type: .normal))
            }
            normalLinesBuffer.removeAll()
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
                    flushNormalLines()
                    inCodeBlock = true
                    currentCodeLanguage = String(trimmedLine.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                    currentCodeContent = ""
                    startLineIndex = index
                } else {
                    normalLinesBuffer.append((index, line))
                }
            }
        }
        
        if inCodeBlock {
            blocks.append(MarkdownBlock(offset: startLineIndex, content: currentCodeContent, type: .code(language: currentCodeLanguage)))
        } else {
            flushNormalLines()
        }
        
        return blocks
    }

    @ViewBuilder
    private func lineView(for line: String) -> some View {
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
        } else if line.hasPrefix("> ") {
            blockquoteLine(String(line.dropFirst(2)))
        } else if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ") {
            listItemLine(String(line.dropFirst(2)))
        } else if line.trimmingCharacters(in: .whitespaces).isEmpty {
            Spacer().frame(height: 8)
        } else {
            Text(markdownInline(line))
                .font(.body)
                .lineSpacing(3)
                .textSelection(.enabled)
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
    private func blockquoteLine(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Rectangle()
                .fill(Color.accentColor)
                .frame(width: 3)
            Text(markdownInline(text))
                .font(.body.italic())
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func listItemLine(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundColor(.accentColor)
            Text(markdownInline(text))
                .font(.body)
        }
        .padding(.leading, 8)
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
        case normal
    }
}
