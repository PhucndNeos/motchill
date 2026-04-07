import 'package:flutter/material.dart';

import '../data/motchill_repository.dart';
import '../features/detail/detail_controller.dart';
import '../features/shared/load_state.dart';
import '../models.dart';
import 'player_screen.dart';

class DetailScreen extends StatefulWidget {
  const DetailScreen({
    super.key,
    required this.repository,
    required this.movieSlug,
  });

  final MotchillRepository repository;
  final String movieSlug;

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  late final DetailController _controller;

  @override
  void initState() {
    super.initState();
    _controller = DetailController(
      repository: widget.repository,
      movieSlug: widget.movieSlug,
    )..load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _play(MovieDetail detail, int index) async {
    try {
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PlayerScreen(
            repository: widget.repository,
            detail: detail,
            initialIndex: index,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start playback: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final state = _controller.state;

        if (state.status == LoadStatus.loading && state.value == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (state.status == LoadStatus.failure && state.value == null) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 48),
                    const SizedBox(height: 12),
                    Text('Can not load detail', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(state.error.toString(), textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _controller.load,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final detail = state.value!;
        final episodes = _controller.episodes;
        final selectedEpisode = _controller.selectedEpisode ?? detail.episode;
        final banner = detail.banner.isNotEmpty ? detail.banner : detail.thumbnail;

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 320,
                pinned: true,
                backgroundColor: const Color(0xFF08111F),
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding: const EdgeInsetsDirectional.only(start: 16, bottom: 16),
                  title: Text(detail.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (banner.isNotEmpty)
                        Image.network(banner, fit: BoxFit.cover)
                      else
                        Container(color: const Color(0xFF18253A)),
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Color(0xAA08111F),
                              Color(0xFF08111F),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                sliver: SliverList(
                  delegate: SliverChildListDelegate(
                    [
                      Row(
                        children: [
                          _InfoChip(label: detail.year.isEmpty ? 'N/A' : detail.year),
                          const SizedBox(width: 8),
                          _InfoChip(label: detail.duration.isEmpty ? 'Stream' : detail.duration),
                          const SizedBox(width: 8),
                          _InfoChip(label: '${episodes.length} eps'),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(detail.description.isEmpty ? 'No description available.' : detail.description),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: () => _play(detail, _controller.selectedIndex),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: Text('Play ${selectedEpisode.label}'),
                      ),
                      const SizedBox(height: 24),
                      Text('Episodes', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: List.generate(episodes.length, (index) {
                          final episode = episodes[index];
                          final selected = index == _controller.selectedIndex;
                          return ChoiceChip(
                            selected: selected,
                            label: Text(episode.label),
                            onSelected: (_) => _controller.selectEpisode(index),
                          );
                        }),
                      ),
                      const SizedBox(height: 18),
                      ...episodes.asMap().entries.map((entry) {
                        final index = entry.key;
                        final episode = entry.value;
                        final selected = index == _controller.selectedIndex;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            tileColor: const Color(0xFF111B2A),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            leading: CircleAvatar(
                              backgroundColor: selected ? const Color(0xFF32D6B7) : const Color(0xFF22314A),
                              child: Text('${index + 1}'),
                            ),
                            title: Text(episode.label),
                            subtitle: Text(
                              episode.seoTitle ?? episode.seoDescription ?? (episode.status?.toString() ?? ''),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: const Icon(Icons.play_circle_outline_rounded),
                            onTap: () {
                              _controller.selectEpisode(index);
                              _play(detail, index);
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}
