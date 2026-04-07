import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../core/widgets/motchill_network_image.dart';
import '../../core/widgets/tv_focusable.dart';
import '../../data/models/motchill_models.dart';
import 'home_controller.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  late final HomeController _controller;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = Get.find<HomeController>();
  }

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
            if (_controller.isLoading.value && _controller.sections.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            if (_controller.errorMessage.value != null &&
                _controller.sections.isEmpty) {
              return _ErrorState(
                message: _controller.errorMessage.value!,
                onRetry: _controller.refresh,
              );
            }

            final sections = _controller.sections.toList(growable: false);
            final slideSection = _slideSection(sections);
            final contentSections = _contentSections(sections);
            final slideMovies = slideSection?.products ?? const <MovieCard>[];

            if (slideMovies.isEmpty && contentSections.isEmpty) {
              return _ErrorState(
                message: 'No content available yet.',
                onRetry: _controller.refresh,
              );
            }

            final heroMovies = slideMovies.isNotEmpty
                ? slideMovies
                : contentSections
                      .expand((section) => section.products)
                      .toList(growable: false);
            final clampedIndex = _selectedIndex.clamp(0, heroMovies.length - 1);
            final selectedMovie = heroMovies[clampedIndex];
            final previewMovies = heroMovies
                .where((movie) => movie != selectedMovie)
                .toList(growable: false);

            return RefreshIndicator(
              onRefresh: _controller.refresh,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                      child: _HomeHeroSection(
                        selectedMovie: selectedMovie,
                        previewMovies: previewMovies,
                        onSelectMovie: (movie) {
                          final nextIndex = heroMovies.indexOf(movie);
                          if (nextIndex == -1) return;
                          setState(() {
                            _selectedIndex = nextIndex;
                          });
                        },
                        onTapFavorite: () => Get.toNamed(
                          AppRoutes.search,
                          parameters: const {'likedOnly': 'true'},
                        ),
                        onTapSearch: () => Get.toNamed(AppRoutes.search),
                        onOpen: () => Get.toNamed(
                          AppRoutes.detail.replaceFirst(
                            ':slug',
                            Uri.encodeComponent(selectedMovie.link),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (contentSections.isNotEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      sliver: SliverList.separated(
                        itemBuilder: (context, index) {
                          final section = contentSections[index];
                          return _SectionRail(
                            section: section,
                            onOpenCard: (movie) {
                              if (movie.link.isEmpty) return;
                              Get.toNamed(
                                AppRoutes.detail.replaceFirst(
                                  ':slug',
                                  Uri.encodeComponent(movie.link),
                                ),
                              );
                            },
                          );
                        },
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 22),
                        itemCount: contentSections.length,
                      ),
                    ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}

HomeSection? _slideSection(List<HomeSection> sections) {
  for (final section in sections) {
    if (section.key == 'slide') return section;
  }
  return sections.isEmpty ? null : sections.first;
}

List<HomeSection> _contentSections(List<HomeSection> sections) {
  return sections
      .where((section) => section.key != 'slide')
      .toList(growable: false);
}

String _sectionSearchSlug(HomeSection section) {
  final key = section.key.trim().toLowerCase();
  if (key.isNotEmpty && key != 'slide') {
    return key;
  }

  final normalized = section.title.trim().toLowerCase();
  if (normalized.isEmpty) return '';
  return normalized
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
}

class _HomeHeroSection extends StatelessWidget {
  const _HomeHeroSection({
    required this.selectedMovie,
    required this.previewMovies,
    required this.onSelectMovie,
    required this.onTapFavorite,
    required this.onTapSearch,
    required this.onOpen,
  });

  final MovieCard selectedMovie;
  final List<MovieCard> previewMovies;
  final ValueChanged<MovieCard> onSelectMovie;
  final VoidCallback onTapFavorite;
  final VoidCallback onTapSearch;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: onTapFavorite,
                icon: const Icon(Icons.favorite_border_rounded),
                label: const Text('Favorite'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onTapSearch,
                icon: const Icon(Icons.search_rounded),
                label: const Text('Tìm kiếm'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          height: 280,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            color: const Color(0xFF1A1A1A),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Stack(
              children: [
                if (selectedMovie.displayBanner.isNotEmpty)
                  Positioned.fill(
                    child: MotchillNetworkImage(
                      url: selectedMovie.displayBanner,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      placeholderColor: const Color(0xFF1A1A1A),
                      placeholderIconColor: Colors.white24,
                      errorIconColor: Colors.white38,
                      iconSize: 40,
                    ),
                  ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.22),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          const Color(0xFF131313).withValues(alpha: 0.96),
                          const Color(0xFF131313).withValues(alpha: 0.80),
                          const Color(0xFF131313).withValues(alpha: 0.14),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 20,
                  top: 20,
                  right: 20,
                  child: const Text(
                    'CINEMATIC CHOICE',
                    style: TextStyle(
                      color: Color(0xFFE50914),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        selectedMovie.displayTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          height: 0.96,
                          letterSpacing: -0.6,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        selectedMovie.displaySubtitle.isNotEmpty
                            ? selectedMovie.displaySubtitle
                            : selectedMovie.statusTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          FilledButton.icon(
                            onPressed: onOpen,
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: const Text('Xem ngay'),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton.icon(
                            onPressed: onTapSearch,
                            icon: const Icon(Icons.search_rounded),
                            label: const Text('Tìm kiếm'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 138,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: previewMovies.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final movie = previewMovies[index];
              return _ThumbCard(
                movie: movie,
                onTap: () => onSelectMovie(movie),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SectionRail extends StatelessWidget {
  const _SectionRail({required this.section, required this.onOpenCard});

  final HomeSection section;
  final ValueChanged<MovieCard> onOpenCard;

  void _openAll() {
    final slug = _sectionSearchSlug(section);
    Get.toNamed(
      AppRoutes.search,
      parameters: slug.isEmpty ? null : {'slug': slug},
      arguments: section.title.trim().isNotEmpty ? section.title.trim() : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final products = section.products;
    if (products.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                section.title.isNotEmpty ? section.title : section.key,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            TextButton(onPressed: _openAll, child: const Text('Xem tất cả')),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 226,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: products.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final movie = products[index];
              return _SectionMovieCard(
                movie: movie,
                onTap: () => onOpenCard(movie),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SectionMovieCard extends StatelessWidget {
  const _SectionMovieCard({required this.movie, required this.onTap});

  final MovieCard movie;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 132,
      child: TvFocusable(
        onTap: onTap,
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
                        child: _Badge(text: movie.rating),
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
      ),
    );
  }
}

class _ThumbCard extends StatelessWidget {
  const _ThumbCard({required this.movie, required this.onTap});

  final MovieCard movie;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 104,
      child: TvFocusable(
        onTap: onTap,
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
                              Colors.black.withValues(alpha: 0.45),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (movie.rating.isNotEmpty)
                      Positioned(
                        left: 8,
                        top: 8,
                        child: _Badge(text: movie.rating),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              movie.displayTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
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

class _Badge extends StatelessWidget {
  const _Badge({required this.text});

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

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

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
