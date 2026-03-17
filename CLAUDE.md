# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**ManotApp** is a native macOS Markdown editor built with Swift 6, SwiftUI, and SwiftData, targeting macOS 14.0+.

## Build & Run

Open in Xcode and press ⌘R:
```bash
open ManotApp.xcodeproj
```

There is no CLI test runner — tests are run via Xcode (⌘U). No linting configuration exists.

## Dependencies (Swift Package Manager)

- **swift-markdown** — Markdown parsing and rendering
- **HighlighterSwift** — Syntax highlighting for code blocks

## Architecture

The app uses MVVM + SwiftUI with SwiftData for persistence.

**Entry point:** `ManotApp.swift` sets up the `ModelContainer` and `ThemeManager`.

**Layout:** `ContentView` renders a `NavigationSplitView` with `SidebarView` (left) and `EditorView` (right).

### Data Models (`Models/`)
- `Note` — SwiftData model with title, content, timestamps, and optional folder reference
- `Folder` — Self-referential SwiftData model supporting infinite nesting (parent/children relationships)

### Editor (`Views/Editor/`)
- `EditorView` — Orchestrates edit/split/preview modes, auto-save (400ms debounce), and zen mode
- `SyntaxTextEditor` — `NSViewRepresentable` wrapping `NSTextView` with `MarkdownHighlighter` for live syntax highlighting
- `MarkdownPreviewView` — Rendered markdown output using swift-markdown and HighlighterSwift; handles block parsing (code blocks, tables) before rendering
- `ScrollSyncManager` — Bidirectional scroll sync between editor and preview; uses a `syncDepth` counter as a re-entry guard to prevent feedback loops
- `MarkdownHighlighter` — Swift type encapsulating markdown syntax highlighting rules

### Sidebar (`Views/Sidebar/`)
- `SidebarView` — Search bar, folder tree, note list, and create/delete toolbar
- `FolderRowView` — Recursive folder rendering with expand/collapse, rename, and drag-drop support
- `NoteTransferable` / `FolderTransferable` — `Transferable` payloads for drag-and-drop

### Utilities (`Utilities/`)
- `ThemeManager` — `@Observable` class managing light/dark theme; persisted to `UserDefaults`
- `ExportService` — Exports notes as `.md` or `.pdf` via `NSSavePanel`
- `AppCommands` — macOS menu bar commands and keyboard shortcuts (⌘N, ⌘⇧N, ⌘B, ⌘I, ⌘⇧T, ⌘⇧Z)

### Cross-View Communication
`NotificationCenter` is used for decoupled communication between components — for example, heading navigation from the Table of Contents view into the editor, and markdown insertion commands.

## Swift 6 Concurrency

The project uses `.swiftLanguageMode(.v6)` in `Package.swift`. All shared state must be `@MainActor`-bound or use `Sendable`-conforming types. Pay attention to actor isolation when touching `NSView`/`AppKit` APIs.

## iCloud / CloudKit

The app is configured with CloudKit entitlements (`ManotApp.entitlements`) but sync is not yet enabled in production. The `ModelContainer` is set up to support CloudKit when activated.
