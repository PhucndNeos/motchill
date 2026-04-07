import 'dart:math' as math;

class HomeSection {
  const HomeSection({
    required this.title,
    required this.key,
    required this.products,
    required this.isCarousel,
  });

  final String title;
  final String key;
  final List<MovieCard> products;
  final bool isCarousel;

  factory HomeSection.fromJson(Map<String, dynamic> json) {
    return HomeSection(
      title: _stringValue(json['Title']),
      key: _stringValue(json['Key']),
      products: (json['Products'] as List<dynamic>? ?? const [])
          .map(
            (item) =>
                MovieCard.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
      isCarousel: json['IsCarousel'] as bool? ?? false,
    );
  }
}

class MovieCard {
  const MovieCard({
    required this.id,
    required this.name,
    required this.otherName,
    required this.avatar,
    required this.bannerThumb,
    required this.avatarThumb,
    required this.description,
    required this.banner,
    required this.imageIcon,
    required this.link,
    required this.quantity,
    required this.rating,
    required this.year,
    required this.statusTitle,
    required this.countries,
    required this.categories,
  });

  final int id;
  final String name;
  final String otherName;
  final String avatar;
  final String bannerThumb;
  final String avatarThumb;
  final String description;
  final String banner;
  final String imageIcon;
  final String link;
  final String quantity;
  final String rating;
  final int year;
  final String statusTitle;
  final List<SimpleLabel> countries;
  final List<SimpleLabel> categories;

  factory MovieCard.fromJson(Map<String, dynamic> json) {
    return MovieCard(
      id: _toInt(json['Id']),
      name: _stringValue(json['Name']),
      otherName: _stringValue(json['OtherName']),
      avatar: _stringValue(json['Avatar']),
      bannerThumb: _stringValue(json['BannerThumb']),
      avatarThumb: _stringValue(json['AvatarThumb']),
      description: _stringValue(json['Description']),
      banner: _stringValue(json['Banner']),
      imageIcon: _stringValue(json['ImageIcon']),
      link: _stringValue(json['Link']),
      quantity: _stringValue(json['Quanlity']),
      rating: json['Rating']?.toString() ?? '',
      year: _toInt(json['Year']),
      statusTitle: _stringValue(json['StatusTitle']),
      countries: _labelsFromJson(json['Countries']),
      categories: _labelsFromJson(json['Categories']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Id': id,
      'Name': name,
      'OtherName': otherName,
      'Avatar': avatar,
      'BannerThumb': bannerThumb,
      'AvatarThumb': avatarThumb,
      'Description': description,
      'Banner': banner,
      'ImageIcon': imageIcon,
      'Link': link,
      'Quanlity': quantity,
      'Rating': rating,
      'Year': year,
      'StatusTitle': statusTitle,
      'Countries': countries.map((label) => label.toJson()).toList(),
      'Categories': categories.map((label) => label.toJson()).toList(),
    };
  }
}

class NavbarItem {
  const NavbarItem({
    required this.id,
    required this.name,
    required this.slug,
    required this.items,
    required this.isExistChild,
  });

  final int id;
  final String name;
  final String slug;
  final List<NavbarItem> items;
  final bool isExistChild;

  factory NavbarItem.fromJson(Map<String, dynamic> json) {
    return NavbarItem(
      id: _toInt(json['Id']),
      name: _stringValue(json['Name']),
      slug: _stringValue(json['Slug']),
      items: (json['Items'] as List<dynamic>? ?? const [])
          .map(
            (item) =>
                NavbarItem.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
      isExistChild: json['IsExistChild'] as bool? ?? false,
    );
  }
}

class PopupAdConfig {
  const PopupAdConfig({
    required this.id,
    required this.name,
    required this.type,
    required this.desktopLink,
    required this.mobileLink,
  });

  final int id;
  final String name;
  final String type;
  final String desktopLink;
  final String mobileLink;

  factory PopupAdConfig.fromJson(Map<String, dynamic> json) {
    return PopupAdConfig(
      id: _toInt(json['Id']),
      name: _stringValue(json['Name']),
      type: _stringValue(json['Type']),
      desktopLink: _stringValue(json['DesktopLink']),
      mobileLink: _stringValue(json['MobileLink']),
    );
  }
}

class SimpleLabel {
  const SimpleLabel({
    required this.id,
    required this.name,
    required this.link,
    required this.displayColumn,
  });

  final int id;
  final String name;
  final String link;
  final int displayColumn;

  factory SimpleLabel.fromJson(Map<String, dynamic> json) {
    return SimpleLabel(
      id: _toInt(json['Id']),
      name: _stringValue(json['Name']),
      link: _stringValue(json['Link']),
      displayColumn: _toInt(json['DisplayColumn']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Id': id,
      'Name': name,
      'Link': link,
      'DisplayColumn': displayColumn,
    };
  }
}

class MovieEpisode {
  const MovieEpisode({
    required this.id,
    required this.episodeNumber,
    required this.name,
    required this.fullLink,
    required this.status,
    required this.type,
  });

