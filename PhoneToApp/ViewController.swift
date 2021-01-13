//
//  ViewController.swift
//  PhoneToApp
//
//  Created by Abdulhakim Ajetunmobi on 06/07/2020.
//  Copyright © 2020 Vonage. All rights reserved.
//

import UIKit
import NexmoClient

class ViewController: UIViewController {
    
    let connectionStatusLabel = UILabel()
    let client = NXMClient.shared
    var call: NXMCall?
    var callBeenHandled = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        connectionStatusLabel.text = "Connected"
        connectionStatusLabel.textAlignment = .center
        connectionStatusLabel.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(connectionStatusLabel)
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-20-[label]-20-|",
                                                           options: [], metrics: nil, views: ["label" : connectionStatusLabel]))
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-80-[label(20)]",
                                                           options: [], metrics: nil, views: ["label" : connectionStatusLabel]))
        
        NotificationCenter.default.addObserver(self, selector: #selector(statusReceived(_:)), name: .clientStatus, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(callReceived(_:)), name: .incomingCall, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(callHandled), name: .handledCallCallKit, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func statusReceived(_ notification: NSNotification) {
        DispatchQueue.main.async { [weak self] in
            self?.connectionStatusLabel.text = notification.object as? String
        }
    }
    
    @objc func callReceived(_ notification: NSNotification) {
        DispatchQueue.main.async { [weak self] in
            if let call = notification.object as? NXMCall, !(self?.callBeenHandled ?? false) {
                self?.displayIncomingCallAlert(call: call)
            }
        }
    }
    
    @objc func callHandled() {
        DispatchQueue.main.async { [weak self] in
            if self?.presentedViewController != nil {
                self?.callBeenHandled = true
                self?.dismiss(animated: true, completion: nil)
            }
        }
    }
    
    func displayIncomingCallAlert(call: NXMCall) {
        var from = "Unknown"
        if let otherParty = call.otherCallMembers.firstObject as? NXMCallMember {
            from = otherParty.channel?.from.data ?? "Unknown"
        }
        let
            alert = UIAlertController(title: "Incoming call from", message: from, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Answer", style: .default, handler: { _ in
            self.call = call
            NotificationCenter.default.post(name: .handledCallApp, object: nil)
            call.answer(nil)
            
        }))
        alert.addAction(UIAlertAction(title: "Reject", style: .default, handler: { _ in
            call.reject(nil)
        }))
        
        self.present(alert, animated: true, completion: nil)
    }
    
}

