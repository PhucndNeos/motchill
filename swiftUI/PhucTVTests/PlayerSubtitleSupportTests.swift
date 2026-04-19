import XCTest
@testable import PhucTV

final class PlayerSubtitleSupportTests: XCTestCase {
    func testDecodeVTTCues() throws {
        let data = Data("""
        WEBVTT

        00:00:01.000 --> 00:00:03.000
        Hello world

        00:00:04.000 --> 00:00:05.500
        Next line
        """.utf8)

        let cues = try PlayerSubtitleLoader.decodeCues(from: data, fileExtension: "vtt")

        XCTAssertEqual(cues.count, 2)
        XCTAssertEqual(cues[0], PlayerSubtitleCue(startMillis: 1000, endMillis: 3000, text: "Hello world"))
        XCTAssertEqual(cues[1], PlayerSubtitleCue(startMillis: 4000, endMillis: 5500, text: "Next line"))
    }

    func testDecodeSRTCuesPreservesLineBreaks() throws {
        let data = Data("""
        1
        00:00:02,000 --> 00:00:04,000
        Line one
        Line two
        """.utf8)

        let cues = try PlayerSubtitleLoader.decodeCues(from: data, fileExtension: "srt")

        XCTAssertEqual(cues.count, 1)
        XCTAssertEqual(cues[0].text, "Line one\nLine two")
    }

    func testResolverReturnsCueInsideRangeAndNilInGap() {
        let cues = [
            PlayerSubtitleCue(startMillis: 1000, endMillis: 3000, text: "First"),
            PlayerSubtitleCue(startMillis: 5000, endMillis: 7000, text: "Second"),
        ]

        let first = PlayerSubtitleResolver.resolve(positionMillis: 1800, cues: cues, hintIndex: nil)
        XCTAssertEqual(first.cueIndex, 0)
        XCTAssertEqual(first.text, "First")

        let gap = PlayerSubtitleResolver.resolve(positionMillis: 4200, cues: cues, hintIndex: first.cueIndex)
        XCTAssertNil(gap.cueIndex)
        XCTAssertNil(gap.text)

        let second = PlayerSubtitleResolver.resolve(positionMillis: 6200, cues: cues, hintIndex: gap.cueIndex)
        XCTAssertEqual(second.cueIndex, 1)
        XCTAssertEqual(second.text, "Second")
    }

    func testResolverCombinesAllOverlappingCueTextAtSamePosition() {
        let cues = [
            PlayerSubtitleCue(startMillis: 0, endMillis: 10_000, text: "[Music]"),
            PlayerSubtitleCue(startMillis: 2_000, endMillis: 4_000, text: "Hello there"),
            PlayerSubtitleCue(startMillis: 6_000, endMillis: 8_000, text: "Another line"),
        ]

        let overlapping = PlayerSubtitleResolver.resolve(positionMillis: 2_500, cues: cues, hintIndex: nil)
        XCTAssertEqual(overlapping.cueIndex, 1)
        XCTAssertEqual(overlapping.text, "[Music]\nHello there")

        let laterOverlap = PlayerSubtitleResolver.resolve(positionMillis: 6_500, cues: cues, hintIndex: overlapping.cueIndex)
        XCTAssertEqual(laterOverlap.cueIndex, 2)
        XCTAssertEqual(laterOverlap.text, "[Music]\nAnother line")
    }
}
