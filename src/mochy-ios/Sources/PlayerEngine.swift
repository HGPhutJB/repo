import Foundation
import AVFoundation
import MediaPlayer
import UIKit

extension Notification.Name {
    static let playerStateChanged = Notification.Name("MochyiOSPlayerStateChanged")
    static let playerTimeChanged = Notification.Name("MochyiOSPlayerTimeChanged")
    static let playerFailed = Notification.Name("MochyiOSPlayerFailed")
}

/// Bộ phát nhạc: hàng đợi, AVPlayer, phát nền, điều khiển ở màn hình khoá.
final class PlayerEngine: NSObject {
    static let shared = PlayerEngine()

    private(set) var queue: [Song] = []
    private(set) var index: Int = -1
    private(set) var isPlaying = false
    private(set) var isLoading = false
    private(set) var duration: Double = 0
    private(set) var currentTime: Double = 0
    private(set) var artwork: UIImage?
    private(set) var lastError: String?

    var currentSong: Song? {
        if index >= 0 && index < queue.count { return queue[index] }
        return nil
    }

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var statusObservation: NSKeyValueObservation?
    private var endObserver: NSObjectProtocol?
    private var requestToken = 0
    private var resumeAfterInterruption = false

    private override init() {
        super.init()
        configureAudioSession()
        configureRemoteCommands()
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(handleInterruption(_:)),
                           name: AVAudioSession.interruptionNotification, object: nil)
        center.addObserver(self, selector: #selector(handleRouteChange(_:)),
                           name: AVAudioSession.routeChangeNotification, object: nil)
    }

    // MARK: - Điều khiển

    func play(queue: [Song], index: Int) {
        guard index >= 0 && index < queue.count else { return }
        self.queue = queue
        self.index = index
        startCurrent()
    }

    func togglePlayPause() {
        if isPlaying { pause() } else { resume() }
    }

    func resume() {
        guard let player = player, !isLoading else { return }
        try? AVAudioSession.sharedInstance().setActive(true)
        player.play()
        isPlaying = true
        postState()
        updateNowPlayingInfo()
    }

    func pause() {
        guard let player = player else { return }
        player.pause()
        isPlaying = false
        postState()
        updateNowPlayingInfo()
    }

    func next() {
        if index + 1 < queue.count {
            index += 1
            startCurrent()
        } else {
            pause()
            seek(to: 0)
        }
    }

    func previous() {
        if currentTime > 3 || index <= 0 {
            seek(to: 0)
        } else {
            index -= 1
            startCurrent()
        }
    }

    func seek(to seconds: Double) {
        guard let player = player else { return }
        let target = CMTime(seconds: max(0, seconds), preferredTimescale: 600)
        player.seek(to: target) { [weak self] _ in
            DispatchQueue.main.async {
                self?.currentTime = max(0, seconds)
                self?.updateNowPlayingInfo()
                NotificationCenter.default.post(name: .playerTimeChanged, object: nil)
            }
        }
    }

    // MARK: - Nội bộ

    private func startCurrent() {
        guard let song = currentSong else { return }
        requestToken += 1
        let token = requestToken
        teardownPlayer()
        isLoading = true
        isPlaying = false
        duration = 0
        currentTime = 0
        artwork = nil
        lastError = nil
        postState()
        updateNowPlayingInfo()
        loadArtwork(for: song, token: token)

        InnerTube.shared.resolveStream(videoId: song.videoId) { [weak self] result in
            guard let self = self, token == self.requestToken else { return }
            switch result {
            case .success(let info):
                self.begin(info)
            case .failure(let error):
                self.fail(error)
            }
        }
    }

    private func begin(_ info: StreamInfo) {
        try? AVAudioSession.sharedInstance().setActive(true)
        let options: [String: Any] = ["AVURLAssetHTTPHeaderFieldsKey": ["User-Agent": info.userAgent]]
        let asset = AVURLAsset(url: info.url, options: options)
        let item = AVPlayerItem(asset: asset)
        let newPlayer = AVPlayer(playerItem: item)
        player = newPlayer

        statusObservation = item.observe(\.status, options: [.new]) { [weak self] observedItem, _ in
            DispatchQueue.main.async {
                self?.itemStatusChanged(observedItem)
            }
        }
        timeObserver = newPlayer.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: DispatchQueue.main
        ) { [weak self] time in
            self?.tick(time)
        }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: OperationQueue.main
        ) { [weak self] _ in
            self?.next()
        }
        newPlayer.play()
    }

    private func itemStatusChanged(_ item: AVPlayerItem) {
        guard item === player?.currentItem else { return }
        switch item.status {
        case .readyToPlay:
            let seconds = item.duration.seconds
            duration = seconds.isFinite ? seconds : 0
            isLoading = false
            isPlaying = true
            postState()
            updateNowPlayingInfo()
        case .failed:
            let error: Error = item.error ?? MochyError.playback("AVPlayer báo lỗi không rõ")
            fail(error)
        default:
            break
        }
    }

    private func tick(_ time: CMTime) {
        let seconds = time.seconds
        if seconds.isFinite { currentTime = seconds }
        NotificationCenter.default.post(name: .playerTimeChanged, object: nil)
    }

    private func fail(_ error: Error) {
        teardownPlayer()
        isLoading = false
        isPlaying = false
        let message = describe(error)
        lastError = message
        postState()
        updateNowPlayingInfo()
        NotificationCenter.default.post(name: .playerFailed, object: nil, userInfo: ["message": message])
    }

    private func describe(_ error: Error) -> String {
        if let mochy = error as? MochyError {
            return mochy.errorDescription ?? "Lỗi không rõ"
        }
        let ns = error as NSError
        var text = "\(ns.localizedDescription) [\(ns.domain) \(ns.code)]"
        if let underlying = ns.userInfo[NSUnderlyingErrorKey] as? NSError {
            text += "\n↳ \(underlying.localizedDescription) [\(underlying.domain) \(underlying.code)]"
        }
        return text
    }

    private func teardownPlayer() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
        if let end = endObserver {
            NotificationCenter.default.removeObserver(end)
            endObserver = nil
        }
        statusObservation?.invalidate()
        statusObservation = nil
        player?.pause()
        player = nil
    }

    private func loadArtwork(for song: Song, token: Int) {
        guard let url = song.thumbnailURL else { return }
        ImageLoader.shared.load(url) { [weak self] image in
            guard let self = self, token == self.requestToken, let image = image else { return }
            self.artwork = image
            self.postState()
            self.updateNowPlayingInfo()
        }
    }

    private func postState() {
        NotificationCenter.default.post(name: .playerStateChanged, object: nil)
    }

    // MARK: - Hệ thống

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [])
        try? session.setActive(true)
    }

    private func configureRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in
            self?.resume()
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            self?.next()
            return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            self?.previous()
            return .success
        }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            if let positionEvent = event as? MPChangePlaybackPositionCommandEvent {
                self?.seek(to: positionEvent.positionTime)
            }
            return .success
        }
    }

    private func updateNowPlayingInfo() {
        guard let song = currentSong else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: song.title,
            MPMediaItemPropertyArtist: song.artist,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]
        if duration > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = duration
        }
        if let image = artwork {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    @objc private func handleInterruption(_ notification: Notification) {
        guard let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
        if type == .began {
            resumeAfterInterruption = isPlaying
            if isPlaying { pause() }
        } else {
            let optionsRaw = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsRaw)
            if resumeAfterInterruption && options.contains(.shouldResume) {
                resume()
            }
            resumeAfterInterruption = false
        }
    }

    @objc private func handleRouteChange(_ notification: Notification) {
        guard let raw = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: raw) else { return }
        if reason == .oldDeviceUnavailable && isPlaying {
            DispatchQueue.main.async { [weak self] in
                self?.pause()
            }
        }
    }
}
