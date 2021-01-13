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
    private let callController = CXCallController()
    private var calls = [UUID]()
    
    func addCall(uuid: UUID) {
        self.calls.append(uuid)
    }

    func removeCall(uuid: UUID) {
        self.calls.removeAll { $0 == uuid }
    }

    func reset() {
        self.calls.removeAll()
    }
    
    func endCall(with action: CXCallAction) {
        let transaction = CXTransaction(action: action)
        callController.request(transaction) { error in
            guard error == nil else { return }
            self.removeCall(uuid: action.uuid)
        }
    }
}
