//
//  CallManager.swift
//  PhoneToApp
//
//  Created by Abdulhakim Ajetunmobi on 07/01/2021.
//  Copyright © 2021 Vonage. All rights reserved.
//

import CallKit
import NexmoClient
import AVFoundation

final class CallManager: NSObject {
    private var cxProvider: CXProvider?
    private let callController = CXCallController()
    private var calls: [UUID] = []
    public var activeCall: NXMCall?
    
    override init() {
        super.init()
        let cxConfig = CXProviderConfiguration(localizedName: "Nexmo Call")
        cxConfig.supportsVideo = false
        cxConfig.supportedHandleTypes = [.generic]
        self.cxProvider = CXProvider(configuration: cxConfig)
        self.cxProvider?.setDelegate(self, queue: nil)
    }

    func addCall(uuid: UUID) {
        self.calls.append(uuid)
    }

    func removeCall(uuid: UUID) {
        self.calls.removeAll { $0 == uuid }
    }

    func reset() {
        self.calls.removeAll()
    }
}

extension CallManager: CXProviderDelegate {
    func providerDidReset(_ provider: CXProvider) {
        self.reset()
    }
    
    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        guard activeCall != nil else { return }
        activeCall?.answer(nil)
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        configureAudioSession(with: audioSession)
    }
    
    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        self.activeCall?.hangup()
        self.removeCall(uuid: action.callUUID)
        action.fulfill()
    }
    
    func endCall(with uuid: UUID) {
        let transaction = CXTransaction(action: CXEndCallAction(call: uuid))
        callController.request(transaction) { error in
            guard error == nil else {
                //Handle error
                return
            }
            self.removeCall(uuid: uuid)
        }
    }
    
    func reportCall(callerID: String) {
        let update = CXCallUpdate()
        let callerUUID = UUID()
        
        update.remoteHandle = CXHandle(type: .generic, value: callerID)
        update.localizedCallerName = callerID
        update.hasVideo = false
        
        cxProvider?.reportNewIncomingCall(with: callerUUID, update: update) { error in
            guard error == nil else {
                //Handle error
                return
            }
            self.addCall(uuid: callerUUID)
        }
    }
    
    func configureAudioSession(with session: AVAudioSession) {
        // See https://github.com/opentok/CallKit/blob/e36ee4d41050fa39ba082240d87361762387cf99/CallKitDemo/ProviderDelegate.swift#L259
        // https://stackoverflow.com/questions/16439767/error-domain-nsosstatuserrordomain-code-560030580-the-operation-couldn-t-be-com
        // let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(AVAudioSession.Category.playAndRecord, mode: .default)
            try session.setActive(true)
            try session.setMode(AVAudioSession.Mode.voiceChat)
        } catch {
            print(error, session.isOtherAudioPlaying)
        }
    }
}
