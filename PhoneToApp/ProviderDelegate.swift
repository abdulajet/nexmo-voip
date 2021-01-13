import CallKit
import NexmoClient
import AVFoundation

struct PushCall {
    var call: NXMCall?
    var uuid: UUID?
    var answerBlock: (() -> Void)?
}

class ProviderDelegate: NSObject {
    private let callManager = CallManager()
    private let provider: CXProvider
    private var activeCall: PushCall? = PushCall()
    
    override init() {
        provider = CXProvider(configuration: ProviderDelegate.providerConfiguration)
        super.init()
        provider.setDelegate(self, queue: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(callReceived(_:)), name: .incomingCall, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
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
        hangup()
    }
    
    func call(_ call: NXMCall, didUpdate callMember: NXMCallMember, with status: NXMCallMemberStatus) {
        switch status {
        case .canceled, .failed, .timeout, .rejected, .completed:
            hangup()
        default:
            break
        }
    }
    
    func call(_ call: NXMCall, didUpdate callMember: NXMCallMember, isMuted muted: Bool) {}
    
    func hangup() {
        if let uuid = activeCall?.uuid {
            let action = CXEndCallAction(call: uuid)
            activeCall?.call?.hangup()
            activeCall = nil
            callManager.endCall(with: action)
        }
    }
}

extension ProviderDelegate: CXProviderDelegate {
    func providerDidReset(_ provider: CXProvider) {
        callManager.reset()
    }
    
    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        activeCall?.answerBlock = { [weak self] in
            guard let self = self, self.activeCall != nil else { return }
            self.configureAudioSession()
            self.activeCall?.call?.answer(nil)
            self.activeCall?.call?.setDelegate(self)
            self.activeCall?.uuid = action.callUUID
            action.fulfill()
        }
    }
    
    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        hangup()
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
        if let call = notification.object as? NXMCall {
            activeCall?.call = call
            activeCall?.answerBlock?()
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
