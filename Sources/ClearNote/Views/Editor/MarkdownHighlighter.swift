import Foundation
import AppKit
import Markdown
import Highlighter

struct MarkdownHighlighter: MarkupWalker {
    let storage: NSTextStorage
    let text: String
    
    private let baseFont = NSFont.systemFont(ofSize: 14, weight: .regular)
    private let baseColor = NSColor.labelColor
    
    // Markdown highlighter properties
    private lazy var syntaxHighlighter: Highlighter? = {
        let highlighter = Highlighter()
        highlighter?.setTheme("xcode")
        return highlighter
    }()
    
    private lazy var lineStarts: [String.Index] = {
        var starts: [String.Index] = []
        var currentIndex = text.startIndex
        starts.append(currentIndex)
        while currentIndex < text.endIndex {
            if text[currentIndex].isNewline {
                if text[currentIndex] == "\r" && text.index(after: currentIndex) < text.endIndex && text[text.index(after: currentIndex)] == "\n" {
                    currentIndex = text.index(after: currentIndex)
                }
                currentIndex = text.index(after: currentIndex)
                starts.append(currentIndex)
            } else {
                currentIndex = text.index(after: currentIndex)
            }
        }
        return starts
    }()
    
    init(storage: NSTextStorage, text: String) {
        self.storage = storage
        self.text = text
    }
    
    mutating func highlight() {
        let document = Document(parsing: text)
        
        let fullRange = NSRange(location: 0, length: storage.length)
        storage.beginEditing()
        
        // Reset to base style
        storage.setAttributes([
            .font: baseFont,
            .foregroundColor: baseColor
        ], range: fullRange)
        
        visit(document)
        
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
            let matches = detector.matches(in: text, options: [], range: fullRange)
            for match in matches {
                var attributes: [NSAttributedString.Key: Any] = [
                    .foregroundColor: NSColor.linkColor,
                    .underlineStyle: NSUnderlineStyle.single.rawValue
                ]
                if let url = match.url {
                    attributes[.link] = url
                }
                storage.addAttributes(attributes, range: match.range)
            }
        }
        
