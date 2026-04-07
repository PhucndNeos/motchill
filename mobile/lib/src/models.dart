import 'dart:convert';

class MovieCard {
  const MovieCard({
    required this.slug,
    required this.title,
    required this.subtitle,
    required this.image,
    required this.href,
    this.badge,
  });

  final String slug;
  final String title;
  final String subtitle;
  final String image;
  final String href;
  final String? badge;

  factory MovieCard.fromJson(Map<String, dynamic> json) {
    return MovieCard(
      slug: json['slug'] as String? ?? '',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      image: json['image'] as String? ?? '',
      href: json['href'] as String? ?? '',
      badge: json['badge'] as String?,
    );
  }
}

class EpisodeInfo {
  const EpisodeInfo({
    required this.id,
    required this.slug,
    required this.name,
    required this.number,
    required this.status,
    this.productId,
    this.seoName,
    this.seoTitle,
    this.seoDescription,
  });

  final int? id;
  final String slug;
  final String name;
  final dynamic number;
  final dynamic status;
  final int? productId;
  final String? seoName;
  final String? seoTitle;
  final String? seoDescription;

  factory EpisodeInfo.fromJson(Map<String, dynamic> json) {
    return EpisodeInfo(
      id: json['id'] as int?,
      slug: json['slug'] as String? ?? '',
      name: json['name'] as String? ?? '',
      number: json['number'],
      status: json['status'],
      productId: json['productId'] as int?,
      seoName: json['seoName'] as String?,
      seoTitle: json['seoTitle'] as String?,
      seoDescription: json['seoDescription'] as String?,
    );
  }

  String get label {
    final raw = seoName ?? name;
    if (raw.isNotEmpty) return raw;
    if (number != null) return 'Episode $number';
    return 'Episode';
  }
}

class PlaybackSourceChoice {
  const PlaybackSourceChoice({
    required this.index,
    required this.label,
    required this.available,
    required this.playbackKind,
    required this.mediaUrl,
    required this.mediaReferer,
    required this.raw,
    this.sourceId,
    this.error,
  });

  final int index;
  final String label;
  final bool available;
  final String playbackKind;
  final String mediaUrl;
  final String mediaReferer;
  final dynamic raw;
  final int? sourceId;
  final String? error;

  factory PlaybackSourceChoice.fromJson(Map<String, dynamic> json, int index) {
    final mediaUrl = json['mediaUrl'] as String? ?? '';
    return PlaybackSourceChoice(
      index: json['index'] as int? ?? index,
      label: _sourceChoiceLabel(json, index),
      available: json['available'] as bool? ?? mediaUrl.isNotEmpty,
      playbackKind: json['playbackKind'] as String? ?? 'unsupported',
      mediaUrl: mediaUrl,
      mediaReferer: json['mediaReferer'] as String? ?? '',
      raw: json,
      sourceId: json['sourceId'] as int?,
      error: json['error'] as String?,
    );
  }
}

String _sourceChoiceLabel(dynamic source, int index) {
  if (source is Map) {
    final map = Map<String, dynamic>.from(source);
    final label =
        map['label'] ??
        map['ServerName'] ??
        map['serverName'] ??
        map['name'] ??
        map['title'];
    if (label is String && label.trim().isNotEmpty) {
      return label.trim();
    }

    final nestedLabel = map['LinkName'] ?? map['linkName'];
    if (nestedLabel is String && nestedLabel.trim().isNotEmpty) {
      return nestedLabel.trim();
    }
  }

  return 'Source ${index + 1}';
}

class MovieDetail {
  const MovieDetail({
    required this.movie,
    required this.episode,
    required this.episodes,
    required this.sources,
  });

  final Map<String, dynamic> movie;
  final EpisodeInfo episode;
  final List<EpisodeInfo> episodes;
  final List<dynamic> sources;

