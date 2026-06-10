import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate {

    private var castApiImpl: CastHostApiImpl?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        let controller = window?.rootViewController as? FlutterViewController
        if let controller = controller {
            let binaryMessenger = controller.binaryMessenger

            // Initialize our Cast Host API implementation
            castApiImpl = CastHostApiImpl(binaryMessenger: binaryMessenger)

            // Register the Pigeon Host API handler
            CastHostApiSetup.setup(binaryMessenger: binaryMessenger, api: castApiImpl)

            // Also handle the legacy MethodChannel for screen mirroring
            let screenCastChannel = FlutterMethodChannel(
                name: "biblepresenter/screencast",
                binaryMessenger: binaryMessenger
            )
            screenCastChannel.setMethodCallHandler { (call, result) in
                if call.method == "openScreenMirror" {
                    // On iOS, open the AirPlay settings via the picker
                    self.castApiImpl?.showAirPlayPicker()
                    result(nil)
                } else {
                    result(FlutterMethodNotImplemented)
                }
            }
        }

        // Configure audio session for AirPlay playback
        configureAudioSession()

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    private func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            // Set category to playback to allow AirPlay output
            try audioSession.setCategory(.playback, mode: .default, options: [.allowAirPlay])
            try audioSession.setActive(true)
        } catch {
            print("[BiblePresenter] Failed to configure audio session: \(error)")
        }
    }
}
