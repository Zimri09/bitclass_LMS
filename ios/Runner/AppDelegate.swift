import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var quizChannel: FlutterMethodChannel?
  private var quizProtected = false
  private var quizShield: UIView?
  private var quizObservers: [NSObjectProtocol] = []

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let controller = window?.rootViewController as? FlutterViewController {
      quizChannel = FlutterMethodChannel(name: "bitclass/quiz_protection",
                                         binaryMessenger: controller.binaryMessenger)
      quizChannel?.setMethodCallHandler { [weak self] call, result in
        guard let self = self else { result(nil); return }
        switch call.method {
        case "enable":
          self.quizProtected = true
          self.observeQuizCapture()
          self.updateQuizShield()
          if self.window?.screen.isCaptured == true {
            self.quizChannel?.invokeMethod("event", arguments: "capture_active")
          }
          result("ios_capture_detection")
        case "disable":
          self.quizProtected = false
          self.quizObservers.forEach { NotificationCenter.default.removeObserver($0) }
          self.quizObservers.removeAll()
          self.updateQuizShield()
          result(nil)
        default: result(FlutterMethodNotImplemented)
        }
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func observeQuizCapture() {
    guard quizObservers.isEmpty else { return }
    let center = NotificationCenter.default
    quizObservers.append(center.addObserver(forName: UIScreen.capturedDidChangeNotification,
      object: nil, queue: .main) { [weak self] _ in
        guard let self = self else { return }
        self.updateQuizShield()
        if self.window?.screen.isCaptured == true {
          self.quizChannel?.invokeMethod("event", arguments: "capture_active")
        }
      })
    quizObservers.append(center.addObserver(forName: UIApplication.userDidTakeScreenshotNotification,
      object: nil, queue: .main) { [weak self] _ in
        self?.quizChannel?.invokeMethod("event", arguments: "screenshot_taken")
      })
    for name in [UIApplication.willResignActiveNotification,
                 UIApplication.didBecomeActiveNotification] {
      quizObservers.append(center.addObserver(forName: name, object: nil, queue: .main) {
        [weak self] notification in
        self?.updateQuizShield(background: notification.name == UIApplication.willResignActiveNotification)
      })
    }
  }

  private func updateQuizShield(background: Bool? = nil) {
    guard let window = window else { return }
    let hidden = quizProtected && (window.screen.isCaptured ||
      (background ?? (UIApplication.shared.applicationState != .active)))
    if hidden && quizShield == nil {
      let shield = UILabel(frame: window.bounds)
      shield.autoresizingMask = [.flexibleWidth, .flexibleHeight]
      shield.backgroundColor = .systemBackground
      shield.textColor = .label
      shield.textAlignment = .center
      shield.numberOfLines = 0
      shield.text = "Quiz hidden while recording or outside the app.\nStop recording and return to continue."
      shield.isUserInteractionEnabled = true
      window.addSubview(shield)
      quizShield = shield
    } else if !hidden {
      quizShield?.removeFromSuperview()
      quizShield = nil
    }
  }
}
