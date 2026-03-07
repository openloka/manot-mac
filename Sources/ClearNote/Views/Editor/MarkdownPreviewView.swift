import SwiftUI

struct MarkdownPreviewView: View {
    let content: String

    var body: some View {
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
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    @ViewBuilder
    private var renderedContent: some View {
        let lines = content.components(separatedBy: "\n")
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                lineView(for: line)
            }
        }
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
        } else if line.hasPrefix("```") || line.hasPrefix("    ") {
            codeBlockLine(line)
        } else if line.hasPrefix("> ") {
            blockquoteLine(String(line.dropFirst(2)))
        } else if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ") {
            listItemLine(String(line.dropFirst(2)))
        } else if line.trimmingCharacters(in: .whitespaces).isEmpty {
            Spacer().frame(height: 8)
        } else {
            if let attr = try? AttributedString(markdown: line,
                                                options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
                Text(attr)
                    .font(.body)
                    .lineSpacing(3)
                    .textSelection(.enabled)
            } else {
                Text(line)
                    .font(.body)
                    .textSelection(.enabled)
            }
        }
    }

    @ViewBuilder
    private func codeBlockLine(_ line: String) -> some View {
        let code = line.hasPrefix("    ") ? String(line.dropFirst(4)) : line
        Text(code)
            .font(.system(.body, design: .monospaced))
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.textBackgroundColor).opacity(0.6))
            )
            .textSelection(.enabled)
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
        (try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(text)
    }
}
