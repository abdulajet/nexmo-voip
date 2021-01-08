//
//  AppDelegate.swift
//  PhoneToApp
//
//  Created by Abdulhakim Ajetunmobi on 06/07/2020.
//  Copyright © 2020 Vonage. All rights reserved.
//

import UIKit
import PushKit
import NexmoClient
import AVFoundation

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var pushToken: Data?
    var pushPayload: PKPushPayload?
    let callManager = CallManager()
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        AVAudioSession.sharedInstance().requestRecordPermission { (granted:Bool) in
            print("Allow microphone use. Response: %d", granted)
        }
        setupClientIfNeeded()
        registerForVoIPPushes()
        return true
    }
    
    func setupClientIfNeeded() {
        guard !NXMClient.shared.isConnected() else { return }
        
        NXMClient.shared.login(withAuthToken: "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJpYXQiOjE2MTAxMTUwMDQsImp0aSI6IjM0Mzc4NGMwLTUxYmItMTFlYi1iMjBhLTFiNGUyMTA4MmY5OSIsImV4cCI6MTYxMDEzNjYwMiwiYWNsIjp7InBhdGhzIjp7Ii8qL3VzZXJzLyoqIjp7fSwiLyovY29udmVyc2F0aW9ucy8qKiI6e30sIi8qL3Nlc3Npb25zLyoqIjp7fSwiLyovZGV2aWNlcy8qKiI6e30sIi8qL2ltYWdlLyoqIjp7fSwiLyovbWVkaWEvKioiOnt9LCIvKi9hcHBsaWNhdGlvbnMvKioiOnt9LCIvKi9wdXNoLyoqIjp7fSwiLyova25vY2tpbmcvKioiOnt9fX0sInN1YiI6ImFiZHVsYWpldCIsImFwcGxpY2F0aW9uX2lkIjoiZTJkZDU3YjUtNTA3MS00NTA2LTg4MjctOGVmYTViOTZmYzlkIn0.snHXptf0Y5hcbG2fGBpIszrSt9QWuKIgBsenLIl1BTIeA8v85dbnEbB7jGV-3rUPpB_K_7FSOgMa-EvZZ86fy-gzVgMiQbNi3HbLZk8UyGUQ0Ru3JFrvATlJyAmrFww4yGui4EqNJIVyw4OkLBHzaWJIZisx73GIprRpU_5RG5QvuyUEQgc6Mu8fu3tkXTUBPNO3ukPJvallZJtsOxIFrQrvpwWd8C3nbThvsD-s6XPOO4CyTu22haABuGfg58r372i9WfsjNwrfroSoFyNuCnFFtSF1rWqE-3h8dE0LzPflq2MPQz0W3fJUwv-GkP7sVeXxSsNCH1ZVYQSZjUc2bQ")
        NXMClient.shared.setDelegate(self)
    }
    
    func registerForVoIPPushes() {
        let voipRegistry = PKPushRegistry(queue: DispatchQueue.main)
        voipRegistry.delegate = self
        voipRegistry.desiredPushTypes = [PKPushType.voIP]
    }
    
    // MARK: UISceneSession Lifecycle
    
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
    
    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {}
}

extension AppDelegate: PKPushRegistryDelegate {
    func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
        if NXMClient.shared.isConnected() {
            enableNXMPush(with: pushCredentials.token)
        } else {
            setupClientIfNeeded()
            self.pushToken = pushCredentials.token
        }
    }
    
    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
        if(NXMClient.shared.isNexmoPush(userInfo: payload.dictionaryPayload) && UIApplication.shared.applicationState == .background) {
            if NXMClient.shared.isConnected() {
                processPush(with: payload)
            } else {
                setupClientIfNeeded()
                self.pushPayload = payload
            }
        }
    }
    
    func processPush(with payload: PKPushPayload) {
        guard let nexmoPayload = NXMClient.shared.processNexmoPushPayload(payload.dictionaryPayload) else {
            print("Not a Nexmo push notification")
            return
        }
        
        let pushInfo = nexmoPayload.eventData?["push_info"] as? NSDictionary
        let from = pushInfo?["from_user"] as? NSDictionary
        
        self.callManager.reportCall(callerID: (from?["name"] as? String ?? "Unknown"))
    }
    
    func enableNXMPush(with token: Data) {
        NXMClient.shared.enablePushNotifications(withPushKitToken: token, userNotificationToken: nil, isSandbox: true) { error in
            if error != nil {
                print("registration error: \(String(describing: error))")
            }
            print("push token registered")
        }
    }
}


extension AppDelegate: NXMClientDelegate {
    func client(_ client: NXMClient, didChange status: NXMConnectionStatus, reason: NXMConnectionStatusReason) {
        let statusText: String
        
        switch status {
        case .connected:
            if let token = pushToken {
                enableNXMPush(with: token)
            }
            if let payload = pushPayload {
                processPush(with: payload)
            }
            statusText = "Connected"
        case .disconnected:
            statusText = "Disconnected"
        case .connecting:
            statusText = "Connecting"
        @unknown default:
            statusText = "Unknown"
        }
        
        NotificationCenter.default.post(name: Notification.Name("Status"), object: self, userInfo: ["status": statusText])
    }
    
    func client(_ client: NXMClient, didReceiveError error: Error) {
        NotificationCenter.default.post(name: Notification.Name("Status"), object: self, userInfo: ["status": error.localizedDescription])
    }
    
    func client(_ client: NXMClient, didReceive call: NXMCall) {
        DispatchQueue.main.async { [weak self] in
            if UIApplication.shared.applicationState == .background {
                self?.callManager.activeCall = call
            } else {
                NotificationCenter.default.post(name: Notification.Name("Call"), object: self, userInfo: ["call": call])
            }
        }
    }
    
}
