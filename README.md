# ClearNote

A distraction-free, macOS-native Markdown editor with iCloud sync — built with Swift 6, SwiftUI, and SwiftData.

![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-blue)
![Swift](https://img.shields.io/badge/swift-6.0-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## Features

| Feature | Status |
|---|---|
| Hierarchical folder tree (sidebar) | ✅ |
| Create / Rename / Delete folders & notes | ✅ |
| Drag notes into folders | ✅ |
| Recursive sub-folders | ✅ |
| Live search (title + content) | ✅ |
| Markdown editor with syntax highlighting | ✅ |
| Markdown Preview (rendered) | ✅ |
| Edit / Split / Preview mode toggle | ✅ |
| Bidirectional scroll sync (split view) | ✅ |
| Table of contents with heading navigation | ✅ |
| Zen mode | ✅ |
| Light / Dark theme | ✅ |
| Export as `.md` and `.pdf` | ✅ |
| Keyboard shortcuts | ✅ |
| iCloud CloudKit sync | ✅ (requires Apple Developer account) |

## Requirements

- macOS 14.0 Sonoma or later
- Xcode 15+
- Swift 6.0+

## Getting Started

### 1. Clone and open

```bash
git clone https://github.com/your-username/ClearNote.git
cd ClearNote
```

### 2. Configure signing

Copy the signing template and fill in your own Apple Developer details:

```bash
cp Configuration/Signing.xcconfig.template Configuration/Signing.xcconfig
```

Edit `Configuration/Signing.xcconfig`:

```
DEVELOPMENT_TEAM = YOUR_TEAM_ID
PRODUCT_BUNDLE_IDENTIFIER = com.yourname.clearnote
```

> **Finding your Team ID:** Xcode → Settings → Accounts → select your Apple ID → Team ID column. Or visit [developer.apple.com/account](https://developer.apple.com/account) → Membership.

`Signing.xcconfig` is gitignored and will never be committed.

### 3. Build and run

```bash
open ClearNote.xcodeproj
```

Press **⌘R** to build and run.

## iCloud / CloudKit Setup

The app is pre-configured for CloudKit sync. To enable it with your own account:

1. In Xcode, select the ClearNote target → **Signing & Capabilities**
2. Add the **iCloud** capability and enable **CloudKit**
3. Set the container identifier to match your bundle ID: `iCloud.com.yourname.clearnote`
4. Update `ClearNote.entitlements` with your container identifier
5. Sign with your Apple Developer account

Local functionality works fully without these steps.

## Keyboard Shortcuts

| Shortcut | Action |
|---|---|
| `⌘N` | New Note |
| `⌘⇧N` | New Folder |
| `⌘B` | Bold |
| `⌘I` | Italic |
| `⌘⇧T` | Table of Contents |
| `⌘⇧Z` | Zen Mode |
| `⌘⇧E` | Export as Markdown |

## Project Structure

```
Sources/ClearNote/
├── ClearNoteApp.swift          # @main entry point, ModelContainer setup
├── Models/
│   ├── Note.swift              # SwiftData Note model
│   └── Folder.swift            # SwiftData Folder model (recursive)
├── Views/
│   ├── ContentView.swift       # NavigationSplitView root
│   ├── Sidebar/
│   │   ├── SidebarView.swift   # Search + folder tree + toolbar
│   │   ├── FolderRowView.swift # Recursive folder rows, rename, drop target
│   │   ├── NoteRowView.swift   # Note rows with title / preview / date
│   │   ├── NoteTransferable.swift  # Drag-and-drop payload
│   │   └── SearchResultsView.swift # Filtered note list
│   └── Editor/
│       ├── EditorView.swift          # Edit/Split/Preview toggle, auto-save, toolbar
│       ├── SyntaxTextEditor.swift    # NSTextView wrapper with syntax highlighting
│       ├── MarkdownHighlighter.swift # Markdown highlighting rules
│       ├── MarkdownPreviewView.swift # Rendered markdown (AttributedString)
│       ├── ScrollSyncManager.swift   # Bidirectional scroll sync
│       └── EmptyStateView.swift      # No-selection placeholder
└── Utilities/
    ├── ThemeManager.swift      # Light/dark theme with UserDefaults persistence
    ├── ExportService.swift     # .md and .pdf export via NSSavePanel
    └── AppCommands.swift       # macOS menu bar commands
```

## Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) before submitting a pull request.

## License

ClearNote is available under the MIT license. See [LICENSE](LICENSE) for details.
