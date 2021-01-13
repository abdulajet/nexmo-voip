import PushKit
import NexmoClient

typealias PushInfo = (token: PKPushPayload, completion: () -> Void)

final class ClientManager: NSObject {
    public var pushToken: Data?
    public var pushInfo: PushInfo?
    
    static let shared = ClientManager()
    
    static let jwt = "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJpYXQiOjE2MTA1NDczMDIsImp0aSI6ImJhNjNhYWEwLTU1YTktMTFlYi1hMTg0LWM5YzQ4MDAzZWYxMyIsImV4cCI6MTYxMDU2ODkwMiwiYWNsIjp7InBhdGhzIjp7Ii8qL3VzZXJzLyoqIjp7fSwiLyovY29udmVyc2F0aW9ucy8qKiI6e30sIi8qL3Nlc3Npb25zLyoqIjp7fSwiLyovZGV2aWNlcy8qKiI6e30sIi8qL2ltYWdlLyoqIjp7fSwiLyovbWVkaWEvKioiOnt9LCIvKi9hcHBsaWNhdGlvbnMvKioiOnt9LCIvKi9wdXNoLyoqIjp7fSwiLyova25vY2tpbmcvKioiOnt9fX0sInN1YiI6ImFiZHVsYWpldCIsImFwcGxpY2F0aW9uX2lkIjoiZTJkZDU3YjUtNTA3MS00NTA2LTg4MjctOGVmYTViOTZmYzlkIn0.vFLWE0xIab79glK6-29Ya5DnWLNSGXBIwDRpTaODvKB01An9VjiVn6cMgndZsKnQNGILKw868H2ymC8pz3yZkTVdsAMCOk0tMviRsbZUDZBeNocC2KPuBvm3CB-nRmyW4o1xeCQ7BErbH2mYFnaz0ba8kocmjyrjShba2O4gOJJLhdPaCs6E7P7me13RCd1fAhO5WK_MkM5AVNyVScYTgT5hANH9bDWz0_D6qz45-XHm3xR-GSDyi45DwMoii-6dnZT7e2yxT28JHxTOwNdvhxQ1XV0-RZJgICk355jkME8SWauqZdO4wmM2zEU-k_V1ZZ4Tw9H2OQdzTOZogEWo8w"
    
    override init() {
        super.init()
        initializeClient()
    }
    
    func initializeClient() {
        NXMClient.shared.setDelegate(self)
    }
    
    func login(with token: String) {
        guard !NXMClient.shared.isConnected() else { return }
        NXMClient.shared.login(withAuthToken: ClientManager.jwt)
    }
    
    func isNexmoPush(with userInfo: [AnyHashable : Any]) -> Bool {
        return NXMClient.shared.isNexmoPush(userInfo: userInfo)
    }
    
    func invalidatePushToken() {
        self.pushToken = nil
        UserDefaults.standard.removeObject(forKey: Constants.pushToken)
        NXMClient.shared.disablePushNotifications(nil)
    }
    
    // MARK:-  Private
    
    private func processNexmoPushPayload(with pushInfo: PushInfo) {
        guard let _ = NXMClient.shared.processNexmoPushPayload(pushInfo.token.dictionaryPayload) else {
            print("Nexmo push processing error")
            return
        }
        pushInfo.completion()
        self.pushInfo = nil
    }
    
    private func enableNXMPushIfNeeded(with token: Data) {
        if shouldRegisterToken(with: token) {
            NXMClient.shared.enablePushNotifications(withPushKitToken: token, userNotificationToken: nil, isSandbox: true) { error in
                if error != nil {
                    print("registration error: \(String(describing: error))")
                }
                print("push token registered")
                UserDefaults.standard.setValue(token, forKey: Constants.pushToken)
            }
        }
    }
    
    private func shouldRegisterToken(with token: Data) -> Bool {
        let storedToken = UserDefaults.standard.object(forKey: Constants.pushToken) as? Data
        
        if let storedToken = storedToken, storedToken == token {
            return false
        }
        
        invalidatePushToken()
        return true
    }
    
}

// MARK:-  NXMClientDelegate

extension ClientManager: NXMClientDelegate {
    
    func client(_ client: NXMClient, didChange status: NXMConnectionStatus, reason: NXMConnectionStatusReason) {
        let statusText: String
        
        switch status {
        case .connected:
            if let token = pushToken {
                enableNXMPushIfNeeded(with: token)
            }
            if let pushInfo = pushInfo {
                processNexmoPushPayload(with: pushInfo)
            }
            statusText = "Connected"
        case .disconnected:
            statusText = "Disconnected"
        case .connecting:
            statusText = "Connecting"
        @unknown default:
            statusText = "Unknown"
        }
        
        NotificationCenter.default.post(name: .clientStatus, object: statusText)
    }
    
    func client(_ client: NXMClient, didReceiveError error: Error) {
        NotificationCenter.default.post(name: .clientStatus, object: error.localizedDescription)
    }
    
    func client(_ client: NXMClient, didReceive call: NXMCall) {
        NotificationCenter.default.post(name: .incomingCall, object: call)
    }
}

// MARK:-  Constants

struct Constants {
    static let pushToken = "NXMPushToken"
    static let fromKeyPath = "nexmo.push_info.from_user.name"
}

extension Notification.Name {
    static let clientStatus = Notification.Name("Status")
    static let incomingCall = Notification.Name("Call")
}
