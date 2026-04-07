import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../core/widgets/motchill_network_image.dart';
import '../../core/widgets/tv_focusable.dart';
import '../../data/models/motchill_models.dart';
import 'detail_controller.dart';

class DetailView extends GetView<DetailController> {
  const DetailView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF141414), Color(0xFF0F0F0F), Color(0xFF050505)],
          ),
        ),
        child: SafeArea(
          child: Obx(() {
            final detail = controller.detail.value;

            if (controller.isLoading.value && detail == null) {
              return const Center(child: CircularProgressIndicator());
            }

            if (controller.errorMessage.value != null && detail == null) {
              return _DetailErrorState(
                message: controller.errorMessage.value!,
                onRetry: controller.load,
              );
            }

            if (detail == null) {
              return const SizedBox.shrink();
            }

            return CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  expandedHeight: 420,
                  backgroundColor: const Color(0xFF141414),
                  surfaceTintColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  leading: IconButton(
                    onPressed: Get.back,
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  title: Text(
                    detail.title.isNotEmpty ? detail.title : 'Detail',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  actions: [
                    Obx(
                      () => IconButton(
                        onPressed: controller.toggleLike,
                        icon: Icon(
                          controller.isLiked.value
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                        ),
                      ),
                    ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    collapseMode: CollapseMode.pin,
                    background: _DetailHero(
                      detail: detail,
                      onPlay: detail.episodes.isNotEmpty
                          ? () => _openEpisode(detail, detail.episodes.first)
                          : null,
                      onOpenInformation:
                          controller.openInformationTabIfAvailable,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _HeroHeader(
                          detail: detail,
                          onOpenTrailer: controller.openTrailer,
                        ),
                        const SizedBox(height: 16),
                        _MetadataRow(detail: detail),
                      ],
                    ),
                  ),
                ),
                if (controller.availableTabs.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: _DetailTabStrip(
                        tabs: controller.availableTabs,
                        selectedTab: controller.selectedTab.value,
                        onTabSelected: controller.selectTab,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      child: _SectionCard(
                        child: _DetailTabBody(
                          detail: detail,
                          selectedTab: controller.selectedTab.value,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _DetailHero extends StatelessWidget {
  const _DetailHero({
    required this.detail,
    required this.onPlay,
    required this.onOpenInformation,
  });

  final MovieDetail detail;
  final VoidCallback? onPlay;
  final VoidCallback onOpenInformation;

  @override
  Widget build(BuildContext context) {
    final banner = detail.displayBackdrop;
    return Stack(
      fit: StackFit.expand,
      children: [
        _BackdropImage(url: banner),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.15),
                  Colors.black.withValues(alpha: 0.55),
                  const Color(0xFF141414),
                ],
                stops: const [0.0, 0.62, 1.0],
              ),
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                detail.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  height: 0.98,
                  letterSpacing: -0.4,
                ),
              ),
              if (detail.otherName.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  detail.otherName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.35,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (detail.year > 0) _MetaPill(label: detail.year.toString()),
                  if (detail.quality.trim().isNotEmpty)
                    _MetaPill(label: detail.quality),
                  if (detail.statusTitle.trim().isNotEmpty)
                    _MetaPill(label: detail.statusTitle),
                  if (detail.ratePoint > 0)
                    _MetaPill(label: detail.ratePoint.toStringAsFixed(1)),
                  if (detail.viewNumber > 0)
                    _MetaPill(label: _formatCount(detail.viewNumber)),
                  if (detail.time.trim().isNotEmpty)
                    _MetaPill(label: detail.time),
                  if (detail.episodesTotal > 0)
                    _MetaPill(label: '${detail.episodesTotal} eps'),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: onPlay,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Xem ngay'),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: onOpenInformation,
                    icon: const Icon(Icons.info_outline_rounded),
                    label: const Text('Chi tiết'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.detail, required this.onOpenTrailer});

  final MovieDetail detail;
  final Future<void> Function() onOpenTrailer;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            detail.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.2,
            ),
          ),
        ),
        if (detail.trailer.trim().isNotEmpty)
          TextButton.icon(
            onPressed: () => onOpenTrailer(),
            icon: const Icon(Icons.play_circle_outline_rounded),
            label: const Text('Trailer'),
          ),
      ],
    );
  }
}

class _MetadataRow extends StatelessWidget {
  const _MetadataRow({required this.detail});

