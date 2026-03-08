# Localization Expansion Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add polished Japanese, Traditional Chinese, French, German, Greek, Italian, Spanish, Korean, Russian, and Portuguese translations for every string key in `Localizable.xcstrings` while maintaining the single-file JSON structure.

**Architecture:** Keep using the JSON-style `Localizable.xcstrings` file as the truth. Each string key will have a `localizations` dictionary listing `en`, `zh-Hans`, `ja`, `zh-Hant`, `fr`, `de`, `el`, `it`, `es`, `ko`, `ru`, and `pt`. The new entries must contain fully translated human copy and maintain any `%lld` or `…` placeholders.

**Tech Stack:** Swift localization via `.xcstrings`, `xcstrings` compiler (part of the Swift toolchain), `xcodebuild` to verify builds.

---

### Task 1: Scaffold the new language entries

**Files:**
- Modify: `CelestialPDFs/Localizable.xcstrings`

**Step 1: Write the failing test/check**

```text
Manual check: `Localizable.xcstrings` currently contains translations for `en` and `zh-Hans` only. Expectation: each key should now also contain keys for ja, zh-Hant, fr, de, el, it, es, ko, ru, pt.
```

**Step 2: Confirm failure**

Run: `rg -c '"ja"' CelestialPDFs/Localizable.xcstrings`. Expected: counts less than number of keys.

**Step 3: Add scaffolding**

- For every key, add `localizations` entries for the new languages with placeholder copies identical to English (will replace with polished translations later).
- Ensure JSON structure stays valid (preserve existing entries). Use script or manual editing.

**Step 4: Re-run check**

Run: `rg -c '"ja"' CelestialPDFs/Localizable.xcstrings` again; it should now match other language counts.

**Step 5: Commit**

```bash
git add CelestialPDFs/Localizable.xcstrings
git commit -m "i18n: add language scaffolding to Localizable"
```

### Task 2: Translate the strings

**Files:**
- Modify: `CelestialPDFs/Localizable.xcstrings`

**Step 1: Write the failing test/check**

```text
Manual inspection: new language entries are identical to English placeholders; they must be replaced with context-aware translations.
```

**Step 2: Translate strings**

- Replace the placeholder values for each new language with polished translations (ja, zh-Hant, fr, de, el, it, es, ko, ru, pt) for every key.
- Keep spacing, punctuation, and placeholder formats consistent.
- Consider grouping by screen to keep phrasing consistent.

**Step 3: Validate JSON**

Run: `swiftc -dump-parseable-module-localized-strings CelestialPDFs/Localizable.xcstrings` (or rely on `xcodebuild build` later) to ensure syntactic correctness.

**Step 4: Spot-check languages**

Pick 2-3 keys and verify translations make sense (e.g., “Ask AI” vs local language). Optionally run `xcodebuild build` after translation to ensure `xcstrings` compiles.

**Step 5: Commit**

```bash
git add CelestialPDFs/Localizable.xcstrings
git commit -m "i18n: add new language translations"
```

### Task 3: Verification & documentation

**Files:**
- Test: not file-based (manual verification)

**Step 1: Run build**

Run: `xcodebuild -project CelestialPDFs.xcodeproj -scheme CelestialPDFs -configuration Debug build`
Expected: PASS.

**Step 2: Manual spot checks**

Launch the app (or use previews) in each new language if practical to confirm strings render correctly.

**Step 3: Document progress (if needed)**

Note any remaining outstanding translations in `docs/plans/…` or commit message.

**Step 4: Commit documentation/notes**

If any notes were added to `docs`, stage and commit them.

**Step 5: Final review/merge prep**

Ensure working tree only contains intended changes, then prep for merge (no additional commits needed here).
