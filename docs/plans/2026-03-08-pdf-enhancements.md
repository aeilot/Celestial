# PDF Reader Enhancements Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add 8 enhancements to improve PDF reading experience: lazy loading, sidebar sizing, fit modes, floating toolbar config, shelf stats, i18n system language, tag UI, and subfolder UI.

**Architecture:** Incremental improvements to existing SwiftUI views. Each feature is independent and can be implemented separately. Focus on minimal code changes to existing architecture.

**Tech Stack:** SwiftUI, PDFKit, UserDefaults for settings, Localizable.xcstrings for i18n

---

## Current State Analysis

**Already Implemented:**
- Tags exist in PDFBook model and are displayed in list view
- Subfolders exist in BookStore.allFolders and sidebar
- i18n infrastructure exists (Localizable.xcstrings created)
- Floating toolbar exists but positioning needs fix

**Needs Implementation:**
- Lazy PDF loading (currently loads immediately)
- Sidebar max width constraint
- PDF fit width/fit page modes
- Floating toolbar toggle setting
- Stats display at shelf bottom
- System language detection for i18n
- Tag editing UI
- Subfolder display improvements

---


## Implementation Tasks

### Task 1: Lazy PDF Loading
**Priority:** High (Performance)
**Files:** `PDFReaderView.swift`, `PDFKitView.swift`
**Changes:**
- Defer PDF document loading until view appears
- Show loading indicator while document loads
- Load document in background Task

### Task 2: Enlarge Note Sidebar
**Priority:** Medium (UX)
**Files:** `PDFReaderView.swift`
**Changes:**
- Change right panel max width from 400 to half window width
- Use GeometryReader to calculate dynamic max width

### Task 3: PDF Fit Modes
**Priority:** High (Core Feature)
**Files:** `PDFReaderView.swift`, `PDFKitView.swift`
**Changes:**
- Add fit mode enum: `.fitWidth`, `.fitPage`, `.autoScale`
- Add toolbar buttons to switch modes
- Update PDFView scaling mode

### Task 4: Floating Toolbar Configuration
**Priority:** Medium (UX)
**Files:** `PDFReaderView.swift`, `SettingsView.swift`
**Changes:**
- Add UserDefaults setting for showing floating toolbar
- Fix positioning to 5px above selection (currently incorrect)
- Add settings toggle

### Task 5: Shelf Stats Display
**Priority:** Low (Polish)
**Files:** `BookshelfView.swift`
**Changes:**
- Add stats footer at bottom of ScrollView
- Show book count centered

### Task 6: i18n System Language Matching
**Priority:** Medium (i18n)
**Files:** `Localizable.xcstrings`, all View files
**Changes:**
- Expand string catalog with all hardcoded strings
- SwiftUI automatically uses system language
- Add more translations

### Task 7: Tag Editing UI
**Priority:** Medium (Feature)
**Files:** `BookDetailSheet.swift`
**Changes:**
- Add tag input field with chips
- Allow adding/removing tags
- Show tag suggestions from existing tags

### Task 8: Subfolder UI Improvements
**Priority:** Low (Polish)
**Files:** `ContentView.swift` (SidebarView)
**Changes:**
- Already implemented with indentation
- Could add folder icons and expand/collapse

## Implementation Order

1. Task 1 (Lazy loading) - Critical for performance
2. Task 4 (Fix floating toolbar position) - Bug fix
3. Task 3 (PDF fit modes) - High value feature
4. Task 2 (Sidebar width) - Quick UX improvement
5. Task 7 (Tag editing) - Complete existing feature
6. Task 5 (Shelf stats) - Quick polish
7. Task 6 (i18n completion) - Localize remaining strings
8. Task 8 (Subfolder polish) - Optional enhancement
