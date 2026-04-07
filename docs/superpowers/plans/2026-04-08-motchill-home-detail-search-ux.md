# Motchill Home Detail Search UX Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make home, detail, and search feel like one connected browsing flow: hero and rail actions jump into contextual search, detail content is organized into horizontal tabs with local likes, and search can locally filter liked results.

**Architecture:** Keep the existing GetX + repository structure and add one small shared persistence layer for liked movie IDs. Home only becomes a routing surface, detail owns tab selection and the like toggle, and search owns the local liked-results filter while still using the existing server-driven search API. Route parameters stay simple so the new behavior can be tested with small widget and controller tests.

**Tech Stack:** Flutter, GetX, shared_preferences, flutter_test

---

### Task 1: Add a shared local like store

**Files:**
- Create: `mobile-api-base/lib/core/storage/liked_movie_store.dart`
- Modify: `mobile-api-base/lib/app/bindings/initial_binding.dart`
- Test: `mobile-api-base/test/core/storage/liked_movie_store_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
test('liked movie store persists liked ids and toggles membership', () async {
  SharedPreferences.setMockInitialValues({});
  final store = LikedMovieStore();

  expect(await store.loadIds(), isEmpty);
  expect(await store.isLiked(42), isFalse);

  await store.toggle(42);
  expect(await store.isLiked(42), isTrue);

  await store.toggle(42);
  expect(await store.isLiked(42), isFalse);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile-api-base && flutter test test/core/storage/liked_movie_store_test.dart -r expanded`
Expected: FAIL because `LikedMovieStore` does not exist yet.

- [ ] **Step 3: Write minimal implementation**

```dart
class LikedMovieStore {
  static const _key = 'liked_movie_ids';

  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  Future<Set<int>> loadIds() async {
    final prefs = await _prefs();
    return prefs.getStringList(_key)?.map(int.parse).toSet() ?? <int>{};
  }

  Future<bool> isLiked(int movieId) async {
    return (await loadIds()).contains(movieId);
  }

  Future<Set<int>> toggle(int movieId) async {
    final prefs = await _prefs();
    final ids = await loadIds();
    if (!ids.add(movieId)) {
      ids.remove(movieId);
    }
    await prefs.setStringList(_key, ids.map((id) => id.toString()).toList());
    return ids;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile-api-base && flutter test test/core/storage/liked_movie_store_test.dart -r expanded`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add mobile-api-base/lib/core/storage/liked_movie_store.dart mobile-api-base/lib/app/bindings/initial_binding.dart mobile-api-base/test/core/storage/liked_movie_store_test.dart
