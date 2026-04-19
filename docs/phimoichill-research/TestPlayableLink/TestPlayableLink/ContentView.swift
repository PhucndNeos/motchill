//
//  ContentView.swift
//  TestPlayableLink
//
//  Created by Phucnd on 19/4/26.
//

import SwiftUI
import AVKit
import Combine

struct ContentView: View {
    @State private var viewModel = PlayerTestViewModel()

    var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Film URL:")
                    .font(.subheadline.weight(.semibold))
                Text(viewModel.filmInfoURL)
                    .font(.caption)
                    .textSelection(.enabled)
            }

            if !viewModel.playableSources.isEmpty {
                Picker("Source", selection: $viewModel.selectedSourceID) {
                    ForEach(viewModel.playableSources) { source in
                        Text(source.title).tag(source.id as String?)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: viewModel.selectedSourceID) { _, _ in
                    viewModel.reloadAndPlay()
                }
            }

            VideoPlayer(player: viewModel.player)
                .frame(height: 240)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            HStack(spacing: 12) {
                Button(viewModel.isPlaying ? "Pause" : "Play") {
                    viewModel.togglePlayPause()
                }
                .buttonStyle(.borderedProminent)

                Button("Retry") {
                    viewModel.reloadAndPlay()
                }
                .buttonStyle(.bordered)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Status: \(viewModel.statusText)")
                    .font(.subheadline.weight(.semibold))
                Text("Episode picked: \(viewModel.selectedEpisodeDisplay)")
                    .font(.caption)
                Text("Playable URL: \(viewModel.currentPlayableURL ?? "-")")
                    .font(.caption)
                    .textSelection(.enabled)
                Text("Log:")
                    .font(.subheadline.weight(.semibold))
                ScrollView {
                    Text(viewModel.logText)
                        .font(.caption.monospaced())
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 220)
                .padding(8)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        .onAppear {
            viewModel.start()
        }
    }
}

@Observable
@MainActor
class PlayerTestViewModel {
    struct Episode: Identifiable {
        let id: String
        let tapNumber: Int?
        let href: String
        let label: String
    }

    struct PlayableSource: Identifiable {
        let id: String
        let title: String
        let url: String
    }

    let filmInfoURL = "https://phimmoichill.men/info/phu-nhan-dai-quan-the-ky-21-pm17367"

    var statusText: String = "Idle"
    var logText: String = "Waiting..."
    var isPlaying: Bool = false
    var episodes: [Episode] = []
    var playableSources: [PlayableSource] = []
    var selectedSourceID: String?
    var selectedEpisodeDisplay: String = "-"

    let player = AVPlayer()
    private let session = URLSession(configuration: .default)

    private var itemStatusObservation: NSKeyValueObservation?
    private var timeControlObservation: NSKeyValueObservation?
    private var failedObserver: NSObjectProtocol?

    func start() {
        configureObservers()
        Task {
            await bootstrapFromFilmPage()
        }
    }

    func bootstrapFromFilmPage() async {
        statusText = "Resolving"
        appendLog("Start resolve from film url...")

        do {
            let html = try await fetchHTML(url: filmInfoURL)
            let parsedEpisodes = parseEpisodes(from: html)
            episodes = parsedEpisodes
            appendLog("Parsed episodes count=\(parsedEpisodes.count)")

            guard let firstEpisode = pickFirstEpisode(parsedEpisodes) else {
                statusText = "Failed"
                appendLog("No episode found.")
                return
            }
            selectedEpisodeDisplay = "\(firstEpisode.label) (id=\(firstEpisode.id))"
            appendLog("Selected first episode: \(selectedEpisodeDisplay)")

            let links = try await resolvePlayableSources(episodeID: firstEpisode.id)
            playableSources = links
            selectedSourceID = links.first?.id
            appendLog("Resolved playable links count=\(links.count)")
            reloadAndPlay()
        } catch {
            statusText = "Failed"
            appendLog("Bootstrap error: \(error.localizedDescription)")
        }
    }

    func reloadAndPlay() {
        guard let urlString = currentPlayableURL,
              let url = URL(string: urlString) else {
            appendLog("Invalid URL")
            return
        }

        let headers: [String: String] = [
            "Referer": "https://phimmoichill.men/",
            "Origin": "https://phimmoichill.men",
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile"
        ]

        let options: [String: Any] = [
            "AVURLAssetHTTPHeaderFieldsKey": headers
        ]
        let asset = AVURLAsset(url: url, options: options)
        let item = AVPlayerItem(asset: asset)

        observeItemStatus(item)
        player.replaceCurrentItem(with: item)
        player.play()
        appendLog("Reloaded source=\(selectedSourceTitle) with headers and started play.")
    }

    var currentPlayableURL: String? {
        playableSources.first(where: { $0.id == selectedSourceID })?.url
    }

    private var selectedSourceTitle: String {
        playableSources.first(where: { $0.id == selectedSourceID })?.title ?? "-"
    }

