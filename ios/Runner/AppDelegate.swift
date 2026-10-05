import Flutter
import UIKit

/// One bounded, expiring in-memory slot. Delivery never creates a route name.
final class RecoveryIngress {
  private var pending: (String, TimeInterval)?
  private var expiry: Timer?
  deinit { expiry?.invalidate() }
  private(set) var ready = false
  var send: ((String) -> Void)?
  var now: () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
  let origin: URLComponents?
  let localPort: Int?

  init(origin: String, localPort: Int? = nil) {
    let candidate = URLComponents(string: origin)
    if let value = candidate, value.scheme == "https", !(value.host ?? "").isEmpty,
       value.user == nil, value.password == nil, value.query == nil,
       value.fragment == nil, value.path.isEmpty || value.path == "/" {
      self.origin = value
    } else { self.origin = nil }
    self.localPort = localPort
  }

  func payload(_ url: URL) -> String? {
    guard let value = URLComponents(url: url, resolvingAgainstBaseURL: false),
          value.path == "/reset-password" else { return nil }
    // The local custom scheme is compiled/registered only by the Local Debug helper.
    if let port = localPort, value.scheme == "emie-local-recovery", value.host == "recover" {
      guard url.absoluteString.utf8.count <= 4096, value.user == nil,
            value.password == nil, value.port == nil, value.fragment == nil else {
        return "/reset-password"
      }
      var mapped = value
      mapped.scheme = "http"; mapped.host = "127.0.0.1"; mapped.port = port
      return mapped.string ?? "/reset-password"
    }
    guard let expected = origin, value.scheme == expected.scheme,
          value.host == expected.host, (value.port ?? 443) == (expected.port ?? 443)
    else { return nil } // Unrelated plugin URLs/activities retain their normal lifecycle.
    guard url.absoluteString.utf8.count <= 4096 else { return "/reset-password" }
    return url.absoluteString // Dart retains all query/proof/session validation.
  }

  @discardableResult func accept(_ url: URL) -> Bool {
    guard let value = payload(url) else { return false }
    if ready { send?(value) } else {
      pending = (value, now())
      expiry?.invalidate()
      expiry = Timer.scheduledTimer(withTimeInterval: 60, repeats: false) { [weak self] _ in
        self?.pending = nil
        self?.expiry = nil
      }
    }
    return true
  }

  func takeInitial() -> String? {
    ready = true
    expiry?.invalidate()
    expiry = nil
    let value = pending
    pending = nil
    guard let value = value, now() - value.1 <= 60 else { return nil }
    return value.0
  }
}

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var configChannel: FlutterMethodChannel?
  private var recoveryChannel: FlutterMethodChannel?
  lazy var recovery: RecoveryIngress = {
    var port: Int? = nil
    #if DEBUG && EMIE_LOCAL
    if let configured = Bundle.main.object(forInfoDictionaryKey: "EMIELocalPort") as? Int,
       (8010...8019).contains(configured) { port = configured }
    #endif
    return RecoveryIngress(origin: Bundle.main.object(forInfoDictionaryKey: "EMIERecoveryOrigin") as? String ?? "", localPort: port)
  }()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    var forwarded = launchOptions
    if let url = launchOptions?[.url] as? URL, recovery.accept(url) {
      forwarded?.removeValue(forKey: .url)
    }
    if var activities = launchOptions?[.userActivityDictionary] as? [AnyHashable: Any] {
      for (key, value) in activities {
        if let activity = value as? NSUserActivity,
           activity.activityType == NSUserActivityTypeBrowsingWeb,
           let url = activity.webpageURL, recovery.accept(url) {
          activities.removeValue(forKey: key)
        }
      }
      forwarded?[.userActivityDictionary] = activities
    }
    GeneratedPluginRegistrant.register(with: self)
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(name: "ai.emie.app/recovery", binaryMessenger: controller.binaryMessenger)
      recoveryChannel = channel
      let config = FlutterMethodChannel(name: "ai.emie.app/config", binaryMessenger: controller.binaryMessenger)
      configChannel = config
      config.setMethodCallHandler { call, result in
        guard call.method == "googleAvailable" else { result(FlutterMethodNotImplemented); return }
        let client = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String ?? ""
        let server = Bundle.main.object(forInfoDictionaryKey: "GIDServerClientID") as? String ?? ""
        let types = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] ?? []
        let schemes = types.flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] }
        let reversed = client.split(separator: ".").reversed().joined(separator: ".")
        let pattern = #"^[A-Za-z0-9_-]+\.apps\.googleusercontent\.com$"#
        result(client.range(of: pattern, options: .regularExpression) != nil &&
               server.range(of: pattern, options: .regularExpression) != nil && schemes.contains(reversed))
      }
      recovery.send = { [weak channel] value in channel?.invokeMethod("resetLink", arguments: value) }
      channel.setMethodCallHandler { [weak self] call, result in
        if call.method == "takeInitial" { result(self?.recovery.takeInitial()) }
        else { result(FlutterMethodNotImplemented) }
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: forwarded)
  }

  override func application(_ app: UIApplication, open url: URL,
                           options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
    if recovery.accept(url) { return true }
    return super.application(app, open: url, options: options)
  }

  override func application(_ application: UIApplication, continue userActivity: NSUserActivity,
                           restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
    if userActivity.activityType == NSUserActivityTypeBrowsingWeb,
       let url = userActivity.webpageURL, recovery.accept(url) { return true }
    return super.application(application, continue: userActivity, restorationHandler: restorationHandler)
  }
}
