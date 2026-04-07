class PlaySource {
  const PlaySource({
    required this.sourceId,
    required this.serverName,
    required this.link,
    required this.subtitle,
    required this.type,
    required this.isFrame,
    required this.quality,
    required this.tracks,
  });

  final int sourceId;
  final String serverName;
  final String link;
  final String subtitle;
  final int type;
  final bool isFrame;
  final String quality;
  final List<PlayTrack> tracks;

  factory PlaySource.fromJson(Map<String, dynamic> json) {
    return PlaySource(
      sourceId: _toInt(json['SourceId']),
      serverName: _stringValue(json['ServerName']),
      link: _stringValue(json['Link']),
      subtitle: _stringValue(json['Subtitle']),
      type: _toInt(json['Type']),
      isFrame: json['IsFrame'] as bool? ?? false,
      quality: _stringValue(json['Quality']),
      tracks: (json['Tracks'] as List<dynamic>? ?? const [])
          .map(
            (item) =>
                PlayTrack.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(growable: false),
    );
  }

  String get displayName {
    final parts = <String>[
      if (serverName.trim().isNotEmpty) serverName.trim(),
      if (quality.trim().isNotEmpty) quality.trim(),
      if (isFrame) 'iframe' else 'stream',
    ];
    return parts.join(' • ');
  }

  Iterable<PlayTrack> get audioTracks =>
      tracks.where((track) => track.isAudio);

  Iterable<PlayTrack> get subtitleTracks =>
      tracks.where((track) => track.isSubtitle);

  bool get hasAudioTracks => audioTracks.isNotEmpty;

  bool get hasSubtitleTracks => subtitleTracks.isNotEmpty;

  PlayTrack? get defaultAudioTrack {
    for (final track in audioTracks) {
      if (track.isDefault) return track;
    }
    return null;
  }

  PlayTrack? get defaultSubtitleTrack {
    for (final track in subtitleTracks) {
      if (track.isDefault) return track;
    }
    return null;
  }

  bool get isStream => !isFrame;
}

class PlayTrack {
  const PlayTrack({
    required this.kind,
    required this.file,
    required this.label,
    required this.isDefault,
  });

  final String kind;
  final String file;
  final String label;
  final bool isDefault;

  factory PlayTrack.fromJson(Map<String, dynamic> json) {
    return PlayTrack(
      kind: _stringValue(json['kind']),
      file: _stringValue(json['file']),
      label: _stringValue(json['label']),
      isDefault: json['default'] as bool? ?? false,
    );
  }

  String get displayLabel {
    final trimmedLabel = label.trim();
    if (trimmedLabel.isNotEmpty) return trimmedLabel;
    final trimmedFile = file.trim();
    if (trimmedFile.isNotEmpty) return trimmedFile;
    final trimmedKind = kind.trim();
    return trimmedKind.isNotEmpty ? trimmedKind : 'Track';
  }

  bool get isAudio => _matchesTrackKind(kind, 'audio');

  bool get isSubtitle =>
      _matchesTrackKind(kind, 'subtitle') || _matchesTrackKind(kind, 'sub');
}

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? 0;
}

String _stringValue(dynamic value) {
  if (value == null) return '';
  return '$value';
}

bool _matchesTrackKind(String kind, String expected) {
  final normalizedKind = kind.trim().toLowerCase();
  final normalizedExpected = expected.trim().toLowerCase();
  return normalizedKind.contains(normalizedExpected);
}
