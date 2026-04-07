import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/models/motchill_models.dart';
import '../../data/models/motchill_search_models.dart';
import '../../data/repositories/motchill_repository.dart';
import '../../core/storage/liked_movie_store.dart';

class SearchController extends GetxController {
  SearchController(
    this._repository, {
    LikedMovieStore? likedMovieStore,
    bool initialLikedOnly = false,
  }) : _likedMovieStore = likedMovieStore ?? Get.find<LikedMovieStore>(),
       _initialLikedOnly = initialLikedOnly {
    showLikedOnly.value = initialLikedOnly;
  }

  final MotchillRepository _repository;
  final LikedMovieStore _likedMovieStore;
  final searchInputController = TextEditingController();

  final filters = Rxn<SearchFilterData>();
  final results = Rxn<SearchResults>();
  final isLoading = true.obs;
  final isSearching = false.obs;
  final errorMessage = RxnString();
  final searchText = ''.obs;
  final searchInputValue = ''.obs;
  final selectedCategoryId = RxnInt();
  final selectedCategoryLabel = ''.obs;
  final selectedCountryId = RxnInt();
  final selectedCountryLabel = ''.obs;
  final selectedTypeRaw = ''.obs;
  final selectedTypeLabel = ''.obs;
  final selectedYear = ''.obs;
  final selectedOrderBy = 'UpdateOn'.obs;
  final showLikedOnly = false.obs;
  final likedMovieIds = <int>{}.obs;
  final likedMovies = <MovieCard>[].obs;
  final bool _initialLikedOnly;

  String _initialSlug = '';
  String _initialQuery = '';
  String _initialLabel = '';
  bool _presetApplied = false;

  @override
  void onInit() {
    super.onInit();
    _initialSlug = (Get.parameters['slug'] ?? '').trim();
    _initialQuery = (Get.parameters['q'] ?? '').trim();
    _initialLabel = Get.arguments is String
        ? (Get.arguments as String).trim()
        : '';

    searchInputController.text = _initialQuery;
    searchText.value = _initialQuery;
    searchInputValue.value = _initialQuery;
    selectedCategoryLabel.value = _initialLabel;
    showLikedOnly.value = _initialLikedOnly;
    searchInputController.addListener(() {
      searchInputValue.value = searchInputController.text;
    });

    load();
  }

  @override
  void onClose() {
    searchInputController.dispose();
    super.onClose();
  }

  Future<void> load() async {
    isLoading.value = true;
    errorMessage.value = null;

    try {
      await _loadLikedMovies();
      final filterData = await _repository.loadSearchFilters();
      filters.value = filterData;
      _applyPresetCategory(filterData);
      await _search(pageNumber: 1);
    } catch (error) {
      errorMessage.value = error.toString();
    } finally {
      isLoading.value = false;
    }
  }

  @override
  Future<void> refresh() => load();

  Future<void> submitSearch([String? value]) async {
    final nextValue = (value ?? searchInputController.text).trim();
    searchInputController.text = nextValue;
    searchInputController.selection = TextSelection.collapsed(
      offset: nextValue.length,
    );
    searchText.value = nextValue;
    searchInputValue.value = nextValue;
    await _search(pageNumber: 1);
  }

  Future<void> clearSearch() => submitSearch('');

  Future<void> selectCategory(SearchFacetOption? option) async {
    if (option == null || !option.hasId || option.id <= 0) {
      await clearCategory();
      return;
    }

    selectedCategoryId.value = option.id;
    selectedCategoryLabel.value = option.name;
    await _search(pageNumber: 1);
  }

  Future<void> selectCountry(SearchFacetOption? option) async {
    if (option == null || !option.hasId || option.id <= 0) {
      await clearCountry();
      return;
    }

    selectedCountryId.value = option.id;
    selectedCountryLabel.value = option.name;
    await _search(pageNumber: 1);
  }

  Future<void> selectTypeRaw(SearchChoice? choice) async {
    final value = choice?.value.trim() ?? '';
    if (value.isEmpty) {
      await clearTypeRaw();
      return;
    }

    selectedTypeRaw.value = value;
    selectedTypeLabel.value = choice?.label.trim() ?? '';
    await _search(pageNumber: 1);
  }

  Future<void> selectYear(SearchChoice? choice) async {
    final value = choice?.value.trim() ?? '';
    if (value.isEmpty) {
      await clearYear();
      return;
    }

    selectedYear.value = value;
    await _search(pageNumber: 1);
  }

  Future<void> selectOrderBy(String value) async {
    selectedOrderBy.value = value;
    await _search(pageNumber: 1);
  }

  Future<void> toggleLikedOnly() async {
    await _loadLikedMovies();
    showLikedOnly.toggle();
  }

  Future<void> goToPage(int pageNumber) async {
    await _search(pageNumber: pageNumber);
  }

