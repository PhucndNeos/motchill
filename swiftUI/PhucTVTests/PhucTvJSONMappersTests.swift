import XCTest
@testable import PhucTvSwiftUI

final class PhucTvJSONMappersTests: XCTestCase {
    func testMapsDetailSearchAndPlayPayloads() throws {
        let decoder = JSONDecoder()
        let detailJSON = """
        {
          "movie": {
            "Id": 42,
            "Name": "Oppenheimer",
            "OtherName": "Oppenheimer (2023)",
            "Avatar": "avatar",
            "BannerThumb": "banner-thumb",
            "AvatarThumb": "avatar-thumb",
            "Description": "Biography drama",
            "Banner": "banner",
            "ImageIcon": "icon",
            "Link": "/movie/oppenheimer",
            "Quanlity": "HD",
            "Rating": "8.8",
            "Year": 2023,
            "StatusTitle": "Completed",
            "StatusRaw": "completed",
            "StatusTMText": "Ended",
            "Director": "Christopher Nolan",
            "Time": "180m",
            "Trailer": "https://example.com/trailer",
            "ShowTimes": "Now showing",
            "MoreInfo": "More info",
            "CastString": "Cillian Murphy",
            "EpisodesTotal": 1,
            "ViewNumber": 1000,
            "RatePoint": 8.8,
            "Photos": ["photo-1", "photo-2"],
            "PreviewPhotos": ["preview-1"],
            "Countries": [{"Id": 1, "Name": "USA", "Link": "/country/usa", "DisplayColumn": 1}],
            "Categories": [{"Id": 2, "Name": "Drama", "Link": "/category/drama", "DisplayColumn": 1}],
            "Episodes": [{"Id": 99, "EpisodeNumber": "1", "Name": "Episode 1", "FullLink": "/play/1", "Status": "1", "Type": "episode"}]
          },
          "relatedMovies": [
            {
              "Id": 7,
              "Name": "Dunkirk",
              "OtherName": "",
              "Avatar": "",
              "BannerThumb": "",
              "AvatarThumb": "",
              "Description": "",
              "Banner": "",
              "ImageIcon": "",
              "Link": "/movie/dunkirk",
              "Quanlity": "",
              "Rating": "7.9",
              "Year": 2017,
              "StatusTitle": "Completed"
            }
          ]
        }
        """

        let detail = try decoder.decode(
            PhucTvMovieDetailDTO.self,
            from: Data(detailJSON.utf8)
        )

        let mappedDetail = detail.domain

        XCTAssertEqual(mappedDetail.id, 42)
        XCTAssertEqual(mappedDetail.title, "Oppenheimer")
        XCTAssertEqual(mappedDetail.director, "Christopher Nolan")
        XCTAssertEqual(mappedDetail.photoUrls, ["photo-1", "photo-2"])
        XCTAssertEqual(mappedDetail.previewPhotoUrls, ["preview-1"])
        XCTAssertEqual(mappedDetail.episodes.first?.label, "Episode 1")
        XCTAssertEqual(mappedDetail.relatedMovies.count, 1)
        XCTAssertEqual(mappedDetail.displayBackdrop, "banner")

        let searchJSON = """
        {
          "Records": [
            {
              "Id": 1,
              "Name": "Movie",
              "OtherName": "",
              "Avatar": "",
              "BannerThumb": "",
              "AvatarThumb": "",
              "Description": "",
              "Banner": "",
              "ImageIcon": "",
              "Link": "/movie/movie",
              "Quanlity": "",
              "Rating": "0",
              "Year": 2024,
              "StatusTitle": "Now"
            }
          ],
          "Pagination": {
            "PageIndex": 1,
            "PageSize": 24,
            "PageCount": 5,
            "TotalRecords": 120
          }
        }
        """

        let search = try decoder.decode(
            PhucTvSearchResultsDTO.self,
            from: Data(searchJSON.utf8)
        )

        let mappedSearch = search.domain

        XCTAssertEqual(mappedSearch.records.count, 1)
        XCTAssertEqual(mappedSearch.pagination.pageCount, 5)
        XCTAssertTrue(mappedSearch.pagination.hasNextPage)
        XCTAssertFalse(mappedSearch.pagination.hasPreviousPage)

        let sourceJSON = """
        {
          "SourceId": 5,
          "ServerName": "Server 1",
          "Link": "https://cdn.example.com/master.m3u8",
          "Subtitle": "/subs.vtt",
          "Type": 0,
          "IsFrame": false,
          "Quality": "1080p",
          "Tracks": [
            {"kind": "audio", "file": "https://cdn.example.com/audio.m3u8", "label": "English", "default": true},
            {"kind": "captions", "file": "https://cdn.example.com/sub.vtt", "label": "VN", "default": false}
          ]
        }
        """

        let source = try decoder.decode(
            PhucTvPlaySourceDTO.self,
            from: Data(sourceJSON.utf8)
        ).domain

        XCTAssertEqual(source.sourceId, 5)
        XCTAssertEqual(source.audioTracks.count, 1)
        XCTAssertEqual(source.subtitleTracks.count, 1)
        XCTAssertEqual(source.subtitleTracks.first?.displayLabel, "VN")
        XCTAssertTrue(source.displayName.contains("Server 1"))
        XCTAssertTrue(source.displayName.contains("1080p"))
        XCTAssertTrue(source.displayName.contains("stream"))
        XCTAssertTrue([source].playableDirectStreams.contains(source))
    }