  final int id;
  final dynamic episodeNumber;
  final String name;
  final String fullLink;
  final dynamic status;
  final String type;

  factory MovieEpisode.fromJson(Map<String, dynamic> json) {
    return MovieEpisode(
      id: _toInt(json['Id']),
      episodeNumber: json['EpisodeNumber'],
      name: _stringValue(json['Name']),
      fullLink: _stringValue(json['FullLink']),
      status: json['Status'],
      type: _stringValue(json['Type']),
    );
  }

  String get label {
    if (name.trim().isNotEmpty) {
      return name.trim();
    }
    if (episodeNumber != null) {
      return 'Tập $episodeNumber';
    }
    return 'Episode';
  }
}

class MovieDetail {
  const MovieDetail({
    required this.movie,
    required this.relatedMovies,
    required this.countries,
    required this.categories,
    required this.episodes,
  });

  final Map<String, dynamic> movie;
  final List<MovieCard> relatedMovies;
  final List<SimpleLabel> countries;
  final List<SimpleLabel> categories;
  final List<MovieEpisode> episodes;

  factory MovieDetail.fromJson(Map<String, dynamic> json) {
    final movie = Map<String, dynamic>.from(json['movie'] as Map);
    return MovieDetail(
      movie: movie,
      relatedMovies: (json['relatedMovies'] as List<dynamic>? ?? const [])
          .map(
            (item) =>
                MovieCard.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
      countries: _labelsFromJson(movie['Countries']),
      categories: _labelsFromJson(movie['Categories']),
      episodes: (movie['Episodes'] as List<dynamic>? ?? const [])
          .map(
            (item) =>
                MovieEpisode.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
    );
  }

  int get id => _toInt(movie['Id']);
  String get title => _stringValue(movie['Name']);
  String get otherName => _stringValue(movie['OtherName']);
  String get avatar => _stringValue(movie['Avatar']);
  String get avatarThumb => _stringValue(movie['AvatarThumb']);
  String get banner => _stringValue(movie['Banner']);
  String get bannerThumb => _stringValue(movie['BannerThumb']);
  String get description => _stringValue(movie['Description']);
  String get quality => _stringValue(movie['Quanlity']);
  String get statusTitle => _stringValue(movie['StatusTitle']);
  String get statusRaw => _stringValue(movie['StatusRaw']);
  String get statusText => _stringValue(movie['StatusTMText']);
  String get director => _stringValue(movie['Director']);
  String get time => _stringValue(movie['Time']);
  String get trailer => _stringValue(movie['Trailer']);
  String get showTimes => _stringValue(movie['ShowTimes']);
  String get moreInfo => _stringValue(movie['MoreInfo']);
  String get castString => _stringValue(movie['CastString']);
  int get year => _toInt(movie['Year']);
  int get episodesTotal => _toInt(movie['EpisodesTotal']);
  int get viewNumber => _toInt(movie['ViewNumber']);
  double get ratePoint => _toDouble(movie['RatePoint']);

  List<String> get photoUrls {
    final raw = movie['Photos'];
    if (raw is List) {
      return raw.map((e) => '$e').where((e) => e.isNotEmpty).toList();
    }
    return const [];
  }

  List<String> get previewPhotoUrls {
    final raw = movie['PreviewPhotos'];
    if (raw is List) {
      return raw.map((e) => '$e').where((e) => e.isNotEmpty).toList();
    }
    return const [];
  }
}

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? 0;
}

double _toDouble(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse('$value') ?? 0.0;
}

String _stringValue(dynamic value) {
  if (value == null) return '';
  return '$value';
}

List<SimpleLabel> _labelsFromJson(dynamic value) {
  if (value is! List) return const [];
  return value
      .map(
        (item) => SimpleLabel.fromJson(Map<String, dynamic>.from(item as Map)),
      )
      .toList(growable: false);
}

class SectionIndex {
  const SectionIndex({required this.value, required this.label});

  final int value;
  final String label;
}

extension MovieCardLayout on MovieCard {
  String get displayTitle => name.trim().isNotEmpty ? name.trim() : 'Untitled';
  String get displaySubtitle =>
      otherName.trim().isNotEmpty ? otherName.trim() : description.trim();
  String get displayPoster => avatarThumb.isNotEmpty ? avatarThumb : avatar;
  String get displayBanner => banner.isNotEmpty ? banner : bannerThumb;
}

extension MovieDetailLayout on MovieDetail {
  String get displayBackdrop {
    if (banner.isNotEmpty) return banner;
    if (avatar.isNotEmpty) return avatar;
    if (bannerThumb.isNotEmpty) return bannerThumb;
    return avatarThumb;
  }

  List<SectionIndex> get sectionIndex {
    return List.generate(
      math.min(episodes.length, 20),
      (index) => SectionIndex(value: index, label: episodes[index].label),
    );
  }
}
