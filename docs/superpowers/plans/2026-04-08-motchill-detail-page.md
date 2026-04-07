# Motchill Detail Page Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the detail screen so it surfaces all real data returned by `GET /api/movie/:slug` in a clear cinematic layout on mobile.

**Architecture:** Keep `DetailController` as the fetch/state layer, keep `DetailView` as the layout orchestrator, and split the UI into small section widgets for hero, metadata, description, chips, episodes, gallery, and related rail. Prefer hiding empty sections over inventing placeholder content so the page always reflects the API truth.

**Tech Stack:** Flutter, GetX, `flutter_test`

---

### Task 1: Add detail screen coverage first

**Files:**
- Modify: `mobile-api-base/test/models_test.dart`
- Create: `mobile-api-base/test/detail_view_test.dart`

- [ ] **Step 1: Write the failing test**

Add a widget test that pumps `DetailView` with a fake repository returning a `MovieDetail` containing:

- `movie.title = Oppenheimer`
- `movie.otherName = `Oppenheimer (2023)``
- `movie.bannerThumb`, `movie.banner`
- `movie.description`
- `movie.director`
- `movie.castString`
- `movie.showTimes`
- `movie.moreInfo`
- `movie.trailer`
- non-empty `countries`, `categories`, `episodes`, `relatedMovies`, `photoUrls`, `previewPhotos`

Assert that the following are rendered:

```dart
expect(find.text('Oppenheimer'), findsOneWidget);
expect(find.text('2023'), findsWidgets);
expect(find.textContaining('Christopher Nolan'), findsOneWidget);
expect(find.textContaining('Cillian Murphy'), findsOneWidget);
expect(find.textContaining('Biography'), findsOneWidget);
expect(find.textContaining('Countries'), findsOneWidget);
expect(find.textContaining('Categories'), findsOneWidget);
expect(find.textContaining('Episodes'), findsOneWidget);
expect(find.textContaining('Related'), findsOneWidget);
```

- [ ] **Step 2: Run the test to verify it fails**

Run:

```bash
cd mobile-api-base && flutter test test/detail_view_test.dart
```

Expected: fail because the current `DetailView` does not yet render the full data-first layout.

- [ ] **Step 3: Keep the model test aligned**

If the model test is missing any field assertion for `photoUrls`, `previewPhotos`, or `ratePoint`, extend `mobile-api-base/test/models_test.dart` so it verifies the parser already supports the fields the new UI needs.

- [ ] **Step 4: Re-run tests**

Run:

```bash
cd mobile-api-base && flutter test test/detail_view_test.dart test/models_test.dart
```

Expected: still failing until the UI is implemented.

### Task 2: Rebuild the detail screen as a data-first cinematic layout

**Files:**
- Modify: `mobile-api-base/lib/features/detail/detail_view.dart`
- Modify: `mobile-api-base/lib/features/detail/detail_controller.dart` only if a tiny state tweak is needed

- [ ] **Step 1: Write the minimal implementation**

Refactor `DetailView` into a scrollable page with these sections in order:

1. Hero banner using `bannerThumb` fallback to `banner`
2. Title / other name / metadata chips
3. Description
4. Extra info block for `director`, `castString`, `showTimes`, `moreInfo`, `trailer`
5. `countries` and `categories` chips
6. `episodes` list
7. `photoUrls` / `previewPhotos` gallery
8. `relatedMovies` rail

Hide each section when its data is empty. Keep loading and error states intact. Reuse the existing GetX controller and repository flow.

- [ ] **Step 2: Run the widget test**

Run:

```bash
cd mobile-api-base && flutter test test/detail_view_test.dart
```

Expected: PASS after the layout is rebuilt.

- [ ] **Step 3: Run the full test suite**

Run:

```bash
cd mobile-api-base && flutter test
```

Expected: PASS.

### Task 3: Polish and verify navigation edges

**Files:**
- Modify: `mobile-api-base/lib/app/routes/app_pages.dart` only if a detail route edge case appears
- Modify: `mobile-api-base/lib/features/home/home_view.dart` only if detail navigation needs a small adjustment
- Modify: `mobile-api-base/lib/features/category/category_view.dart` only if related movie taps need route alignment

- [ ] **Step 1: Verify tap targets still navigate to detail**

Confirm tapping a movie from home, category, or related rail opens the new detail page with the correct slug.

- [ ] **Step 2: Run the full test suite again**

Run:

```bash
cd mobile-api-base && flutter test
```

Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add mobile-api-base/lib/features/detail/detail_view.dart \
  mobile-api-base/lib/features/detail/detail_controller.dart \
  mobile-api-base/test/detail_view_test.dart \
  mobile-api-base/test/models_test.dart \
  docs/superpowers/plans/2026-04-08-motchill-detail-page.md
git commit -m "feat: rebuild detail page with full api data"
```
