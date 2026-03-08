# Localization Expansion Design

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:writing-plans to create the implementation plan after this design.

**Goal:** Add polished Japanese, Traditional Chinese, French, German, Greek, Italian, Spanish, Korean, Russian, and Portuguese translations for every existing key in `Localizable.xcstrings` while keeping a single JSON-like source of truth.

**Architecture:** Continue using the centralized `Localizable.xcstrings` file (JSON-style). For each key, include a `localizations` dictionary covering `en`, `zh-Hans`, and the new languages. For existing `zh-Hans` entries keep the same values. The file will remain a single truth from which localized `.strings` are derived during builds.

**Tech Stack:** SwiftUI localization using `.xcstrings` JSON format; builds rely on existing `xcstrings` compilation tool.

---

### Details
1. **Coverage:** Every current key (toolbar labels, panel headings, prompts, settings) will gain translations in our new languages. No keys will be left untranslated. Each localization entry will be marked as `translated` with carefully tailored wording.
2. **Consistency:** Placeholders and formatting (`%lld`, `…`, synonyms) will be preserved across languages and reviewed for natural phrasing (e.g., `Search title or author…` becomes « Rechercher un titre ou un auteur… » in French). Japanese and Traditional Chinese will use culturally appropriate punctuation/quotes.
3. **Maintainability:** Keep the JSON structure uniform—each key has `localizations` with the same set of language keys. New language translations will be introduced inline so future edits only touch one file. The doc will reference these languages explicitly to avoid confusion.
4. **Validation:** After editing, verify via `xcodebuild ... build` (already part of existing workflow) and optionally run a quick snippet to ensure `xcstrings` compiles. No automated translation, just manual curated strings.

Is this design ready to proceed?EOF