  final MovieDetail detail;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      if (detail.year > 0) _MetaPill(label: detail.year.toString()),
      if (detail.ratePoint > 0)
        _MetaPill(label: detail.ratePoint.toStringAsFixed(1)),
      if (detail.quality.trim().isNotEmpty) _MetaPill(label: detail.quality),
      if (detail.statusText.trim().isNotEmpty)
        _MetaPill(label: detail.statusText),
      if (detail.statusRaw.trim().isNotEmpty)
        _MetaPill(label: detail.statusRaw),
      if (detail.viewNumber > 0)
        _MetaPill(label: _formatCount(detail.viewNumber)),
      if (detail.time.trim().isNotEmpty) _MetaPill(label: detail.time),
      if (detail.episodesTotal > 0)
        _MetaPill(label: '${detail.episodesTotal} eps'),
    ];

    if (chips.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }
}

class _InfoGrid extends StatelessWidget {
  const _InfoGrid({required this.detail});

  final MovieDetail detail;

  @override
  Widget build(BuildContext context) {
    final items = <_InfoEntry>[
      _InfoEntry('Director', detail.director),
      _InfoEntry('Cast', detail.castString),
      _InfoEntry('Show times', detail.showTimes),
      _InfoEntry('More info', detail.moreInfo),
      _InfoEntry('Trailer', detail.trailer),
      _InfoEntry('Status raw', detail.statusRaw),
      _InfoEntry('Status text', detail.statusText),
    ].where((entry) => entry.value.trim().isNotEmpty).toList(growable: false);

    return Column(
      children: [
        for (var index = 0; index < items.length; index++) ...[
          _InfoCard(entry: items[index]),
          if (index != items.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.entry});

  final _InfoEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B1B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF2C2C2C)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry.label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            entry.value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _EpisodeTile extends StatelessWidget {
  const _EpisodeTile({required this.episode, this.onTap});

  final MovieEpisode episode;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final subtitleParts = <String>[
      if (episode.type.trim().isNotEmpty) episode.type.trim(),
      if (episode.status != null) '$episode.status',
    ];

    return TvFocusable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      focusedBorderColor: const Color(0xFFE8A7A7),
      focusedBackgroundColor: const Color(0xFF251717),
      focusScale: 1.01,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF171717),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF2D2D2D)),
        ),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          title: Text(
            episode.label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: subtitleParts.isEmpty
              ? const Text(
                  'Episode detail from public API',
                  style: TextStyle(color: Colors.white60),
                )
              : Text(
                  subtitleParts.join(' � '),
                  style: const TextStyle(color: Colors.white60),
                ),
          trailing: const Icon(
            Icons.chevron_right_rounded,
            color: Colors.white54,
          ),
        ),
      ),
    );
  }
}

void _openEpisode(MovieDetail detail, MovieEpisode episode) {
  if (detail.id == 0 || episode.id == 0) return;
  Get.toNamed(
    AppRoutes.play
        .replaceFirst(':movieId', detail.id.toString())
        .replaceFirst(':episodeId', episode.id.toString()),
    arguments: {'movieTitle': detail.title, 'episodeLabel': episode.label},
  );
}

class _DetailTabStrip extends StatelessWidget {
  const _DetailTabStrip({
    required this.tabs,
    required this.selectedTab,
    required this.onTabSelected,
  });

