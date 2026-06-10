import Foundation
import AVKit
import AVFoundation
import Flutter

// ══════════════════════════════════════════════════════════════
// CastHostApiImpl — iOS implementation of the Pigeon CastHostApi
//
// On iOS, we use:
// 1. AVRouteDetector — Detects available AirPlay devices.
// 2. AVRoutePickerView — Native iOS AirPlay picker button.
// 3. AVPlayer with allowsExternalPlayback = true — Enables
//    AirPlay output for any content loaded in the player.
//
// Note: iOS does NOT support Google Cast (Chromecast) natively.
// The Chromecast-related APIs (startDiscovery, connectToDevice)
// are no-ops on iOS. Only AirPlay is supported on this platform.
// ══════════════════════════════════════════════════════════════

class CastHostApiImpl: NSObject, CastHostApi {

    private var flutterApi: CastFlutterApi?
    private var routeDetector: AVRouteDetector?
    private var isDiscovering = false
    private var connectedDeviceId = ""
    private var player: AVPlayer?

    // ── AirPlay picker view reference ──
    private var routePickerView: AVRoutePickerView?

    init(binaryMessenger: FlutterBinaryMessenger) {
        super.init()
        self.flutterApi = CastFlutterApi(binaryMessenger: binaryMessenger)
        setupRouteDetector()
    }

    // ══════════════════ Setup ══════════════════

