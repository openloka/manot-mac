import SwiftUI
import AppKit

/// A syntax-highlighted markdown editor backed by NSTextView.
/// Highlights: Headers (blue/bold), Bold (**), Italic (_), `code`, URLs
struct SyntaxTextEditor: NSViewRepresentable {
    @Binding var text: String
    var onChange: () -> Void
    var scrollSyncManager: ScrollSyncManager?
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - NSViewRepresentable

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else { return scrollView }

        context.coordinator.textView = textView
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = true
        textView.isContinuousSpellCheckingEnabled = true
        textView.font = NSFont.systemFont(ofSize: 14, weight: .regular)
        textView.textContainerInset = NSSize(width: 24, height: 24)
        textView.textContainer?.lineFragmentPadding = 0
        textView.string = text

        // Styling
        textView.backgroundColor = NSColor.textBackgroundColor
        scrollView.backgroundColor = NSColor.textBackgroundColor

        // Line wrapping
        textView.textContainer?.widthTracksTextView = true
        textView.isHorizontallyResizable = false

        applyHighlighting(to: textView)
        
        if let scrollSyncManager = scrollSyncManager {
            scrollSyncManager.editorScrollView = scrollView
        }
        
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        if let scrollSyncManager = scrollSyncManager {
            scrollSyncManager.editorScrollView = scrollView
        }

        guard let textView = scrollView.documentView as? NSTextView else { return }
        guard let storage = textView.textStorage else { return }
        // Bail early if nothing changed — avoids any unnecessary work.
        guard storage.string != text else { return }

        // Using textView.string = … destroys scroll position because AppKit
        // treats it as a full document reload. Replacing via NSTextStorage is
        // an incremental edit that preserves layout, scroll, and selection.
        let fullRange = NSRange(location: 0, length: storage.length)
        storage.beginEditing()
        storage.replaceCharacters(in: fullRange, with: text)
        storage.endEditing()

        applyHighlighting(to: textView)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: SyntaxTextEditor
        weak var textView: NSTextView?
        private var highlightTask: Task<Void, Never>?

        init(_ parent: SyntaxTextEditor) {
            self.parent = parent
            super.init()
            
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleInsertMarkdown(_:)),
                name: NSNotification.Name("insertMarkdown"),
                object: nil
            )
            
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleJumpToRange(_:)),
                name: NSNotification.Name("jumpToRange"),
                object: nil
            )
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        @MainActor
        @objc func handleInsertMarkdown(_ notification: Notification) {
            guard let textView = textView,
                  let window = textView.window,
                  window.isKeyWindow,
                  let userInfo = notification.userInfo,
                  let prefix = userInfo["prefix"] as? String,
                  let suffix = userInfo["suffix"] as? String else { return }
            
            // Force focus back to the text view if a toolbar button was clicked
            if window.firstResponder != textView {
                window.makeFirstResponder(textView)
            }
            
            let range = textView.selectedRange()
            let selectedText = (textView.string as NSString).substring(with: range)
            let replacementText = prefix + selectedText + suffix
            
            if textView.shouldChangeText(in: range, replacementString: replacementText) {
                textView.replaceCharacters(in: range, with: replacementText)
                textView.didChangeText()
                
                // Move cursor correctly
                if selectedText.isEmpty {
                    // Place cursor between prefix and suffix
                    let newPos = range.location + prefix.count
                    textView.setSelectedRange(NSRange(location: newPos, length: 0))
                } else {
                    // Select the wrapped text (keep internal selection)
                    let newRange = NSRange(location: range.location + prefix.count, length: selectedText.count)
                    textView.setSelectedRange(newRange)
                }
            }
        }

        @MainActor
        @objc func handleJumpToRange(_ notification: Notification) {
            guard let textView = textView,
                  let window = textView.window,
                  window.isKeyWindow,
                  let userInfo = notification.userInfo,
                  let range = userInfo["range"] as? NSRange else { return }
            
            textView.setSelectedRange(range)
            textView.scrollRangeToVisible(range)
            
            if window.firstResponder != textView {
                window.makeFirstResponder(textView)
            }
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
        guard let storage = textView.textStorage else { return }
        let text = storage.string

        var highlighter = MarkdownHighlighter(storage: storage, text: text)
        highlighter.highlight()
    }
}