git commit -m "feat: add local liked movie store"
```

### Task 2: Route home entry points into contextual search

**Files:**
- Modify: `mobile-api-base/lib/features/home/home_view.dart`
- Modify: `mobile-api-base/lib/features/search/search_controller.dart`
- Modify: `mobile-api-base/lib/features/search/search_view.dart`
- Test: `mobile-api-base/test/home_view_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
testWidgets('hero filter and rail view-all open search with presets', (tester) async {
  await tester.pumpWidget(
    GetMaterialApp(
      initialRoute: '/',
      getPages: [
        GetPage(name: '/', page: () => const HomeView()),
        GetPage(name: '/search', page: () => const SearchView(), binding: SearchBinding()),
      ],
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.text('Bộ lọc'));
  await tester.pumpAndSettle();
  expect(Get.currentRoute, '/search');

  Get.back();
  await tester.pumpAndSettle();

  await tester.tap(find.text('Xem tất cả').last);
  await tester.pumpAndSettle();
  expect(Get.parameters['slug'], 'phim-trung-quoc');
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile-api-base && flutter test test/home_view_test.dart -r expanded`
Expected: FAIL because `Bộ lọc` does not route yet and `Xem tất cả` is still a no-op.

- [ ] **Step 3: Write minimal implementation**

```dart
void _openSearch([Map<String, String>? parameters, String? title]) {
  Get.toNamed(AppRoutes.search, parameters: parameters, arguments: title);
}

// Hero button:
onPressed: () => _openSearch(),

// Rail button:
onPressed: () => _openSearch(
  {'slug': section.key.isNotEmpty ? section.key : _slugFromTitle(section.title)},
  section.title,
),
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile-api-base && flutter test test/home_view_test.dart -r expanded`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add mobile-api-base/lib/features/home/home_view.dart mobile-api-base/lib/features/search/search_controller.dart mobile-api-base/lib/features/search/search_view.dart mobile-api-base/test/home_view_test.dart
git commit -m "feat: route home actions into search"
```

### Task 3: Tabify detail content and wire local like state

**Files:**
- Modify: `mobile-api-base/lib/features/detail/detail_controller.dart`
- Modify: `mobile-api-base/lib/features/detail/detail_view.dart`
- Modify: `mobile-api-base/lib/app/routes/app_pages.dart` if route args need a dedicated preset
- Test: `mobile-api-base/test/detail_view_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
testWidgets('detail screen defaults to episodes tab and toggles like locally', (tester) async {
  await tester.pumpWidget(
    GetMaterialApp(
      initialRoute: '/detail/oppenheimer',
      getPages: [
        GetPage(name: '/detail/:slug', page: () => const DetailView(), binding: DetailBinding()),
        GetPage(name: '/play/:movieId/:episodeId', page: () => const Scaffold(body: Text('player screen'))),
      ],
    ),
  );
  await tester.pumpAndSettle();

  expect(find.text('Episodes'), findsWidgets);
  expect(find.text('Synopsis'), findsNothing);

  await tester.tap(find.byIcon(Icons.favorite_border_rounded));
  await tester.pumpAndSettle();
  expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile-api-base && flutter test test/detail_view_test.dart -r expanded`
Expected: FAIL because there is no tab state and the like button is inert.

- [ ] **Step 3: Write minimal implementation**

```dart
enum DetailSectionTab { episodes, synopsis, information, classification, gallery, related }

// In controller:
final selectedTab = DetailSectionTab.episodes.obs;
final isLiked = false.obs;

Future<void> toggleLike() async {
  isLiked.value = !isLiked.value;
  await _likedMovieStore.toggle(detail.value!.id);
}

void selectInitialTab(MovieDetail detail) {
  selectedTab.value = detail.episodes.isNotEmpty
      ? DetailSectionTab.episodes
      : DetailSectionTab.synopsis;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile-api-base && flutter test test/detail_view_test.dart -r expanded`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add mobile-api-base/lib/features/detail/detail_controller.dart mobile-api-base/lib/features/detail/detail_view.dart mobile-api-base/lib/app/routes/app_pages.dart mobile-api-base/test/detail_view_test.dart
git commit -m "feat: organize detail screen into tabs"
```

### Task 4: Add liked-only filtering to search results

**Files:**
- Modify: `mobile-api-base/lib/features/search/search_controller.dart`
- Modify: `mobile-api-base/lib/features/search/search_view.dart`
- Modify: `mobile-api-base/lib/core/storage/liked_movie_store.dart`
- Test: `mobile-api-base/test/features/search/search_controller_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
test('liked filter hides unliked results without changing the API payload', () async {
  final controller = SearchController(repository, likedMovieStore: store);
  await controller.load();
  await controller.toggleLikedOnly();

  expect(controller.visibleMovies.map((movie) => movie.id), [1]);
  expect(controller.totalRecords, 2);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile-api-base && flutter test test/features/search/search_controller_test.dart -r expanded`
Expected: FAIL because there is no local liked-only filter yet.

- [ ] **Step 3: Write minimal implementation**

```dart
final showLikedOnly = false.obs;

List<MovieCard> get visibleMovies {
  final movies = moviesFromApi;
  if (!showLikedOnly.value) return movies;
  return movies.where((movie) => likedIds.contains(movie.id)).toList(growable: false);
}

Future<void> toggleLikedOnly() async {
  showLikedOnly.value = !showLikedOnly.value;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile-api-base && flutter test test/features/search/search_controller_test.dart -r expanded`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add mobile-api-base/lib/features/search/search_controller.dart mobile-api-base/lib/features/search/search_view.dart mobile-api-base/lib/core/storage/liked_movie_store.dart mobile-api-base/test/features/search/search_controller_test.dart
git commit -m "feat: filter liked search results locally"
```

### Task 5: Refresh docs and changelog

**Files:**
- Modify: `mobile-api-base/CHANGELOG.md`
- Modify: `docs/superpowers/specs/2026-04-08-motchill-mobile-handoff.md`

- [ ] **Step 1: Add release notes**

Update `Unreleased` with:

```md
### Added

- Local liked-movie persistence and liked-only search filtering.
- Contextual search routing from home hero and rail actions.
- Tabbed detail content with a local like toggle.

### Changed

- Home hero filter button now opens search.
- Rail `Xem tất cả` actions now open search with the originating section preset.
- Detail app bar now keeps only back and like actions.
```

- [ ] **Step 2: Add handoff notes**

Add a short note that search now supports a liked-only local post-filter and that detail owns the shared like state through `LikedMovieStore`.

- [ ] **Step 3: Verify the doc text is consistent with the implementation**

Run: `rg -n "LikedMovieStore|liked-only|Xem tất cả|Bộ lọc|tabs" mobile-api-base/CHANGELOG.md docs/superpowers/specs/2026-04-08-motchill-mobile-handoff.md`

- [ ] **Step 4: Commit**

```bash
git add mobile-api-base/CHANGELOG.md docs/superpowers/specs/2026-04-08-motchill-mobile-handoff.md
git commit -m "docs: update motchill UX handoff"
```
