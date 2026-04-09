package com.motchill.androidcompose.data.remote

import com.motchill.androidcompose.domain.model.displayBackdrop
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class MotchillJsonMappersTest {
    @Test
    fun mapsDetailPayloadIntoDomainModel() {
        val json = JSONObject(
            """
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
                "Episodes": [{"Id": 99, "EpisodeNumber": 1, "Name": "Episode 1", "FullLink": "/play/1", "Status": 1, "Type": "episode"}]
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
            """.trimIndent(),
        )

        val detail = json.toMovieDetail()

        assertEquals(42, detail.id)
        assertEquals("Oppenheimer", detail.title)
        assertEquals("Christopher Nolan", detail.director)
        assertEquals(listOf("photo-1", "photo-2"), detail.photoUrls)
        assertEquals(listOf("preview-1"), detail.previewPhotoUrls)
        assertEquals(1, detail.episodes.size)
        assertEquals("Episode 1", detail.episodes.first().label)
        assertEquals(1, detail.countries.size)
        assertEquals(1, detail.categories.size)
        assertEquals(1, detail.relatedMovies.size)
        assertEquals("banner", detail.displayBackdrop)
    }

    @Test
    fun mapsSearchAndPlayPayloads() {
        val search = JSONObject(
            """
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
            """.trimIndent(),
        ).toSearchResults()

        assertEquals(1, search.records.size)
        assertEquals(5, search.pagination.pageCount)
        assertTrue(search.pagination.hasNextPage)
        assertFalse(search.pagination.hasPreviousPage)

        val source = JSONObject(
            """
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
                {"kind": "subtitle", "file": "https://cdn.example.com/sub.vtt", "label": "VN", "default": false}
              ]
            }
            """.trimIndent(),
        ).toPlaySource()

        assertEquals(5, source.sourceId)
        assertEquals(1, source.audioTracks.size)
        assertEquals(1, source.subtitleTracks.size)
        assertEquals("Server 1 • 1080p • stream", source.displayName)
    }
}