    private func setupRouteDetector() {
        routeDetector = AVRouteDetector()
        routeDetector?.routeDetectionEnabled = true

        // Observe when routes become available/unavailable
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(routesChanged),
            name: AVRouteDetectorMultipleRoutesDetectedDidChangeNotification,
            object: routeDetector
        )
    }

    @objc private func routesChanged(notification: Notification) {
        guard let detector = routeDetector else { return }
        let multipleRoutesAvailable = detector.multipleRoutesDetected

        if multipleRoutesAvailable {
            // AirPlay devices are available. Since iOS doesn't expose
            // individual device names through public API (only through
            // the picker), we report a generic "AirPlay" device.
            let device = CastDevice(
                deviceId: "airplay_tv",
                name: "AirPlay TV",
                platform: "airplay"
            )
            flutterApi?.onDeviceDiscovered(device: device)
        } else {
            // No AirPlay devices available
            flutterApi?.onDeviceLost(deviceId: "airplay_tv")
        }
    }

    // ══════════════════ Host API Implementation ══════════════════

    func startDiscovery() {
        // On iOS, AVRouteDetector auto-discovers AirPlay devices.
        // We just enable route detection which starts the process.
        isDiscovering = true
        routeDetector?.routeDetectionEnabled = true

        // Check current state immediately
        if let detector = routeDetector, detector.multipleRoutesDetected {
            let device = CastDevice(
                deviceId: "airplay_tv",
                name: "AirPlay TV",
                platform: "airplay"
            )
            flutterApi?.onDeviceDiscovered(device: device)
        }
    }

    func stopDiscovery() {
        isDiscovering = false
        // Keep route detection enabled for the picker to work,
        // but we can disable if we want to save resources.
        // routeDetector?.routeDetectionEnabled = false
    }

    func connectToDevice(deviceId: String) {
        // On iOS, you cannot programmatically connect to an AirPlay device.
        // The user must select the device from the native AirPlay picker.
        // We show the picker instead.
        showAirPlayPicker()

        // Once the user selects a device, AVPlayer's external playback
        // will route audio/video to the selected AirPlay device.
        connectedDeviceId = deviceId
        flutterApi?.onConnected(deviceId: deviceId)
    }

    func disconnect() {
        // To disconnect from AirPlay, we can set the player's
        // allowsExternalPlayback to false temporarily.
        player?.allowsExternalPlayback = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.player?.allowsExternalPlayback = true
        }
        connectedDeviceId = ""
        flutterApi?.onDisconnected()
    }

    func loadMedia(mediaUrl: String, title: String, contentType: String) {
        guard let url = URL(string: mediaUrl) else {
            flutterApi?.onError(errorMessage: "Invalid media URL: \(mediaUrl)")
            return
        }

        // Create or update the AVPlayer with the new URL
        let playerItem = AVPlayerItem(url: url)
        if player == nil {
            player = AVPlayer(playerItem: playerItem)
        } else {
            player?.replaceCurrentItem(with: playerItem)
        }

        // Enable AirPlay external playback
        player?.allowsExternalPlayback = true
        player?.usesExternalPlaybackWhileExternalScreenIsActive = true

        // Observe player status
        observePlayerStatus(title: title)

        // Start playback
        player?.play()
    }

    func play() {
        player?.play()
    }

    func pause() {
        player?.pause()
    }

    func seekTo(positionSeconds: Double) {
        let time = CMTime(seconds: positionSeconds, preferredTimescale: 1)
        player?.seek(to: time)
    }

    func setVolume(volume: Double) {
        player?.volume = Float(volume.clamped(to: 0.0...1.0))
    }

    func showAirPlayPicker() {
        // Present the native AirPlay route picker.
        // This requires finding the current UIViewController.
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            guard let rootVC = self.getRootViewController() else {
                self.flutterApi?.onError(errorMessage: "Could not find root view controller")
                return
            }

            let pickerView = AVRoutePickerView()
            pickerView.delegate = self
            self.routePickerView = pickerView

            // Present the picker as a popover from the center of the screen
            let pickerButton = pickerView.subviews.first(where: { $0 is UIButton }) as? UIButton
            if let button = pickerButton {
                button.sendActions(for: .touchUpInside)
            } else {
                // Fallback: add picker view temporarily and activate it
                pickerView.frame = CGRect(x: 0, y: 0, width: 1, height: 1)
                rootVC.view.addSubview(pickerView)
                pickerView.alpha = 0.01

                // Trigger the picker
                if let button = pickerView.subviews.first(where: { $0 is UIButton }) as? UIButton {
                    button.sendActions(for: .touchUpInside)
                }
            }
        }
    }

    func getConnectedDeviceId() -> String {
        return connectedDeviceId
    }

    // ══════════════════ Private Helpers ══════════════════

    private func getRootViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = scene.windows.first?.rootViewController else {
            return nil
        }
        return rootVC
    }

    private var playerStatusObservation: NSKeyValueObservation?
    private var playerItemStatusObservation: NSKeyValueObservation?
    private var playerRateObservation: NSKeyValueObservation?
    private var currentItemObservation: NSKeyValueObservation?

    private func observePlayerStatus(title: String) {
        // Observe playback rate (playing / paused)
        playerRateObservation = player?.observe(\.rate, options: [.new]) { [weak self] player, change in
            guard let self = self else { return }
            let state: String
            if player.rate > 0 {
                state = "playing"
            } else if player.currentTime().seconds > 0 {
                state = "paused"
            } else {
                state = "idle"
            }

            let playerState = CastPlayerState(
                state: state,
                position: player.currentTime().seconds,
                duration: player.currentItem?.duration.seconds ?? 0.0,
                volume: Double(player.volume),
                mediaTitle: title
            )
            self.flutterApi?.onPlayerStateChanged(state: playerState)
        }

        // Observe item status for buffering / error
        playerItemStatusObservation = player?.currentItem?.observe(\.status, options: [.new]) { [weak self] item, _ in
            guard let self = self else { return }
            switch item.status {
            case .failed:
                self.flutterApi?.onError(errorMessage: item.error?.localizedDescription ?? "Playback failed")
            case .readyToPlay:
                // Item is ready, send updated state with duration
                let playerState = CastPlayerState(
                    state: "playing",
                    position: self.player?.currentTime().seconds ?? 0.0,
                    duration: item.duration.seconds,
                    volume: Double(self.player?.volume ?? 1.0),
                    mediaTitle: title
                )
                self.flutterApi?.onPlayerStateChanged(state: playerState)
            default:
                break
            }
        }
    }
}

// ══════════════════ AVRoutePickerViewDelegate ══════════════════

extension CastHostApiImpl: AVRoutePickerViewDelegate {
    func routePickerViewDidEndPresenting(_ routePickerView: AVRoutePickerView) {
        // User finished interacting with the AirPlay picker
    }

    func routePickerView(_ routePickerView: AVRoutePickerView, didUpdate routes: [AVRoute]) {
        // Routes were updated (device connected/disconnected)
        if let selectedRoute = routes.first(where: { $0.isPicked }) {
            let deviceName = selectedRoute.playerProvider?.displayName ?? "AirPlay Device"
            connectedDeviceId = selectedRoute.routeName
            flutterApi?.onConnected(deviceId: connectedDeviceId)

            let device = CastDevice(
                deviceId: connectedDeviceId,
                name: deviceName,
                platform: "airplay"
            )
            flutterApi?.onDeviceDiscovered(device: device)
        }
    }
}

// ══════════════════ Double Extension ══════════════════

extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        return min(max(self, range.lowerBound), range.upperBound)
    }
}