    func testMapsFallbackSubtitleFieldIntoSubtitleTracks() throws {
        let sourceJSON = """
        {
          "SourceId": 8,
          "ServerName": "Server 8",
          "Link": "https://cdn.example.com/master.m3u8",
          "Subtitle": "https://cdn.example.com/direct-sub.vtt",
          "Type": 0,
          "IsFrame": false,
          "Quality": "720p",
          "Tracks": []
        }
        """

        let source = try JSONDecoder().decode(
            PhucTvPlaySourceDTO.self,
            from: Data(sourceJSON.utf8)
        ).domain

        XCTAssertEqual(source.subtitleTracks.count, 1)
        XCTAssertEqual(source.subtitleTracks.first?.displayLabel, "Subtitle")
        XCTAssertEqual(source.subtitleTracks.first?.file, "https://cdn.example.com/direct-sub.vtt")
        XCTAssertTrue(source.subtitleTracks.first?.isDefault ?? false)
    }

    func testDecodesHomeViewNumberWhenApiReturnsString() throws {
        let homeJSON = """
        [
          {
            "Title": "Slide",
            "Key": "slide",
            "IsCarousel": true,
            "Products": [
              {
                "Id": 38643,
                "Name": "Nguyệt Lân Ỷ Kỷ",
                "OtherName": "Veil of Shadows",
                "Avatar": "https://example.com/avatar.webp",
                "BannerThumb": "https://example.com/banner-thumb.webp",
                "AvatarThumb": "https://example.com/avatar-thumb.webp",
                "Description": "Description",
                "Banner": "https://example.com/banner.webp",
                "ImageIcon": "https://example.com/icon.webp",
                "Link": "/movie/veil-of-shadows",
                "Quanlity": "HD",
                "Rating": "8.2",
                "Year": 2024,
                "StatusTitle": "Now showing",
                "StatusRaw": "ongoing",
                "StatusTMText": "Ongoing",
                "Director": "Director",
                "Time": "120m",
                "Trailer": "https://example.com/trailer",
                "ShowTimes": "Now",
                "MoreInfo": "More",
                "CastString": "Cast",
                "EpisodesTotal": 12,
                "ViewNumber": "12345",
                "RatePoint": 8.2,
                "Photos": [],
                "PreviewPhotos": []
              }
            ]
          }
        ]
        """

        let sections = try JSONDecoder().decode(
            [PhucTvHomeSectionDTO].self,
            from: Data(homeJSON.utf8)
        )

        XCTAssertEqual(sections.first?.products.first?.viewNumber, 12345)
        XCTAssertEqual(sections.first?.domain.products.first?.viewNumber, 12345)
    }
}
