# Celestial PDF 🌌

**Celestial PDF** is a native macOS PDF bookshelf and deep-reading tool. It combines elegant skeuomorphic design, a powerful PDFKit reading engine, and advanced AI-powered assistance to provide a premium digital reading and knowledge management experience.

## ✨ Core Features

### 📚 Exquisite Bookshelf
- **Skeuomorphic Visuals**: A grid layout with realistic shelf dividers and gradient shadows for an immersive reading atmosphere.
- **Auto-Thumbnails**: Automatic cover generation via PDFKit with intelligent aspect-ratio awareness and center-cropping.
- **Smart Management**: Recursive subdirectory scanning, keyword search, and multi-dimensional tag filtering.

### 📖 Ultimate Reading Experience
- **Native Engine**: Built on Apple's official PDFKit for industry-leading performance and compatibility.
- **Highlighter**: Permanent highlighting and annotation of selected text.
- **Multi-Scoped Notes**:
  - **Highlight Notes**: Directly attached to specific quoted text.
  - **Page Notes**: Reflections on an entire page.
  - **Book Notes**: Summaries of the core ideas of the book.
- **Markdown Support**: All notes are rendered with Markdown syntax for better expression of your thoughts.
- **Floating Toolbar**: Instant access to actions (Highlight, Lookup, Note, AI) upon text selection.

### 🤖 AI Intelligent Assistant
- **Context-Aware**: Send selected text or current page content directly to the AI as context.
- **Streaming Conversations**: Supports OpenAI-compatible APIs with millisecond-response SSE streaming.
- **Flexible Config**: Customizable API Endpoints, Keys, and Model names.

### 🔤 Vocabulary & Memory
- **Native Dictionary**: Deep integration with macOS Dictionary.app for one-click word lookup.
- **Auto-Vocabulary**: Looked-up words are automatically saved with definitions, source book titles, and page numbers for later review.

### 📊 Personal Profile & Stats
- **Asset Overview**: Real-time tracking of books read, highlights made, notes taken, and vocabulary grown.
- **Personalization**: Custom user avatars, editable names, and a list of recently read books.

## 🛠️ Tech Stack

- **Framework**: SwiftUI (macOS 14.0+)
- **Engines**: PDFKit / AppKit
- **State Management**: Swift Observation (@Observable)
- **Data**: Security-Scoped Bookmarks, JSON Serialization
- **Networking**: URLSession (SSE Streaming)
- **Typography**: Native Markdown rendering (AttributedString)

## 🚀 Getting Started

### Requirements
- macOS Sonoma (14.0) or later
- Xcode 15.0+

### Installation & Run
1. Clone the repository or download the source code.
2. Open `CelestialPDFs.xcodeproj` in Xcode.
3. Select the `CelestialPDFs` Scheme and press **Run** (⌘ + R).

### First-Time Setup
1. **Setup Library**: Click "Select Directory" at the top of the bookshelf to specify your PDF storage folder.
2. **AI Config**: Configure your API Key via `Settings` in the menu bar or the gear icon in the AI panel.
3. **Start Reading**: Click a book cover on the shelf to begin your reading journey.

## 🛡️ Privacy & Security
- **Sandboxed**: Runs within the macOS sandbox, accessing only folders you authorize.
- **Local Storage**: Metadata, notes, and vocabulary are stored locally in the `Application Support` directory and are never uploaded to third-party servers (except for AI chat interactions).

---

Developed with ❤️ by Antigravity AI.
