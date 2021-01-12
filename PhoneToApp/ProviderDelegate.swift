import CallKit
import NexmoClient
import AVFoundation

class ProviderDelegate: NSObject {
    private let callManager = CallManager()
    private let provider: CXProvider
    private var activeCall: NXMCall?
    private var activeCallId: UUID?
    private var answerCallBlock: (() -> Void)?
    
    override init() {
        provider = CXProvider(configuration: ProviderDelegate.providerConfiguration)
        super.init()
        provider.setDelegate(self, queue: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(callReceived(_:)), name: Notification.Name("Call"), object: nil)
    }
    
    static var providerConfiguration: CXProviderConfiguration = {
        let providerConfiguration = CXProviderConfiguration(localizedName: "Vonage Call")
        providerConfiguration.supportsVideo = false
        providerConfiguration.maximumCallsPerCallGroup = 1
        providerConfiguration.supportedHandleTypes = [.generic]
        
        return providerConfiguration
    }()
}

extension ProviderDelegate: NXMCallDelegate {
    func call(_ call: NXMCall, didReceive error: Error) {
        print(error)
        if let uuid = activeCallId {
            activeCall?.hangup()
            activeCall = nil
            callManager.endCall(with: uuid)
        }
    }
    
    func call(_ call: NXMCall, didUpdate callMember: NXMCallMember, with status: NXMCallMemberStatus) {
        switch status {
        case .canceled, .failed, .timeout, .rejected, .completed:
            if let uuid = activeCallId {
                activeCall?.hangup()
                activeCall = nil
                callManager.endCall(with: uuid)
            }
        default:
            break
        }
    }
    
    func call(_ call: NXMCall, didUpdate callMember: NXMCallMember, isMuted muted: Bool) {}
}

extension ProviderDelegate: CXProviderDelegate {
    func providerDidReset(_ provider: CXProvider) {
        callManager.reset()
    }
    
    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        self.answerCallBlock = { [weak self] in
            guard let self = self else { return }
            guard self.activeCall != nil else {
                return
            }
            self.configureAudioSession()
            self.activeCall?.answer(nil)
            self.activeCall?.setDelegate(self)
            self.activeCallId = action.callUUID
            action.fulfill()
        }
    }
    
    
    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        activeCall?.hangup()
        callManager.removeCall(uuid: action.callUUID)
        action.fulfill()
    }
    
    func reportCall(callerID: String) {
        let update = CXCallUpdate()
        let callerUUID = UUID()
        
        update.remoteHandle = CXHandle(type: .generic, value: callerID)
        update.localizedCallerName = callerID
        update.hasVideo = false
        
        provider.reportNewIncomingCall(with: callerUUID, update: update) { error in
            guard error == nil else {
                return
            }
            self.callManager.addCall(uuid: callerUUID)
        }
    }
    
    @objc func callReceived(_ notification: NSNotification) {
        if let dict = notification.userInfo as NSDictionary? {
            if let call = dict["call"] as? NXMCall {
                activeCall = call
                answerCallBlock?()
            }
        }
    }
    
    func configureAudioSession() {
        // See https://forums.developer.apple.com/thread/64544
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(AVAudioSession.Category.playAndRecord, mode: .default)
            try audioSession.setMode(AVAudioSession.Mode.voiceChat)
        } catch {
            print(error)
        }
    }
}