    private func fetchHTML(url: String) async throws -> String {
        guard let u = URL(string: url) else { throw NSError(domain: "bad_url", code: -1) }
        let (data, response) = try await session.data(from: u)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              let html = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "bad_response", code: -2)
        }
        return html
    }

    private func postForm(url: String, form: String) async throws -> String {
        guard let u = URL(string: url) else { throw NSError(domain: "bad_url", code: -1) }
        var req = URLRequest(url: u)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        req.httpBody = form.data(using: .utf8)
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              let html = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "bad_response", code: -2)
        }
        return html
    }

    private func parseEpisodes(from html: String) -> [Episode] {
        guard let block = firstMatch(
            pattern: #"<div class="latest-episode">([\s\S]*?)</div>"#,
            in: html,
            group: 1
        ) else { return [] }

        guard let regex = try? NSRegularExpression(
            pattern: #"<a[^>]*data-id="(\d+)"[^>]*href="([^"]+)"[^>]*>([^<]*)</a>"#
        ) else { return [] }

        let nsRange = NSRange(block.startIndex..<block.endIndex, in: block)
        let matches = regex.matches(in: block, range: nsRange)

        return matches.compactMap { m in
            guard let idR = Range(m.range(at: 1), in: block),
                  let hrefR = Range(m.range(at: 2), in: block),
                  let labelR = Range(m.range(at: 3), in: block) else { return nil }
            let id = String(block[idR])
            let href = String(block[hrefR])
            let label = String(block[labelR]).trimmingCharacters(in: .whitespacesAndNewlines)
            let tap = extractTapNumber(href: href, label: label)
            return Episode(id: id, tapNumber: tap, href: href, label: label)
        }
    }

    private func pickFirstEpisode(_ eps: [Episode]) -> Episode? {
        let sorted = eps.sorted { (a, b) in
            switch (a.tapNumber, b.tapNumber) {
            case let (x?, y?): return x < y
            case (_?, nil): return true
            case (nil, _?): return false
            default: return a.id < b.id
            }
        }
        return sorted.first
    }

    private func resolvePlayableSources(episodeID: String) async throws -> [PlayableSource] {
        let htmlSv0 = try await postForm(
            url: "https://phimmoichill.men/chillsplayer.php",
            form: "qcao=\(episodeID)&sv=0"
        )
        let htmlSv1 = try await postForm(
            url: "https://phimmoichill.men/chillsplayer.php",
            form: "qcao=\(episodeID)&sv=1"
        )

        let hash0 = extractHash(from: htmlSv0)
        let hash1 = extractHash(from: htmlSv1)
        let hash = hash0 ?? hash1
        guard let hash else {
            throw NSError(domain: "hash_not_found", code: -3)
        }

        let source0 = PlayableSource(
            id: "sv0",
            title: "SV0 listpm/mpeg",
            url: "https://sotrim.listpm.net/mpeg/\(hash)/index.m3u8"
        )
        let source1 = PlayableSource(
            id: "sv1",
            title: "SV1 topphimmoi/raw",
            url: "https://sotrim.topphimmoi.org/raw/\(hash)/index.m3u8"
        )
        return [source0, source1]
    }

    private func extractHash(from html: String) -> String? {
        firstMatch(pattern: #"iniPlayers\("([a-f0-9]{32})""#, in: html, group: 1)
    }

    private func extractTapNumber(href: String, label: String) -> Int? {
        if let byHref = firstMatch(pattern: #"tap-(\d+)"#, in: href, group: 1),
           let v = Int(byHref) { return v }
        if let byLabel = firstMatch(pattern: #"(\d+)"#, in: label, group: 1),
           let v = Int(byLabel) { return v }
        return nil
    }

    private func firstMatch(pattern: String, in text: String, group: Int) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let g = Range(match.range(at: group), in: text) else { return nil }
        return String(text[g])
    }

    func togglePlayPause() {
        if isPlaying {
            player.pause()
            appendLog("Paused.")
        } else {
            player.play()
            appendLog("Play requested.")
        }
    }

    private func configureObservers() {
        timeControlObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            guard let self else { return }
            DispatchQueue.main.async {
                switch player.timeControlStatus {
                case .paused:
                    self.isPlaying = false
                    self.statusText = "Paused"
                case .waitingToPlayAtSpecifiedRate:
                    self.isPlaying = false
                    self.statusText = "Buffering"
                case .playing:
                    self.isPlaying = true
                    self.statusText = "Playing"
                @unknown default:
                    self.isPlaying = false
                    self.statusText = "Unknown"
                }
            }
        }

        failedObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? NSError
            self.statusText = "Failed"
            self.appendLog("Failed to play to end: \(error?.localizedDescription ?? "Unknown error")")
        }
    }

    private func observeItemStatus(_ item: AVPlayerItem) {
        itemStatusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            guard let self else { return }
            DispatchQueue.main.async {
                switch item.status {
                case .unknown:
                    self.statusText = "Loading"
                    self.appendLog("Item status: unknown")
                case .readyToPlay:
                    self.statusText = "Ready"
                    self.appendLog("Item status: readyToPlay")
                case .failed:
                    self.statusText = "Failed"
                    self.appendLog("Item status failed: \(item.error?.localizedDescription ?? "Unknown error")")
                @unknown default:
                    self.appendLog("Item status: unknown default")
                }
            }
        }
    }

    private func appendLog(_ line: String) {
        let ts = Self.timestampFormatter.string(from: Date())
        if logText == "Waiting..." {
            logText = "[\(ts)] \(line)"
        } else {
            logText = "[\(ts)] \(line)\n" + logText
        }
    }

    private static let timestampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()
}

#Preview {
    ContentView()
}
