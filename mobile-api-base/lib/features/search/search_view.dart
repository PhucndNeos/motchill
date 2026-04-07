import 'package:flutter/material.dart' hide SearchController;
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../core/widgets/motchill_network_image.dart';
import '../../core/widgets/tv_focusable.dart';
import '../../data/models/motchill_models.dart';
import '../../data/models/motchill_search_models.dart';
import 'search_controller.dart';

class SearchView extends GetView<SearchController> {
  const SearchView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF131313), Color(0xFF101010), Color(0xFF050505)],
          ),
        ),
        child: SafeArea(
          child: Obx(() {
            if (controller.isLoading.value && controller.results.value == null) {
              return const Center(child: CircularProgressIndicator());
            }

            if (controller.errorMessage.value != null &&
                controller.results.value == null) {
              return _SearchErrorState(
                message: controller.errorMessage.value!,
                onRetry: controller.refresh,
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: _SearchHeader(
                    onBack: Get.back,
                    title: controller.screenTitle,
                    subtitle: controller.screenSubtitle,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _SearchBar(
                    controller: controller.searchInputController,
                    showClearButton:
                        controller.searchInputValue.value.isNotEmpty,
                    onSubmitted: controller.submitSearch,
                    onClear: controller.clearSearch,
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _FilterStrip(
                    categoryLabel: controller.selectedCategoryLabel.value,
                    countryLabel: controller.selectedCountryLabel.value,
                    typeLabel: controller.selectedTypeLabel.value,
                    year: controller.selectedYear.value,
                    likedOnlySelected: controller.showLikedOnly.value,
                    orderLabel: controller.currentOrderLabel,
                    onPickCategory: () => _pickCategory(context),
                    onPickCountry: () => _pickCountry(context),
                    onPickType: () => _pickType(context),
                    onPickYear: () => _pickYear(context),
                    onToggleLikedOnly: controller.toggleLikedOnly,
                    onPickOrder: () => _pickOrder(context),
                    onClearCategory: controller.clearCategory,
                    onClearCountry: controller.clearCountry,
                    onClearType: controller.clearTypeRaw,
                    onClearYear: controller.clearYear,
                    onClearOrder: controller.clearOrderBy,
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Obx(() {
                    final movies = controller.visibleMovies;
                    return _ResultsHeader(
                      count: movies.length,
                      currentPage: controller.currentPage,
                      totalPages: controller.totalPages,
                      isUpdating: controller.isSearching.value,
                      canGoPrevious: controller.canGoPrevious,
                      canGoNext: controller.canGoNext,
                      onPrevious: controller.canGoPrevious
                          ? () => controller.goToPage(
                              controller.currentPage - 1,
                            )
                          : null,
                      onNext: controller.canGoNext
                          ? () => controller.goToPage(
                              controller.currentPage + 1,
                            )
                          : null,
                    );
                  }),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: controller.refresh,
                    child: Obx(() {
                      final movies = controller.visibleMovies;
                      final hasError = controller.errorMessage.value != null;

                      if (hasError && movies.isEmpty) {
                        return ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            const SizedBox(height: 24),
                            _SearchErrorState(
                              message: controller.errorMessage.value!,
                              onRetry: controller.refresh,
                            ),
                          ],
                        );
                      }

                      if (movies.isEmpty) {
                        return ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [
                            SizedBox(height: 96),
                            Center(
                              child: Text(
                                'Chưa có nội dung phù hợp',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ),
                          ],
                        );
                      }

                      return CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                            sliver: SliverGrid(
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: 180,
                                    mainAxisSpacing: 14,
                                    crossAxisSpacing: 14,
                                    childAspectRatio: 0.62,
                                  ),
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final movie = movies[index];
                                  return _SearchMovieCard(movie: movie);
                                },
                                childCount: movies.length,
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Future<void> _pickCategory(BuildContext context) async {
    final selected = await Get.bottomSheet<SearchFacetOption?>(
      _FacetPickerSheet(
        title: 'Chọn thể loại',
        options: controller.categoryOptionsWithAll,
        selectedId: controller.selectedCategoryId.value ?? 0,
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );

    if (selected == null) return;
    await controller.selectCategory(selected);
  }

  Future<void> _pickCountry(BuildContext context) async {
    final selected = await Get.bottomSheet<SearchFacetOption?>(
      _FacetPickerSheet(
        title: 'Chọn quốc gia',
        options: controller.countryOptionsWithAll,
        selectedId: controller.selectedCountryId.value ?? 0,
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );

    if (selected == null) return;
    await controller.selectCountry(selected);
  }

  Future<void> _pickType(BuildContext context) async {
    final selected = await Get.bottomSheet<SearchChoice?>(
      _ChoicePickerSheet(
        title: 'Loại phim',
        options: controller.typeOptions,
        selectedValue: controller.selectedTypeRaw.value,
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );

    if (selected == null) return;
    await controller.selectTypeRaw(selected);
  }

  Future<void> _pickYear(BuildContext context) async {
    final selected = await Get.bottomSheet<SearchChoice?>(
      _ChoicePickerSheet(
        title: 'Năm phát hành',
        options: controller.yearOptions,
        selectedValue: controller.selectedYear.value,
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );

    if (selected == null) return;
    await controller.selectYear(selected);
  }

  Future<void> _pickOrder(BuildContext context) async {
    final selected = await Get.bottomSheet<SearchChoice?>(
      _ChoicePickerSheet(
        title: 'Sắp xếp',
        options: controller.orderOptions,
        selectedValue: controller.selectedOrderBy.value,
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );

    if (selected == null) return;
    await controller.selectOrderBy(selected.value);
  }
}

class _SearchHeader extends StatelessWidget {
  const _SearchHeader({
    required this.onBack,
    required this.title,
    required this.subtitle,
  });

  final VoidCallback onBack;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton(
          onPressed: onBack,
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (subtitle.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.showClearButton,
    required this.onSubmitted,
    required this.onClear,
  });

  final TextEditingController controller;
  final bool showClearButton;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF2E2E2E)),
      ),
      child: TextField(
        controller: controller,
        onSubmitted: onSubmitted,
        style: const TextStyle(color: Colors.white),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Tìm phim, tập phim, diễn viên...',
          hintStyle: const TextStyle(color: Colors.white38),
          prefixIcon: const Icon(Icons.search_rounded, color: Colors.white54),
          suffixIcon: showClearButton
              ? IconButton(
                  onPressed: () {
                    controller.clear();
                    onClear();
                  },
                  icon: const Icon(Icons.close_rounded, color: Colors.white54),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }
}

class _FilterStrip extends StatelessWidget {
  const _FilterStrip({
    required this.categoryLabel,
    required this.countryLabel,
    required this.typeLabel,
    required this.year,
    required this.likedOnlySelected,
    required this.orderLabel,
    required this.onPickCategory,
    required this.onPickCountry,
    required this.onPickType,
    required this.onPickYear,
    required this.onToggleLikedOnly,
    required this.onPickOrder,
    required this.onClearCategory,
    required this.onClearCountry,
    required this.onClearType,
    required this.onClearYear,
    required this.onClearOrder,
  });

  final String categoryLabel;
  final String countryLabel;
  final String typeLabel;
  final String year;
  final bool likedOnlySelected;
  final String orderLabel;
  final VoidCallback onPickCategory;
  final VoidCallback onPickCountry;
  final VoidCallback onPickType;
  final VoidCallback onPickYear;
  final VoidCallback onToggleLikedOnly;
  final VoidCallback onPickOrder;
  final VoidCallback onClearCategory;
  final VoidCallback onClearCountry;
  final VoidCallback onClearType;
  final VoidCallback onClearYear;
  final VoidCallback onClearOrder;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _FilterChip(
          key: const Key('search.filter.category'),
          label: categoryLabel.isEmpty ? 'Thể loại' : categoryLabel,
          selected: categoryLabel.isNotEmpty,
          onTap: onPickCategory,
          onClear: categoryLabel.isNotEmpty ? onClearCategory : null,
        ),
        _FilterChip(
          key: const Key('search.filter.country'),
          label: countryLabel.isEmpty ? 'Quốc gia' : countryLabel,
          selected: countryLabel.isNotEmpty,
          onTap: onPickCountry,
          onClear: countryLabel.isNotEmpty ? onClearCountry : null,
        ),
        _FilterChip(
          key: const Key('search.filter.type'),
          label: typeLabel.isEmpty ? 'Loại phim' : typeLabel,
          selected: typeLabel.isNotEmpty,
          onTap: onPickType,
          onClear: typeLabel.isNotEmpty ? onClearType : null,
        ),
        _FilterChip(
          key: const Key('search.filter.year'),
          label: year.isEmpty ? 'Năm' : year,
          selected: year.isNotEmpty,
          onTap: onPickYear,
          onClear: year.isNotEmpty ? onClearYear : null,
        ),
        _FilterChip(
          key: const Key('search.filter.likedOnly'),
          label: 'Đã thích',
          selected: likedOnlySelected,
          onTap: onToggleLikedOnly,
        ),
        _FilterChip(
          key: const Key('search.filter.order'),
          label: orderLabel,
          selected: true,
          onTap: onPickOrder,
          onClear: onClearOrder,
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.onClear,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      focusedBorderColor: const Color(0xFF31D39C),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFE50914).withValues(alpha: 0.20)
              : const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? const Color(0xFFE50914).withValues(alpha: 0.30)
                : const Color(0xFF303030),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? const Color(0xFFFFD4D0) : Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (onClear != null) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onClear,
                child: const Icon(
                  Icons.close_rounded,
                  color: Colors.white54,
                  size: 16,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ResultsHeader extends StatelessWidget {
  const _ResultsHeader({
    required this.count,
    required this.currentPage,
    required this.totalPages,
    required this.isUpdating,
    required this.canGoPrevious,
    required this.canGoNext,
    required this.onPrevious,
    required this.onNext,
  });

  final int count;
  final int currentPage;
  final int totalPages;
  final bool isUpdating;
  final bool canGoPrevious;
  final bool canGoNext;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF171717),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF2D2D2D)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              count > 0 ? '$count kết quả' : 'Không có kết quả',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (isUpdating) ...[
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 8),
          ],
          IconButton(
            onPressed: canGoPrevious ? onPrevious : null,
            icon: const Icon(Icons.chevron_left_rounded),
            color: Colors.white,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 36, height: 36),
          ),
          IconButton(
            onPressed: canGoNext ? onNext : null,
            icon: const Icon(Icons.chevron_right_rounded),
            color: Colors.white,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 36, height: 36),
          ),
          const SizedBox(width: 4),
          Text(
            totalPages == 0 ? 'Trang $currentPage' : 'Trang $currentPage/$totalPages',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _SearchMovieCard extends StatelessWidget {
  const _SearchMovieCard({required this.movie});

  final MovieCard movie;

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      onTap: () {
        if (movie.link.trim().isEmpty) return;
        Get.toNamed(
          AppRoutes.detail.replaceFirst(
            ':slug',
            Uri.encodeComponent(movie.link),
          ),
        );
      },
      borderRadius: BorderRadius.circular(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _PosterImage(url: movie.displayPoster),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.48),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (movie.rating.isNotEmpty)
                    Positioned(
                      left: 10,
                      top: 10,
                      child: _RatingBadge(text: movie.rating),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            movie.displayTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            movie.displaySubtitle.isNotEmpty
                ? movie.displaySubtitle
                : movie.statusTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white60, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _PosterImage extends StatelessWidget {
  const _PosterImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return Container(
        color: const Color(0xFF1C1B1B),
        alignment: Alignment.center,
        child: const Icon(
          Icons.movie_outlined,
          color: Colors.white38,
          size: 42,
        ),
      );
    }

    return MotchillNetworkImage(url: url);
  }
}

class _RatingBadge extends StatelessWidget {
  const _RatingBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFE50914).withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: const Color(0xFFE50914).withValues(alpha: 0.2),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFFFFB4AA),
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _FacetPickerSheet extends StatefulWidget {
  const _FacetPickerSheet({
    required this.title,
    required this.options,
    required this.selectedId,
  });

  final String title;
  final List<SearchFacetOption> options;
  final int? selectedId;

  @override
  State<_FacetPickerSheet> createState() => _FacetPickerSheetState();
}

class _FacetPickerSheetState extends State<_FacetPickerSheet> {
  late List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _focusNodes = _buildFocusNodes(widget.options.length, 'search.facet');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.options.isEmpty) return;
      _focusOption(_initialIndex());
    });
  }

  @override
  void didUpdateWidget(covariant _FacetPickerSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.options.length != widget.options.length) {
      for (final node in _focusNodes) {
        node.dispose();
      }
      _focusNodes = _buildFocusNodes(widget.options.length, 'search.facet');
    }
  }

  @override
  void dispose() {
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  List<FocusNode> _buildFocusNodes(int count, String prefix) {
    return List<FocusNode>.generate(
      count,
      (index) => FocusNode(debugLabel: '$prefix.$index'),
    );
  }

  int _initialIndex() {
    final selectedIndex = widget.options.indexWhere(
      (option) => option.id == widget.selectedId,
    );
    return selectedIndex >= 0 ? selectedIndex : 0;
  }

  void _focusOption(int index) {
    if (index < 0 || index >= _focusNodes.length) return;
    _focusNodes[index].requestFocus();
  }

  bool _isActivate(KeyEvent event) {
    return event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.select ||
        event.logicalKey == LogicalKeyboardKey.space;
  }

  KeyEventResult _handleKey(int index, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (_isActivate(event)) {
      Get.back<SearchFacetOption?>(result: widget.options[index]);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (index > 0) _focusOption(index - 1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (index < _focusNodes.length - 1) _focusOption(index + 1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF141414),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: FocusTraversalGroup(
          policy: WidgetOrderTraversalPolicy(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 420),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemBuilder: (context, index) {
                    final option = widget.options[index];
                    final isSelected = option.id == widget.selectedId;
                    return _FocusablePickerRow(
                      focusNode: _focusNodes[index],
                      onKeyEvent: (node, event) => _handleKey(index, event),
                      selected: isSelected,
                      title: option.name,
                      subtitle: option.slug.isNotEmpty ? option.slug : null,
                      trailing: isSelected
                          ? const Icon(Icons.check_rounded, color: Colors.white)
                          : null,
                      onTap: () => Get.back<SearchFacetOption?>(result: option),
                    );
                  },
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemCount: widget.options.length,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Get.back<SearchFacetOption?>(result: null),
                  child: const Text('Đóng'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChoicePickerSheet extends StatefulWidget {
  const _ChoicePickerSheet({
    required this.title,
    required this.options,
    required this.selectedValue,
  });

  final String title;
  final List<SearchChoice> options;
  final String selectedValue;

  @override
  State<_ChoicePickerSheet> createState() => _ChoicePickerSheetState();
}

class _ChoicePickerSheetState extends State<_ChoicePickerSheet> {
  late List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _focusNodes = _buildFocusNodes(widget.options.length, 'search.choice');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.options.isEmpty) return;
      _focusOption(_initialIndex());
    });
  }

  @override
  void didUpdateWidget(covariant _ChoicePickerSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.options.length != widget.options.length) {
      for (final node in _focusNodes) {
        node.dispose();
      }
      _focusNodes = _buildFocusNodes(widget.options.length, 'search.choice');
    }
  }

  @override
  void dispose() {
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  List<FocusNode> _buildFocusNodes(int count, String prefix) {
    return List<FocusNode>.generate(
      count,
      (index) => FocusNode(debugLabel: '$prefix.$index'),
    );
  }

  int _initialIndex() {
    final selectedIndex = widget.options.indexWhere(
      (option) => option.value == widget.selectedValue,
    );
    return selectedIndex >= 0 ? selectedIndex : 0;
  }

  void _focusOption(int index) {
    if (index < 0 || index >= _focusNodes.length) return;
    _focusNodes[index].requestFocus();
  }

  bool _isActivate(KeyEvent event) {
    return event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.select ||
        event.logicalKey == LogicalKeyboardKey.space;
  }

  KeyEventResult _handleKey(int index, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (_isActivate(event)) {
      Get.back<SearchChoice?>(result: widget.options[index]);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (index > 0) _focusOption(index - 1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (index < _focusNodes.length - 1) _focusOption(index + 1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF141414),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: FocusTraversalGroup(
          policy: WidgetOrderTraversalPolicy(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 420),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemBuilder: (context, index) {
                    final option = widget.options[index];
                    final isSelected = option.value == widget.selectedValue;
                    return _FocusablePickerRow(
                      focusNode: _focusNodes[index],
                      onKeyEvent: (node, event) => _handleKey(index, event),
                      selected: isSelected,
                      title: option.label,
                      subtitle: null,
                      trailing: isSelected
                          ? const Icon(Icons.check_rounded, color: Colors.white)
                          : null,
                      onTap: () => Get.back<SearchChoice?>(result: option),
                    );
                  },
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemCount: widget.options.length,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Get.back<SearchChoice?>(result: null),
                  child: const Text('Đóng'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FocusablePickerRow extends StatelessWidget {
  const _FocusablePickerRow({
    required this.focusNode,
    required this.onKeyEvent,
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
  });

  final FocusNode focusNode;
  final KeyEventResult Function(FocusNode node, KeyEvent event) onKeyEvent;
  final bool selected;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      focusNode: focusNode,
      onKeyEvent: onKeyEvent,
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      focusedBorderColor: const Color(0xFFE8A7A7),
      focusedBackgroundColor: const Color(0xFF251717),
      focusScale: 1.01,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF171717),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? const Color(0xFFE8A7A7) : const Color(0xFF2D2D2D),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[trailing!],
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchErrorState extends StatelessWidget {
  const _SearchErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 56, color: Colors.white70),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => onRetry(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
