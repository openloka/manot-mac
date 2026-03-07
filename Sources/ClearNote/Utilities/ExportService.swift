import AppKit
import Foundation

@MainActor
enum ExportService {
    // MARK: - Export as Markdown

    static func exportAsMarkdown(note: Note) {
        let panel = NSSavePanel()
        panel.title = "Export as Markdown"
        panel.nameFieldStringValue = sanitizedFileName(note.title) + ".md"
        panel.allowedContentTypes = [.plainText]
        panel.canCreateDirectories = true

        if panel.runModal() == .OK, let url = panel.url {
            do {
                try note.content.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                showAlert("Export Failed", message: error.localizedDescription)
            }
        }
    }

    // MARK: - Export as PDF

    static func exportAsPDF(note: Note) {
        let panel = NSSavePanel()
        panel.title = "Export as PDF"
        panel.nameFieldStringValue = sanitizedFileName(note.title) + ".pdf"
        panel.allowedContentTypes = [.pdf]
        panel.canCreateDirectories = true

        if panel.runModal() == .OK, let url = panel.url {
            let content = note.title + "\n\n" + note.content
            let data = NSMutableData()

            guard let consumer = CGDataConsumer(data: data as CFMutableData),
                  let context = CGContext(consumer: consumer, mediaBox: nil, nil)
            else {
                showAlert("Export Failed", message: "Could not create PDF context.")
                return
            }

            let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842) // A4
            context.beginPDFPage(nil)

            let attrString = NSAttributedString(
                string: content,
                attributes: [
                    .font: NSFont.systemFont(ofSize: 12),
                    .foregroundColor: NSColor.textColor
                ]
            )
            let framesetter = CTFramesetterCreateWithAttributedString(attrString)
            let path = CGPath(rect: CGRect(x: 40, y: 40, width: pageRect.width - 80, height: pageRect.height - 80), transform: nil)
            let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: 0, length: 0), path, nil)
            CTFrameDraw(frame, context)

            context.endPDFPage()
            context.closePDF()

            do {
                try (data as Data).write(to: url)
            } catch {
                showAlert("Export Failed", message: error.localizedDescription)
            }
        }
    }

    // MARK: - Helpers

    private static func sanitizedFileName(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:*?\"<>|")
        return name
            .components(separatedBy: invalid)
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespaces)
            .isEmpty ? "Untitled" : name
    }

    private static func showAlert(_ title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }
}
