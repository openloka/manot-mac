import SwiftUI
import AppKit

/// A syntax-highlighted markdown editor backed by NSTextView.
/// Highlights: Headers (blue/bold), Bold (**), Italic (_), `code`, URLs
struct SyntaxTextEditor: NSViewRepresentable {
    @Binding var text: String
    var onChange: () -> Void

    // MARK: - NSViewRepresentable

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else { return scrollView }

        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = true
        textView.isContinuousSpellCheckingEnabled = true
        textView.font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.textContainerInset = NSSize(width: 4, height: 4)
        textView.textContainer?.lineFragmentPadding = 0
        textView.string = text

        // Styling
        textView.backgroundColor = NSColor.textBackgroundColor
        scrollView.backgroundColor = NSColor.textBackgroundColor

        // Line wrapping
        textView.textContainer?.widthTracksTextView = true
        textView.isHorizontallyResizable = false

        applyHighlighting(to: textView)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        // Only update if text was changed externally (avoid cursor reset)
        if textView.string != text {
            let selectedRange = textView.selectedRange()
            textView.string = text
            textView.setSelectedRange(selectedRange)
            applyHighlighting(to: textView)
        }
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: SyntaxTextEditor
        private var highlightTask: Task<Void, Never>?

        init(_ parent: SyntaxTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            parent.onChange()

            // Debounce highlighting
            highlightTask?.cancel()
            highlightTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(150))
                guard !Task.isCancelled else { return }
                self.parent.applyHighlighting(to: textView)
            }
        }
    }

    // MARK: - Syntax Highlighting

    func applyHighlighting(to textView: NSTextView) {
        let storage = textView.textStorage!
        let fullRange = NSRange(location: 0, length: storage.length)
        let text = storage.string

        // Reset to base style
        storage.beginEditing()
        storage.setAttributes([
            .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .regular),
            .foregroundColor: NSColor.labelColor
        ], range: fullRange)

        // H1 – H4
        let headerPatterns: [(String, NSFont, CGFloat)] = [
            ("^#{1} .+$", .monospacedSystemFont(ofSize: 24, weight: .bold), 0),
            ("^#{2} .+$", .monospacedSystemFont(ofSize: 20, weight: .bold), 0),
            ("^#{3} .+$", .monospacedSystemFont(ofSize: 17, weight: .semibold), 0),
            ("^#{4} .+$", .monospacedSystemFont(ofSize: 15, weight: .semibold), 0),
        ]
        for (pattern, font, _) in headerPatterns {
            applyRegex(pattern, options: [.anchorsMatchLines], to: storage, text: text, attrs: [
                .font: font,
                .foregroundColor: NSColor.controlAccentColor
            ])
        }

        // Bold: **text**
        applyRegex(#"\*\*[^*]+\*\*"#, to: storage, text: text, attrs: [
            .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .bold),
            .foregroundColor: NSColor.labelColor
        ])

        // Italic: _text_ or *text*
        applyRegex(#"(?<!\*)\*(?!\*)[^*]+\*(?!\*)"#, to: storage, text: text, attrs: [
            .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .regular).italic(),
            .foregroundColor: NSColor.labelColor
        ])

        // Inline code: `code`
        applyRegex(#"`[^`\n]+`"#, to: storage, text: text, attrs: [
            .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular),
            .foregroundColor: NSColor.systemGreen,
            .backgroundColor: NSColor.systemGreen.withAlphaComponent(0.08)
        ])

        // Block code: ``` fences
        applyRegex(#"```[\s\S]*?```"#, to: storage, text: text, attrs: [
            .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular),
            .foregroundColor: NSColor.systemGreen,
            .backgroundColor: NSColor.systemGreen.withAlphaComponent(0.06)
        ])

        // Blockquote: > text
        applyRegex("^> .+$", options: [.anchorsMatchLines], to: storage, text: text, attrs: [
            .foregroundColor: NSColor.secondaryLabelColor,
            .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .regular).italic()
        ])

        // List markers: - / * / + / 1.
        applyRegex(#"^(\s*[-*+]|\s*\d+\.)\s"#, options: [.anchorsMatchLines], to: storage, text: text, attrs: [
            .foregroundColor: NSColor.controlAccentColor,
            .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .semibold)
        ])

        // Links: [label](url)
        applyRegex(#"\[.+?\]\(.+?\)"#, to: storage, text: text, attrs: [
            .foregroundColor: NSColor.systemBlue,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ])

        storage.endEditing()
    }

    private func applyRegex(
        _ pattern: String,
        options: NSRegularExpression.Options = [],
        to storage: NSTextStorage,
        text: String,
        attrs: [NSAttributedString.Key: Any]
    ) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return }
        let range = NSRange(text.startIndex..., in: text)
        for match in regex.matches(in: text, range: range) {
            storage.addAttributes(attrs, range: match.range)
        }
    }
}

private extension NSFont {
    func italic() -> NSFont {
        let descriptor = fontDescriptor.withSymbolicTraits(.italic)
        return NSFont(descriptor: descriptor, size: pointSize) ?? self
    }
}
