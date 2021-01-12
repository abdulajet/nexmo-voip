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

typealias PushInfo = (token: PKPushPayload, completion: () -> Void)

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var pushToken: Data?
    var pushInfo: PushInfo?
    let providerDelegate = ProviderDelegate()
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        AVAudioSession.sharedInstance().requestRecordPermission { (granted:Bool) in
            print("Allow microphone use. Response: \(granted)")
        }
        registerForVoIPPushes()
        setupClientIfNeeded()
        return true
    }
    
    func setupClientIfNeeded() {
        guard !NXMClient.shared.isConnected() else { return }
        NXMClient.shared.setDelegate(self)
        NXMClient.shared.login(withAuthToken: "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJpYXQiOjE2MTA0NzE3NDYsImp0aSI6ImNmNDI0OWYwLTU0ZjktMTFlYi05NmI1LTNkYzNhY2QzOTQ5MSIsImV4cCI6MTYxMDQ5MzM0NSwiYWNsIjp7InBhdGhzIjp7Ii8qL3VzZXJzLyoqIjp7fSwiLyovY29udmVyc2F0aW9ucy8qKiI6e30sIi8qL3Nlc3Npb25zLyoqIjp7fSwiLyovZGV2aWNlcy8qKiI6e30sIi8qL2ltYWdlLyoqIjp7fSwiLyovbWVkaWEvKioiOnt9LCIvKi9hcHBsaWNhdGlvbnMvKioiOnt9LCIvKi9wdXNoLyoqIjp7fSwiLyova25vY2tpbmcvKioiOnt9fX0sInN1YiI6ImFiZHVsYWpldCIsImFwcGxpY2F0aW9uX2lkIjoiZTJkZDU3YjUtNTA3MS00NTA2LTg4MjctOGVmYTViOTZmYzlkIn0.acfvGXqD2eh9EHJVhPm29Xtn0JwCrrJbexzludPe6U6Z836AhbAH54H7xkk5oZ5zi9-vBi0dx-UrCGm-rVH-jF8Ged4dXAcCKLfCgPhsvnxcrWeNo8MDtUsZxUpxE-txxtl3d1UAWfkeT7PxlgSKXutETB8cno-Uf8cRburtMPUEtI5_XJrqyKrwg2_AUPCJntek02aDIPxXsXCuQL_pfLjiGAFGGUvK8ONgwteJIGZ22SdvC2jTrQjS-CJ0UpqPV33w49emBR78Acg0JEDmHjAmrGH_LgYcHLyuqQUVhX5TIIESgg0zhRouOaw1XCM3DsRdTO4yPpzb2owWFmAGeQ")
    }
    
    func registerForVoIPPushes() {
        let voipRegistry = PKPushRegistry(queue: nil)
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
        self.pushToken = pushCredentials.token
    }
    
    func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
        invaldatePushToken()
    }
    
    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
        if(NXMClient.shared.isNexmoPush(userInfo: payload.dictionaryPayload)) {
            let pushDict = payload.dictionaryPayload as NSDictionary
            let from = pushDict.value(forKeyPath: "nexmo.push_info.from_user.name") as? String
            
            self.pushInfo = (payload, completion)
            providerDelegate.reportCall(callerID: from ?? "Unknown")
        }
    }
    
    func processPush(with pushInfo: PushInfo) {
        guard let _ = NXMClient.shared.processNexmoPushPayload(pushInfo.token.dictionaryPayload) else {
            print("Not a Nexmo push notification")
            return
        }
        pushInfo.completion()
    }
    
    func enableNXMPushIfNeeded(with token: Data) {
        if shouldRegisterToken(with: token) {
            NXMClient.shared.enablePushNotifications(withPushKitToken: token, userNotificationToken: nil, isSandbox: true) { error in
                if error != nil {
                    print("registration error: \(String(describing: error))")
                }
                print("push token registered")
                UserDefaults.standard.setValue(token, forKey: "NXMPushToken")
            }
        }
    }
    
    func shouldRegisterToken(with token: Data) -> Bool {
        let storedToken = UserDefaults.standard.object(forKey: "NXMPushToken") as? Data
        
        if let storedToken = storedToken, storedToken == token {
            return false
        }
        
        invaldatePushToken()
        return true
    }
    
    func invaldatePushToken() {
        self.pushToken = nil
        UserDefaults.standard.removeObject(forKey: "NXMPushToken")
        NXMClient.shared.disablePushNotifications(nil)
    }
}

extension AppDelegate: NXMClientDelegate {
    func client(_ client: NXMClient, didChange status: NXMConnectionStatus, reason: NXMConnectionStatusReason) {
        let statusText: String
        
        switch status {
        case .connected:
            if let token = pushToken {
                enableNXMPushIfNeeded(with: token)
            }
            if let pushInfo = pushInfo {
                processPush(with: pushInfo)
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
        NotificationCenter.default.post(name: Notification.Name("Call"), object: self, userInfo: ["call": call])
    }
}
