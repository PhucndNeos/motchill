import 'package:flutter_test/flutter_test.dart';

import 'package:mobile_api_base/data/models/motchill_models.dart';

void main() {
  test('parses home sections and cards', () {
    final section = HomeSection.fromJson({
      'Title': 'Slide',
      'Key': 'slide',
      'IsCarousel': true,
      'Products': [
        {
          'Id': 1,
          'Name': 'Movie A',
          'OtherName': 'Alt name',
          'Avatar': 'https://example.com/a.jpg',
          'BannerThumb': 'https://example.com/a-thumb.jpg',
          'AvatarThumb': 'https://example.com/a-thumb.jpg',
          'Description': 'Description',
          'Banner': 'https://example.com/a-banner.jpg',
          'ImageIcon': 'https://example.com/a-icon.jpg',
          'Link': 'movie-a',
          'Quanlity': '4K',
          'Rating': '9.5',
          'Year': 2026,
          'StatusTitle': 'Ongoing',
          'Countries': [
            {'Id': 1, 'Name': 'Vietnam', 'Link': 'vietnam', 'DisplayColumn': 1},
          ],
          'Categories': [
            {'Id': 2, 'Name': 'Action', 'Link': 'action', 'DisplayColumn': 1},
          ],
        },
      ],
    });

    expect(section.title, 'Slide');
    expect(section.products.single.displayTitle, 'Movie A');
    expect(
      section.products.single.displayBanner,
      'https://example.com/a-banner.jpg',
    );
    expect(section.products.single.countries.single.name, 'Vietnam');
  });

  test('parses movie detail payload', () {
    final detail = MovieDetail.fromJson({
      'movie': {
        'Id': 10,
        'Name': 'Movie B',
        'OtherName': 'Alt B',
        'Avatar': 'https://example.com/b.jpg',
        'Banner': 'https://example.com/b-banner.jpg',
        'BannerThumb': 'https://example.com/b-banner-thumb.jpg',
        'Description': 'Detail description',
        'Quanlity': '4K',
        'StatusTitle': 'Tập 1',
        'StatusRaw': 'ongoing',
        'StatusTMText': 'Tập 1',
        'Director': 'Director',
        'Time': '45m',
        'Trailer': 'https://example.com/trailer',
        'ShowTimes': '11:00',
        'MoreInfo': '<p>Info</p>',
        'CastString': 'Cast',
        'Year': 2026,
        'EpisodesTotal': 12,
        'ViewNumber': 999,
        'RatePoint': 9.2,
        'Countries': [
          {'Id': 1, 'Name': 'China', 'Link': 'china', 'DisplayColumn': 1},
        ],
        'Categories': [
          {'Id': 2, 'Name': 'Romance', 'Link': 'romance', 'DisplayColumn': 1},
        ],
        'Episodes': [
          {
            'Id': 100,
            'EpisodeNumber': 1,
            'Name': 'Tập 1',
            'FullLink': 'https://example.com/ep1',
            'Status': 'available',
            'Type': 'episode',
          },
        ],
      },
      'relatedMovies': [
        {
          'Id': 20,
          'Name': 'Movie C',
          'OtherName': 'Alt C',
          'Avatar': 'https://example.com/c.jpg',
          'Banner': 'https://example.com/c-banner.jpg',
          'Link': 'movie-c',
          'Quanlity': 'HD',
          'Year': 2025,
          'StatusRaw': 'ongoing',
          'StatusTitle': 'Ongoing',
          'AvatarImageThumb': 'https://example.com/c-thumb.jpg',
          'AvatarImage': 'https://example.com/c-image.jpg',
          'AvatarThumb': 'https://example.com/c-thumb.jpg',
          'BannerThumb': 'https://example.com/c-banner-thumb.jpg',
        },
      ],
    });

    expect(detail.title, 'Movie B');
    expect(detail.episodesTotal, 12);
    expect(detail.episodes.single.label, 'Tập 1');
    expect(detail.relatedMovies.single.displayTitle, 'Movie C');
    expect(detail.displayBackdrop, 'https://example.com/b-banner.jpg');
  });

  test('coerces numeric values in string fields when parsing movie detail', () {
    final detail = MovieDetail.fromJson({
      'movie': {
        'Id': 10,
        'Name': 12345,
        'OtherName': 67890,
        'Avatar': 'https://example.com/b.jpg',
        'Banner': 'https://example.com/b-banner.jpg',
        'BannerThumb': 'https://example.com/b-banner-thumb.jpg',
        'Description': 'Detail description',
        'Quanlity': '4K',
        'StatusTitle': 'Tập 1',
        'StatusRaw': 404,
        'StatusTMText': 777,
        'Director': 'Director',
        'Time': '45m',
        'Trailer': 999,
        'ShowTimes': 111,
        'MoreInfo': 222,
        'CastString': 333,
        'Year': 2026,
        'EpisodesTotal': 12,
        'ViewNumber': 999,
        'RatePoint': 9.2,
        'Countries': const [],
        'Categories': const [],
        'Episodes': const [],
      },
      'relatedMovies': const [],
    });

    expect(detail.title, '12345');
    expect(detail.otherName, '67890');
    expect(detail.statusRaw, '404');
    expect(detail.statusText, '777');
    expect(detail.trailer, '999');
    expect(detail.showTimes, '111');
    expect(detail.moreInfo, '222');
    expect(detail.castString, '333');
  });
}