  final List<DetailSectionTab> tabs;
  final DetailSectionTab selectedTab;
  final ValueChanged<DetailSectionTab> onTabSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final tab in tabs) ...[
            _DetailTabButton(
              label: tab.label,
              selected: tab == selectedTab,
              onTap: () => onTabSelected(tab),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _DetailTabButton extends StatelessWidget {
  const _DetailTabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      focusedBorderColor: const Color(0xFFFFD15C),
      focusedBackgroundColor: const Color(0xFFE50914).withValues(alpha: 0.22),
      padding: EdgeInsets.zero,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFE50914).withValues(alpha: 0.20)
              : const Color(0xFF191919),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? const Color(0xFFE50914).withValues(alpha: 0.35)
                : const Color(0xFF2C2C2C),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _DetailTabBody extends StatelessWidget {
  const _DetailTabBody({
    required this.detail,
    required this.selectedTab,
  });

  final MovieDetail detail;
  final DetailSectionTab selectedTab;

  @override
  Widget build(BuildContext context) {
    switch (selectedTab) {
      case DetailSectionTab.episodes:
        if (detail.episodes.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: _SectionTitle('Episodes')),
                Text(
                  '${detail.episodes.length}',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Column(
              children: [
                for (var index = 0; index < detail.episodes.length; index++) ...[
                  _EpisodeTile(
                    episode: detail.episodes[index],
                    onTap: () => _openEpisode(detail, detail.episodes[index]),
                  ),
                  if (index != detail.episodes.length - 1)
                    const SizedBox(height: 10),
                ],
              ],
            ),
          ],
        );
      case DetailSectionTab.synopsis:
        if (detail.description.trim().isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle('Synopsis'),
            const SizedBox(height: 10),
            Text(
              detail.description,
              style: const TextStyle(
                color: Colors.white70,
                height: 1.55,
                fontSize: 14,
              ),
            ),
          ],
        );
      case DetailSectionTab.information:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle('Information'),
            const SizedBox(height: 12),
            _InfoGrid(detail: detail),
          ],
        );
      case DetailSectionTab.classification:
        if (detail.countries.isEmpty && detail.categories.isEmpty) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle('Classification'),
            const SizedBox(height: 12),
            if (detail.countries.isNotEmpty) ...[
              const _MiniLabel('Countries'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: detail.countries
                    .map((country) => _LabelChip(text: country.name))
                    .toList(growable: false),
              ),
            ],
            if (detail.countries.isNotEmpty && detail.categories.isNotEmpty)
              const SizedBox(height: 14),
            if (detail.categories.isNotEmpty) ...[
              const _MiniLabel('Categories'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: detail.categories
                    .map((category) => _LabelChip(text: category.name))
                    .toList(growable: false),
              ),
            ],
          ],
        );
      case DetailSectionTab.gallery:
        final galleryImages = <String>{
          ...detail.photoUrls,
          ...detail.previewPhotoUrls,
        }.where((url) => url.trim().isNotEmpty).toList(growable: false);
        if (galleryImages.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle('Gallery'),
            const SizedBox(height: 12),
            SizedBox(
              height: 160,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: galleryImages.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  return _GalleryImage(url: galleryImages[index]);
                },
              ),
            ),
          ],
        );
      case DetailSectionTab.related:
        if (detail.relatedMovies.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: _SectionTitle('Related')),
                TextButton(
                  onPressed: () {},
                  child: const Text('VIEW MORE'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 245,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: detail.relatedMovies.length,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final movie = detail.relatedMovies[index];
                  return _RelatedMovieCard(movie: movie);
                },
              ),
            ),
          ],
        );
    }
  }
}

class _GalleryImage extends StatelessWidget {
  const _GalleryImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(aspectRatio: 0.7, child: _BackdropImage(url: url)),
    );
  }
}

class _RelatedMovieCard extends StatelessWidget {
  const _RelatedMovieCard({required this.movie});

  final MovieCard movie;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      child: TvFocusable(
        onTap: () {
          if (movie.link.trim().isEmpty) return;
          Get.toNamed(
            AppRoutes.detail.replaceFirst(
              ':slug',
              Uri.encodeComponent(movie.link),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        focusedBorderColor: const Color(0xFFFFD15C),
        focusedBackgroundColor: const Color(0xFF1F1A14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _BackdropImage(url: movie.displayPoster),
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
            const SizedBox(height: 4),
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

class _BackdropImage extends StatelessWidget {
  const _BackdropImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return Container(
        color: const Color(0xFF1B1B1B),
        alignment: Alignment.center,
        child: const Icon(
          Icons.movie_outlined,
          color: Colors.white38,
          size: 40,
        ),
      );
    }

    return MotchillNetworkImage(
      url: url,
      width: double.infinity,
      height: double.infinity,
      placeholderColor: const Color(0xFF1B1B1B),
      placeholderIconColor: Colors.white24,
      errorIconColor: Colors.white38,
      iconSize: 40,
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF171717),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2C2C2C)),
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.2,
      ),
    );
  }
}

class _MiniLabel extends StatelessWidget {
  const _MiniLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white54,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
      ),
    );
  }
}

class _LabelChip extends StatelessWidget {
  const _LabelChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF323232)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1C),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF313131)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InfoEntry {
  const _InfoEntry(this.label, this.value);

  final String label;
  final String value;
}

String _formatCount(int value) {
  if (value >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(1)}M';
  }
  if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(1)}K';
  }
  return value.toString();
}

class _DetailErrorState extends StatelessWidget {
  const _DetailErrorState({required this.message, required this.onRetry});

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
