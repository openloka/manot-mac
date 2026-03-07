# ClearNote

A distraction-free, macOS-native Markdown editor with iCloud sync — built with Swift 6, SwiftUI, and SwiftData.

## Features

| Feature | Status |
|---|---|
| Hierarchical folder tree (sidebar) | ✅ |
| Create / Rename / Delete folders & notes | ✅ |
| Drag notes into folders | ✅ |
| Recursive sub-folders | ✅ |
| Live search (title + content) | ✅ |
| Markdown editor with auto-save | ✅ |
| Markdown Preview (rendered) | ✅ |
| Edit / Split / Preview mode toggle | ✅ |
| Keyboard shortcuts (⌘N, ⌘⇧N, ⌘B) | ✅ |
| Export as `.md` | ✅ |
| Export as `.pdf` | ✅ |
| iCloud CloudKit sync | ✅ (requires dev account setup) |
| Glassmorphism sidebar | ✅ |

## Opening in Xcode

```bash
open Package.swift
```

Then press **⌘R** to build and run.

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
│       ├── EditorView.swift    # Edit/Split/Preview toggle, auto-save, toolbar
│       ├── MarkdownPreviewView.swift  # Rendered markdown (AttributedString)
│       └── EmptyStateView.swift       # No-selection placeholder
└── Utilities/
    ├── ExportService.swift     # .md and .pdf export via NSSavePanel
    └── AppCommands.swift       # macOS menu bar commands
```

## Keyboard Shortcuts

| Shortcut | Action |
|---|---|
| `⌘N` | New Note |
| `⌘⇧N` | New Folder |
| `⌘B` | Bold (inserts `****`) |
| `⌘⇧E` | Export as Markdown |

## iCloud Setup (CloudKit)

The app is pre-configured for CloudKit sync. To enable it:

1. Open `Package.swift` in Xcode
2. Go to **Signing & Capabilities** for the ClearNote target
3. Add **iCloud** capability → enable **CloudKit**
4. Set the container identifier: `iCloud.com.yourname.ClearNote`
5. Sign with your Apple Developer account

Local functionality works fully without this step.

## Requirements

- macOS 14.0 Sonoma or later
- Xcode 15+ (for building)
- Swift 6.0+