  SearchFilterData? get filterData => filters.value;

  List<SearchFacetOption> get categoryOptions =>
      filters.value?.categories ?? const <SearchFacetOption>[];

  List<SearchFacetOption> get countryOptions =>
      filters.value?.countries ?? const <SearchFacetOption>[];

  List<SearchFacetOption> get categoryOptionsWithAll {
    if (categoryOptions.isEmpty) {
      return const <SearchFacetOption>[
        SearchFacetOption(id: 0, name: 'Tất cả', slug: ''),
      ];
    }

    final first = categoryOptions.first;
    if (first.id == 0 && first.name.trim().toLowerCase() == 'tất cả') {
      return categoryOptions;
    }

    return <SearchFacetOption>[
      const SearchFacetOption(id: 0, name: 'Tất cả', slug: ''),
      ...categoryOptions,
    ];
  }

  List<SearchFacetOption> get countryOptionsWithAll {
    if (countryOptions.isEmpty) {
      return const <SearchFacetOption>[
        SearchFacetOption(id: 0, name: 'Tất cả', slug: ''),
      ];
    }

    final first = countryOptions.first;
    if (first.id == 0 && first.name.trim().toLowerCase() == 'tất cả') {
      return countryOptions;
    }

    return <SearchFacetOption>[
      const SearchFacetOption(id: 0, name: 'Tất cả', slug: ''),
      ...countryOptions,
    ];
  }

  List<SearchChoice> get typeOptions => const <SearchChoice>[
    SearchChoice(value: '', label: 'Tất cả'),
    SearchChoice(value: 'single', label: 'Phim Lẻ'),
    SearchChoice(value: 'series', label: 'Phim Bộ'),
  ];

  List<SearchChoice> get yearOptions => const <SearchChoice>[
    SearchChoice(value: '', label: 'Tất cả'),
    SearchChoice(value: '2025', label: '2025'),
    SearchChoice(value: '2024', label: '2024'),
    SearchChoice(value: '2023', label: '2023'),
    SearchChoice(value: '2022', label: '2022'),
    SearchChoice(value: '2021', label: '2021'),
    SearchChoice(value: '2020', label: '2020'),
    SearchChoice(value: '2019', label: '2019'),
    SearchChoice(value: '2018', label: '2018'),
    SearchChoice(value: '2017', label: '2017'),
    SearchChoice(value: '2016', label: '2016'),
    SearchChoice(value: '2015', label: '2015'),
    SearchChoice(value: '2014', label: '2014'),
    SearchChoice(value: '2013', label: '2013'),
    SearchChoice(value: '2012', label: '2012'),
    SearchChoice(value: '2011', label: '2011'),
    SearchChoice(value: '2010', label: '2010'),
  ];

  List<SearchChoice> get orderOptions => const <SearchChoice>[
    SearchChoice(value: 'UpdateOn', label: 'Mới Nhất'),
    SearchChoice(value: 'ViewNumber', label: 'Lượt Xem'),
    SearchChoice(value: 'Year', label: 'Năm Phát Hành'),
  ];

  List<MovieCard> get movies => results.value?.records ?? const <MovieCard>[];

  List<MovieCard> get visibleMovies {
    if (!showLikedOnly.value) return movies;

    final query = searchText.value.trim().toLowerCase();
    final source = likedMovies;
    if (query.isEmpty) {
      return source;
    }

    return source
        .where((movie) => _matchesQuery(movie, query))
        .toList(growable: false);
  }

  int get currentPage => results.value?.pagination.pageIndex ?? 1;

  int get totalPages => results.value?.pagination.pageCount ?? 0;

  int get totalRecords => results.value?.pagination.totalRecords ?? 0;

  bool get canGoPrevious => currentPage > 1;

  bool get canGoNext => totalPages > 0 && currentPage < totalPages;

  String get screenTitle {
    return 'Tìm kiếm phim';
  }

  String get screenSubtitle {
    final parts = <String>[];

    final keyword = searchText.value.trim();
    if (keyword.isNotEmpty) {
      parts.add('Từ khóa: "$keyword"');
    }

    if (selectedCountryLabel.value.trim().isNotEmpty) {
      parts.add(selectedCountryLabel.value.trim());
    }

    if (selectedTypeLabel.value.trim().isNotEmpty) {
      parts.add('Loại: ${selectedTypeLabel.value.trim()}');
    }

    if (selectedYear.value.trim().isNotEmpty) {
      parts.add('Năm: ${selectedYear.value.trim()}');
    }

    if (parts.isEmpty && selectedCategoryLabel.value.trim().isNotEmpty) {
      return 'Lọc theo danh mục và từ khóa';
    }

    if (showLikedOnly.value) {
      parts.add('Đã thích');
    }

    if (parts.isEmpty) return 'Nhập từ khóa hoặc chọn bộ lọc';
    return parts.join(' • ');
  }

