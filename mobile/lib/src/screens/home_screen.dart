import 'package:flutter/material.dart';

import '../data/motchill_repository.dart';
import '../features/home/home_controller.dart';
import '../features/shared/load_state.dart';
import '../models.dart';
import 'detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.repository});

  final MotchillRepository repository;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final HomeController _controller;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = HomeController(repository: widget.repository)..loadHome();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _openDetail(MovieCard card) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DetailScreen(
          repository: widget.repository,
          movieSlug: card.slug,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final state = _controller.state;
        final items = state.value ?? const <MovieCard>[];
        final query = _controller.query;

        return Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF12233F),
                  Color(0xFF08111F),
                  Color(0xFF050A12),
                ],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Motchill', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
                              SizedBox(height: 4),
                              Text('Fast catalog, fresh playback, one app.'),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: _controller.refresh,
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _controller.searchChanged,
                      decoration: InputDecoration(
                        hintText: 'Search movies, shows, episodes',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _controller.searching
                            ? IconButton(
                                onPressed: () {
                                  _searchController.clear();
                                  _controller.clearSearch();
                                },
                                icon: const Icon(Icons.clear_rounded),
                              )
                            : null,
                        filled: true,
                        fillColor: const Color(0xFF121B2B),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Text(
                          query.isEmpty ? 'Trending now' : 'Results for "$query"',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const Spacer(),
                        if (_controller.searching)
                          TextButton(
                            onPressed: () {
                              _searchController.clear();
                              _controller.clearSearch();
                            },
                            child: const Text('Show all'),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _buildBody(state, items),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody(LoadState<List<MovieCard>> state, List<MovieCard> items) {
    if (state.status == LoadStatus.loading && items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.status == LoadStatus.failure && items.isEmpty) {
      return _EmptyState(
        title: 'Can not load content',
        message: state.error.toString(),
        actionLabel: 'Retry',
        onAction: _controller.refresh,
      );
    }

    if (items.isEmpty) {
      return const _EmptyState(
        title: 'Nothing found',
        message: 'Try another keyword or refresh the home feed.',
      );
    }

    return RefreshIndicator(
      onRefresh: _controller.refresh,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        itemCount: items.length,
        separatorBuilder: (context, index) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          final card = items[index];
          return _MovieTile(
            card: card,
            onTap: () => _openDetail(card),
          );
        },
      ),
    );
  }
}

class _MovieTile extends StatelessWidget {
  const _MovieTile({required this.card, required this.onTap});

  final MovieCard card;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF111B2A),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 16,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(22)),
              child: SizedBox(
                width: 102,
                height: 144,
                child: card.image.isEmpty
                    ? Container(color: const Color(0xFF1B2A40))
                    : Image.network(card.image, fit: BoxFit.cover),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (card.badge != null) ...[
                      _Badge(text: card.badge!),
                      const SizedBox(height: 8),
                    ],
                    Text(
                      card.title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      card.subtitle.isEmpty ? 'Tap to explore' : card.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
                    ),
                    const SizedBox(height: 14),
                    const Row(
                      children: [
                        Icon(Icons.play_circle_fill_rounded, size: 18, color: Color(0xFF32D6B7)),
                        SizedBox(width: 6),
                        Text('Open detail'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF32D6B7).withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF7BF3D9),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.message, this.actionLabel, this.onAction});

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.movie_filter_rounded, size: 56),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            if (actionLabel != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

