import Foundation

// MARK: - CastManager
//
// This file provides a stub/wrapper for Google Cast (Chromecast) integration.
//
// The Google Cast SDK is NOT available as a Swift Package Manager package.
// To complete this integration, follow these steps:
//
//  1. Add the GoogleCast SDK via CocoaPods:
//       pod 'google-cast-sdk-no-bluetooth', '~> 4.8'
//     (use the no-bluetooth variant for App Store submissions that lack BLE entitlement)
//
//  2. In your AppDelegate / @UIApplicationDelegateAdaptor:
//       import GoogleCast
//       let options = GCKCastOptions(discoveryCriteria: GCKDiscoveryCriteria(applicationID: CastManager.appId))
//       GCKCastContext.setSharedInstanceWith(options)
//       GCKCastContext.sharedInstance().useDefaultExpandedMediaControls = true
//
//  3. Add NSBonjourServices and NSLocalNetworkUsageDescription to Info.plist as required
//     by the Cast SDK (see Cast iOS SDK Release Notes for exact keys).
//
//  4. Replace the stub bodies below with real GCKRemoteMediaClient / custom channel calls.
//     A custom channel example:
//       let channel = GCKGenericChannel(namespace: CastManager.namespace)
//       let json = try JSONEncoder().encode(state)
//       channel.sendTextMessage(String(data: json, encoding: .utf8) ?? "")
//
//  5. Observe GCKCastContext.sharedInstance().sessionManager to update
//     the `isCasting` and `isConnected` published properties.

class CastManager: ObservableObject {
    static let shared = CastManager()

    @Published var isCasting: Bool = false
    @Published var isConnected: Bool = false

    /// The Cast application ID registered in the Google Cast Developer Console.
    static let appId = "9E3B984D"

    /// The custom Cast namespace used for match state messages.
    static let namespace = "urn:x-cast:com.matt.tennisscorer"

    // Keep instance-level copies for convenience.
    let appId = CastManager.appId
    let namespace = CastManager.namespace

    private let encoder = JSONEncoder()

    private init() {
        // TODO: Register as a GCKSessionManagerListener here once CocoaPods is set up,
        // so that isCasting / isConnected stay in sync with the Cast session state.
    }

    // MARK: - Public API

    /// Encodes the current match state to JSON and sends it to the receiver app
    /// via the custom Cast channel.
    ///
    /// TODO: Replace this stub with real Cast channel logic after CocoaPods setup.
    func sendMatchState(_ state: MatchState) {
        guard isConnected else { return }

        do {
            let data    = try encoder.encode(state)
            let jsonStr = String(data: data, encoding: .utf8) ?? ""
            // TODO: Obtain the active GCKGenericChannel and call:
            //   channel.sendTextMessage(jsonStr)
            _ = jsonStr  // suppress unused-variable warning until wired up
            print("[CastManager] sendMatchState — stub. Payload length: \(jsonStr.count)")
        } catch {
            print("[CastManager] Failed to encode match state: \(error)")
        }
    }

    /// Disconnects the current Cast session.
    ///
    /// TODO: Replace stub with:
    ///   GCKCastContext.sharedInstance().sessionManager.endSessionAndStopCasting(true)
    func disconnect() {
        // TODO: end GCK session
        isConnected = false
        isCasting   = false
        print("[CastManager] disconnect — stub.")
    }

    // MARK: - Internal helpers (for use once Cast SDK is linked)

    /// Call this from the GCKSessionManagerListener callback when a session starts.
    ///
    /// TODO: Hook into GCKSessionManagerListener.sessionManager(_:didStart:) after CocoaPods setup.
    func _onSessionStarted() {
        DispatchQueue.main.async {
            self.isConnected = true
            self.isCasting   = true
        }
    }

    /// Call this from the GCKSessionManagerListener callback when a session ends.
    ///
    /// TODO: Hook into GCKSessionManagerListener.sessionManager(_:didEnd:withError:) after CocoaPods setup.
    func _onSessionEnded() {
        DispatchQueue.main.async {
            self.isConnected = false
            self.isCasting   = false
        }
    }
}
