import Flutter
import UIKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Configure audio session for background playback + PTT recording
    let audioSession = AVAudioSession.sharedInstance()
    try? audioSession.setCategory(.playAndRecord, options: [.defaultToSpeaker, .allowBluetooth])
    try? audioSession.setActive(true)

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
