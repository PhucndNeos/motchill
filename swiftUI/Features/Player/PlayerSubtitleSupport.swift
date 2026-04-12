import Foundation
import SwiftSubtitles

protocol PlayerSubtitleLoading: Sendable {
    func loadCues(for track: PhucTvPlayTrack) async throws -> [PlayerSubtitleCue]
}

struct PlayerSubtitleCue: Equatable, Sendable {
    let startMillis: Int64
    let endMillis: Int64
    let text: String

    func contains(positionMillis: Int64) -> Bool {
        positionMillis >= startMillis && positionMillis <= endMillis
    }
}

struct PlayerSubtitleResolution: Equatable {
    let cueIndex: Int?
    let text: String?
}

enum PlayerSubtitleResolver {
    private static let hintWindow = 6

    static func resolve(
        positionMillis: Int64,
        cues: [PlayerSubtitleCue],
        hintIndex: Int?
    ) -> PlayerSubtitleResolution {
        guard !cues.isEmpty else {
            return PlayerSubtitleResolution(cueIndex: nil, text: nil)
        }

        if let hintIndex,
           cues.indices.contains(hintIndex),
           let resolvedIndex = resolveUsingHint(positionMillis: positionMillis, cues: cues, hintIndex: hintIndex) {
            return PlayerSubtitleResolution(
                cueIndex: resolvedIndex,
                text: cues[resolvedIndex].text
            )
        }

        guard let cueIndex = binarySearchContainingCue(positionMillis: positionMillis, cues: cues) else {
            return PlayerSubtitleResolution(cueIndex: nil, text: nil)
        }

        return PlayerSubtitleResolution(cueIndex: cueIndex, text: cues[cueIndex].text)
    }

    private static func resolveUsingHint(
        positionMillis: Int64,
        cues: [PlayerSubtitleCue],
        hintIndex: Int
    ) -> Int? {
        let hintCue = cues[hintIndex]
        if hintCue.contains(positionMillis: positionMillis) {
            return hintIndex
        }

        let lowerBound = max(0, hintIndex - hintWindow)
        let upperBound = min(cues.count - 1, hintIndex + hintWindow)
        guard lowerBound <= upperBound else { return nil }

        for index in lowerBound ... upperBound where cues[index].contains(positionMillis: positionMillis) {
            return index
        }

        return nil
    }

    private static func binarySearchContainingCue(
        positionMillis: Int64,
        cues: [PlayerSubtitleCue]
    ) -> Int? {
        var lowerBound = 0
        var upperBound = cues.count - 1

        while lowerBound <= upperBound {
            let middleIndex = (lowerBound + upperBound) / 2
            let cue = cues[middleIndex]

            if positionMillis < cue.startMillis {
                upperBound = middleIndex - 1
            } else if positionMillis > cue.endMillis {
                lowerBound = middleIndex + 1
            } else {
                return middleIndex
            }
        }

        return nil
    }
}

struct PlayerSubtitleLoader: PlayerSubtitleLoading {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func loadCues(for track: PhucTvPlayTrack) async throws -> [PlayerSubtitleCue] {
        let rawURL = track.file.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            !rawURL.isEmpty,
            let url = URL(string: rawURL),
            let fileExtension = Self.supportedFileExtension(from: url)
        else {
            return []
        }

        let (data, _) = try await session.data(from: url)
        return try await Task.detached(priority: .utility) {
            try Self.decodeCues(from: data, fileExtension: fileExtension)
        }.value
    }

    static func decodeCues(
        from data: Data,
        fileExtension: String
    ) throws -> [PlayerSubtitleCue] {
        let normalizedExtension = fileExtension.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let temporaryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(normalizedExtension)

        try data.write(to: temporaryURL, options: .atomic)
        defer {
            try? FileManager.default.removeItem(at: temporaryURL)
        }

        let subtitles = try Subtitles(fileURL: temporaryURL, encoding: .utf8)
        return subtitles.cues.compactMap(Self.makeCue)
    }

    static func supportedFileExtension(from url: URL) -> String? {
        let fileExtension = url.pathExtension.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !fileExtension.isEmpty else { return nil }

        switch fileExtension {
        case "vtt", "srt", "sbv", "sub", "csv", "json", "lrc", "ttml", "ssa", "ass":
            return fileExtension
        default:
            return nil
        }
    }

    private static func makeCue(from cue: Subtitles.Cue) -> PlayerSubtitleCue? {
        let text = cue.text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !text.isEmpty else { return nil }

        let startMillis = Int64((cue.startTimeInSeconds * 1000).rounded())
        let endMillis = Int64((cue.endTimeInSeconds * 1000).rounded())

        guard endMillis >= startMillis else { return nil }

        return PlayerSubtitleCue(
            startMillis: max(0, startMillis),
            endMillis: max(startMillis, endMillis),
            text: text
        )
    }
}