  String get currentOrderLabel => _orderLabel(selectedOrderBy.value);

  Future<void> clearCategory() async {
    selectedCategoryId.value = null;
    selectedCategoryLabel.value = '';
    await _search(pageNumber: 1);
  }

  Future<void> clearCountry() async {
    selectedCountryId.value = null;
    selectedCountryLabel.value = '';
    await _search(pageNumber: 1);
  }

  Future<void> clearTypeRaw() async {
    selectedTypeRaw.value = '';
    selectedTypeLabel.value = '';
    await _search(pageNumber: 1);
  }

  Future<void> clearYear() async {
    selectedYear.value = '';
    await _search(pageNumber: 1);
  }

  Future<void> clearOrderBy() async {
    selectedOrderBy.value = 'UpdateOn';
    await _search(pageNumber: 1);
  }

  Future<void> _search({required int pageNumber}) async {
    if (isLoading.value && results.value == null) {
      // Initial load uses the same search pathway, but we keep the loader visible.
    } else {
      isSearching.value = true;
    }

    errorMessage.value = null;

    try {
      results.value = await _repository.loadSearchResults(
        categoryId: selectedCategoryId.value,
        countryId: selectedCountryId.value,
        typeRaw: selectedTypeRaw.value.trim(),
        year: selectedYear.value.trim(),
        orderBy: selectedOrderBy.value,
        search: searchText.value.trim(),
        pageNumber: pageNumber,
      );
    } catch (error) {
      errorMessage.value = error.toString();
    } finally {
      isSearching.value = false;
    }
  }

  Future<void> _loadLikedMovies() async {
    final movies = await _likedMovieStore.loadMovies();
    likedMovieIds
      ..clear()
      ..addAll(movies.map((movie) => movie.id));
    likedMovies
      ..clear()
      ..addAll(movies);
  }

  void _applyPresetCategory(SearchFilterData filterData) {
    if (_presetApplied) return;
    _presetApplied = true;

    final slug = _initialSlug.trim().toLowerCase();
    if (slug.isEmpty || slug == 'motchill' || slug == 'tat-ca') {
      if (selectedCategoryLabel.value.trim().isEmpty &&
          _initialLabel.trim().isNotEmpty) {
        selectedCategoryLabel.value = _initialLabel.trim();
      }
      return;
    }

    for (final option in filterData.categories) {
      if (_matchesSlug(option, slug)) {
        selectedCategoryId.value = option.id;
        selectedCategoryLabel.value = option.name;
        return;
      }
    }

    if (selectedCategoryLabel.value.trim().isEmpty) {
      selectedCategoryLabel.value = _initialLabel.trim().isNotEmpty
          ? _initialLabel.trim()
          : _humanizeSlug(slug);
    }
  }

  bool _matchesSlug(SearchFacetOption option, String slug) {
    final normalizedName = _normalize(option.name);
    final normalizedSlug = _normalize(option.slug);
    return normalizedName == slug ||
        normalizedSlug == slug ||
        _slugify(option.name) == slug ||
        _slugify(option.slug) == slug;
  }

  String _orderLabel(String value) {
    switch (value) {
      case 'ViewCount':
        return 'Lượt xem';
      case 'Year':
        return 'Năm Phát Hành';
      case 'Name':
        return 'Tên';
      case 'UpdateOn':
      default:
        return 'Cập nhật mới';
    }
  }

  String _normalize(String value) => value.trim().toLowerCase();

  String _slugify(String value) {
    return _normalize(value)
        .replaceAll(RegExp(r'[áàạảãăắằặẳẵâấầậẩẫ]'), 'a')
        .replaceAll(RegExp(r'[éèẹẻẽêếềệểễ]'), 'e')
        .replaceAll(RegExp(r'[íìịỉĩ]'), 'i')
        .replaceAll(RegExp(r'[óòọỏõôốồộổỗơớờợởỡ]'), 'o')
        .replaceAll(RegExp(r'[úùụủũưứừựửữ]'), 'u')
        .replaceAll(RegExp(r'[ýỳỵỷỹ]'), 'y')
        .replaceAll(RegExp(r'đ'), 'd')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
  }

  String _humanizeSlug(String value) {
    return value
        .split('-')
        .where((part) => part.isNotEmpty)
        .map(
          (part) => part.length == 1
              ? part.toUpperCase()
              : '${part[0].toUpperCase()}${part.substring(1)}',
        )
        .join(' ');
  }

  bool _matchesQuery(MovieCard movie, String query) {
    final haystacks = <String>[
      movie.displayTitle,
      movie.displaySubtitle,
      movie.description,
      movie.statusTitle,
      movie.link,
    ].map((value) => value.toLowerCase());

    return haystacks.any((value) => value.contains(query));
  }
}