  factory MovieDetail.fromJson(Map<String, dynamic> json) {
    return MovieDetail(
      movie: Map<String, dynamic>.from(json['movie'] as Map),
      episode: EpisodeInfo.fromJson(
        Map<String, dynamic>.from(json['episode'] as Map),
      ),
      episodes: (json['episodes'] as List<dynamic>? ?? [])
          .map(
            (item) =>
                EpisodeInfo.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
      sources: List<dynamic>.from(
        json['sources'] as List<dynamic>? ?? const [],
      ),
    );
  }

  String get title => movie['name'] as String? ?? 'Untitled';
  String get description => movie['description'] as String? ?? '';
  String get thumbnail => movie['thumbnail'] as String? ?? '';
  String get banner => movie['banner'] as String? ?? '';
  String get year => movie['year']?.toString() ?? '';
  String get duration => movie['duration']?.toString() ?? '';

  List<PlaybackSourceChoice> get sourceChoices {
    if (sources.isEmpty) {
      return const [
        PlaybackSourceChoice(
          index: 0,
          label: 'Source 1',
          available: false,
          playbackKind: 'unsupported',
          mediaUrl: '',
          mediaReferer: '',
          raw: null,
        ),
      ];
    }

    return sources.asMap().entries.map((entry) {
      final index = entry.key;
      final source = entry.value;
      if (source is Map<String, dynamic>) {
        return PlaybackSourceChoice.fromJson(source, index);
      }
      final label = _sourceChoiceLabel(source, index);
      return PlaybackSourceChoice(
        index: index,
        label: label,
        available: false,
        playbackKind: 'unsupported',
        mediaUrl: '',
        mediaReferer: '',
        raw: source,
      );
    }).toList();
  }
}

class PlaybackInfo {
  const PlaybackInfo({
    required this.movieId,
    required this.episodeId,
    required this.server,
    required this.playbackKind,
    required this.streamUrl,
    required this.mediaUrl,
    required this.mediaReferer,
    required this.sources,
    required this.raw,
  });

  final int movieId;
  final int episodeId;
  final int server;
  final String playbackKind;
  final String streamUrl;
  final String mediaUrl;
  final String mediaReferer;
  final List<dynamic> sources;
  final dynamic raw;

  factory PlaybackInfo.fromJson(Map<String, dynamic> json) {
    final sources = List<dynamic>.from(
      (json['sources'] as List<dynamic>? ??
          json['raw'] as List<dynamic>? ??
          const []),
    );
    return PlaybackInfo(
      movieId: json['movieId'] as int,
      episodeId: json['episodeId'] as int,
      server: json['server'] as int? ?? 0,
      playbackKind: json['playbackKind'] as String? ?? 'unsupported',
      streamUrl: json['streamUrl'] as String? ?? '',
      mediaUrl: json['mediaUrl'] as String? ?? '',
      mediaReferer: json['mediaReferer'] as String? ?? '',
      sources: sources,
      raw: json['raw'],
    );
  }

  List<PlaybackSourceChoice> get sourceChoices {
    if (sources.isEmpty) {
      return const [
        PlaybackSourceChoice(
          index: 0,
          label: 'Source 1',
          available: false,
          playbackKind: 'unsupported',
          mediaUrl: '',
          mediaReferer: '',
          raw: null,
        ),
      ];
    }

    return sources.asMap().entries.map((entry) {
      final index = entry.key;
      final source = entry.value;
      if (source is Map<String, dynamic>) {
        return PlaybackSourceChoice.fromJson(source, index);
      }
      final label = _sourceChoiceLabel(source, index);
      return PlaybackSourceChoice(
        index: index,
        label: label,
        available: false,
        playbackKind: 'unsupported',
        mediaUrl: '',
        mediaReferer: '',
        raw: source,
      );
    }).toList();
  }
}

String prettyJson(dynamic value) {
  const encoder = JsonEncoder.withIndent('  ');
  return encoder.convert(value);
}