        storage.endEditing()
    }
    
    // MARK: - MarkupWalker Overrides

    mutating func visitHeading(_ heading: Heading) {
        guard let range = nsRange(for: heading) else { return }
        
        let fontSize: CGFloat
        let weight: NSFont.Weight
        
        switch heading.level {
        case 1:
            fontSize = 24
            weight = .bold
        case 2:
            fontSize = 20
            weight = .bold
        case 3:
            fontSize = 17
            weight = .semibold
        default:
            fontSize = 15
            weight = .semibold
        }
        
        storage.addAttributes([
            .font: NSFont.systemFont(ofSize: fontSize, weight: weight),
            .foregroundColor: NSColor.labelColor
        ], range: range)
        
        descendInto(heading)
    }
    
    mutating func visitStrong(_ strong: Strong) {
        guard let range = nsRange(for: strong) else { return }
        storage.addAttribute(.font, value: NSFont.systemFont(ofSize: 14, weight: .bold), range: range)
        descendInto(strong)
    }
    
    mutating func visitEmphasis(_ emphasis: Emphasis) {
        guard let range = nsRange(for: emphasis) else { return }
        
        let italicFont = baseFont.italic()
        storage.addAttribute(.font, value: italicFont, range: range)
        descendInto(emphasis)
    }
    
    mutating func visitInlineCode(_ inlineCode: InlineCode) {
        guard let range = nsRange(for: inlineCode) else { return }
        
        storage.addAttributes([
            .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular),
            .foregroundColor: NSColor.systemGray,
            .backgroundColor: NSColor.systemGray.withAlphaComponent(0.08)
        ], range: range)
    }
    
    mutating func visitCodeBlock(_ codeBlock: CodeBlock) {
        guard let range = nsRange(for: codeBlock) else { return }
        
        let monoFont = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        
        // Base styling for the whole code block enclosure
        storage.addAttributes([
            .font: monoFont,
            .foregroundColor: NSColor.systemGray,
            .backgroundColor: NSColor.systemGray.withAlphaComponent(0.06)
        ], range: range)
        
        // Syntactic highlighting for the inner code
        let codeText = codeBlock.code
        let language = codeBlock.language ?? ""
        
        if let highlighter = syntaxHighlighter,
           let highlighted = highlighter.highlight(codeText, as: language) {
            
            // Find the exact location of the codeText within the range to apply the attributes properly
            let nsString = text as NSString
            let innerRange = nsString.range(of: codeText, options: [], range: range)
            
            if innerRange.location != NSNotFound {
                highlighted.enumerateAttributes(in: NSRange(location: 0, length: highlighted.length), options: []) { attrs, attrRange, _ in
                    let mappedRange = NSRange(location: innerRange.location + attrRange.location, length: attrRange.length)
                    
                    var finalAttrs = attrs
                    // Ensure the font stays monospaced if HighligterSwift alters it unintentionally, 
                    // though Highlighter uses NSFont/UIFont objects.
                    if let font = attrs[.font] as? NSFont {
                        // Merge the custom font with monospace
                        let mergedFont = NSFont(descriptor: font.fontDescriptor.withSymbolicTraits(font.fontDescriptor.symbolicTraits), size: 13) ?? monoFont
                        finalAttrs[.font] = mergedFont
                    } else {
                        finalAttrs[.font] = monoFont
                    }
                    
                    storage.addAttributes(finalAttrs, range: mappedRange)
                }
            }
        }
        
        descendInto(codeBlock)
    }
    
    mutating func visitBlockQuote(_ blockQuote: BlockQuote) {
        guard let range = nsRange(for: blockQuote) else { return }
        storage.addAttributes([
            .foregroundColor: NSColor.secondaryLabelColor,
            .font: baseFont.italic()
        ], range: range)
        descendInto(blockQuote)
    }
    
    mutating func visitListItem(_ listItem: ListItem) {
        guard let range = nsRange(for: listItem) else { return }
        // The regex previously styled the list marker * or -. In AST parsing,
        // styling just the marker is tricky without descending, but descending
        // will naturally capture the inner text formatting. 
        // We can optionally style the start of the list item.
        let markerLength = 2
        let markerRange = NSRange(location: range.location, length: min(markerLength, range.length))
        storage.addAttributes([
            .font: NSFont.systemFont(ofSize: 14, weight: .semibold)
        ], range: markerRange)
        
        descendInto(listItem)
    }
    
    mutating func visitLink(_ link: Link) {
        guard let range = nsRange(for: link) else { return }
        
        var attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.linkColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        
        if let destination = link.destination, let url = URL(string: destination) {
            attributes[.link] = url
        }
        
        storage.addAttributes(attributes, range: range)
        descendInto(link)
    }

    // MARK: - Helpers

    private mutating func nsRange(for markup: Markup) -> NSRange? {
        guard let sourceRange = markup.range else { return nil }
        
        guard let startOffset = utf16Offset(line: sourceRange.lowerBound.line, column: sourceRange.lowerBound.column),
              let endOffset = utf16Offset(line: sourceRange.upperBound.line, column: sourceRange.upperBound.column) else {
            return nil
        }
        
        guard startOffset >= 0, endOffset >= startOffset, endOffset <= text.utf16.count else {
            return nil
        }
        
        return NSRange(location: startOffset, length: endOffset - startOffset)
    }
    
    private mutating func utf16Offset(line: Int, column: Int) -> Int? {
        let lineIdx = line - 1
        guard lineIdx >= 0 && lineIdx < lineStarts.count else { return nil }
        
        let lineStart = lineStarts[lineIdx]
        
        guard lineStart < text.endIndex else {
            return (text as NSString).length
        }
        
        let utf8View = text.utf8
        guard let utf8StartIndex = lineStart.samePosition(in: utf8View) else { return nil }
        
        // Column is 1-indexed utf8 byte offset
        let targetByteOffset = max(0, column - 1)
        
        guard let utf8TargetIndex = utf8View.index(utf8StartIndex, offsetBy: targetByteOffset, limitedBy: utf8View.endIndex) else {
            return nil
        }
        
        return utf8TargetIndex.samePosition(in: text.utf16)?.utf16Offset(in: text)
    }
}

private extension NSFont {
    func italic() -> NSFont {
        let descriptor = fontDescriptor.withSymbolicTraits(.italic)
        return NSFont(descriptor: descriptor, size: pointSize) ?? self
    }
}
