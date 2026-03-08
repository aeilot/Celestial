# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Celestial PDF is a native macOS PDF bookshelf and deep-reading application built with SwiftUI. It combines PDFKit for rendering, AI-powered reading assistance, and comprehensive note-taking capabilities.

**Key Technologies:**
- SwiftUI (macOS 14.0+) with Swift Observation (@Observable)
- PDFKit for PDF rendering and manipulation
- Security-scoped bookmarks for sandboxed file access
- URLSession with SSE streaming for AI chat
- JSON serialization for data persistence

## Building and Running

**Open and run:**
```bash
open CelestialPDFs.xcodeproj
# Then press ⌘+R in Xcode to build and run
```

**Build from command line:**
```bash
xcodebuild -project CelestialPDFs.xcodeproj -scheme CelestialPDFs -configuration Debug build
```

**Clean build:**
```bash
xcodebuild -project CelestialPDFs.xcodeproj -scheme CelestialPDFs clean
```

## Architecture

### Core State Management

**BookStore** (`Models/BookStore.swift`) is the central @Observable state container injected via `.environment()`. It manages:
- Book library with security-scoped bookmark persistence
- Thumbnail caching (two-tier: NSCache memory + disk JPEG)
- Background directory scanning with progress tracking
- Highlights, notes, and vocabulary across all books
- User profile data via UserDefaults

All data persists to `~/Library/Application Support/CelestialPDFs/`:
- `library.json` - book metadata, highlights, notes
- `vocabulary.json` - looked-up words
- `thumbnails/` - cached cover images

### View Hierarchy

```
CelestialPDFsApp
└── ContentView (sidebar + main content router)
    ├── BookshelfView (grid of BookCardView)
    ├── NotesListView (all notes across books)
    ├── VocabularyView (word lookup history)
    └── StatsView (reading statistics)

PDFReaderView (opened when book selected)
├── PDFKitView (AppKit PDFView wrapper)
├── Floating toolbar (appears on text selection)
└── Right panels:
    ├── ReaderNotesView (highlight/page/book notes)
    └── AIChatView (AI assistant with context)
```

### Key Patterns

**Thumbnail Rendering:**
- `cachedThumbnail(for:)` - fast, main-thread safe, cache-only lookup
- `renderAndCacheThumbnail(for:)` - background rendering with aspect-ratio cropping
- Pre-warming happens automatically after directory scans via `Task.detached(priority: .utility)`

**Security-Scoped Resources:**
- Library directory access uses bookmarks saved to UserDefaults
- Always call `startAccessingSecurityScopedResource()` when resolving bookmarks
- File paths stored as relative paths from library root

**AI Service:**
- Supports OpenAI-compatible APIs with streaming (SSE) and non-streaming fallback
- Automatically retries non-streaming if streaming fails
- Context injection: selected text or current page content
- Settings stored in UserDefaults: `ai_endpoint`, `ai_api_key`, `ai_model`

## Data Models

**PDFBook** - Core book entity with:
- `fileName`: relative path from library root (supports subdirectories)
- `highlights`: array of text selections with bounds and page index
- `notes`: array with scope (highlight/page/book level)
- `lastOpened`: tracks reading history

**BookHighlight** - Stores selection bounds in PDF coordinate space for overlay rendering

**BookNote** - Three scopes via enum:
- `.highlight(UUID)` - attached to specific highlight
- `.page(Int)` - reflections on a page
- `.book` - overall book summary

**VocabularyEntry** - Words looked up via Dictionary.app with source book/page tracking

## Common Tasks

**Adding a new book metadata field:**
1. Add property to `PDFBook` struct in `Models/PDFBook.swift`
2. Update `BookDetailSheet.swift` if user-editable
3. Migration happens automatically (Codable uses default values)

**Modifying thumbnail generation:**
- Edit `renderAndCacheThumbnail(for:size:)` in `BookStore.swift`
- Clear cache: delete `~/Library/Application Support/CelestialPDFs/thumbnails/`
- Memory cache auto-evicts under pressure (NSCache)

**Changing AI behavior:**
- System prompt: `AIService.sendMessage()` in `Services/AIService.swift`
- Context injection: modify how `context` parameter is built in `AIChatView.swift`
- Streaming parsing: `sendStreamingRequest()` handles SSE format

**Adding new note scopes:**
- Extend `NoteScope` enum in `Models/PDFBook.swift`
- Update `scopeDescription` computed property
- Modify `ReaderNotesView.swift` UI accordingly

## Important Constraints

**Sandboxing:**
- App runs in macOS sandbox with user-selected directory entitlement
- Cannot access files outside user-authorized library directory
- Use security-scoped bookmarks for persistent access

**PDFKit Threading:**
- PDF rendering must happen on background threads
- Use `@MainActor` or `Task.detached` appropriately
- Thumbnail generation is CPU-intensive - always background

**Chinese Localization:**
- UI strings are hardcoded in Chinese
- Error messages in `AIService` are Chinese
- Consider this when adding new user-facing text

## File Organization

```
CelestialPDFs/
├── CelestialPDFsApp.swift       # App entry point
├── ContentView.swift             # Main navigation router
├── Models/
│   ├── PDFBook.swift            # Core data models
│   └── BookStore.swift          # Central state container
├── Services/
│   ├── AIService.swift          # OpenAI-compatible chat
│   └── DictionaryService.swift  # macOS Dictionary integration
└── Views/
    ├── BookshelfView.swift      # Grid layout with search/filter
    ├── BookCardView.swift       # Individual book card
    ├── PDFReaderView.swift      # Main reading interface
    ├── PDFKitView.swift         # AppKit PDFView wrapper
    ├── ReaderNotesView.swift    # Note-taking panel
    ├── AIChatView.swift         # AI assistant panel
    ├── VocabularyView.swift     # Word history
    ├── NotesListView.swift      # All notes view
    ├── StatsView.swift          # Reading statistics
    ├── BookDetailSheet.swift    # Edit book metadata
    └── SettingsView.swift       # AI configuration
```
