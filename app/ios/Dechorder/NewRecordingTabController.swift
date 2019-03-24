import AudioKit
import AudioKitUI
import AVFoundation
import CoreData
import UIKit

class NewRecordingTabController: UIViewController, AVAudioRecorderDelegate, EZMicrophoneDelegate, EZRecorderDelegate {
    
    private var audioSession: AVAudioSession? = nil
    private var audioRecorder: AVAudioRecorder? = nil
    private var microphone: EZMicrophone? = nil

    private var isAudioRecordingPermissionGranted: Bool = false
    private var isCurrentlyRecording: Bool = false
    private var isFinishingRecording: Bool = false
    
    var trackRepository: TrackRepository? = nil
    var userDocumentManager: UserDocumentManager? = nil
    var recognizerServiceClient: RecognizerServiceClient? = nil

    private let recordingInProgressColor = UIColor(red: 1.00, green: 0.18, blue: 0.33, alpha: 1.00)
    private let recordingProcessingColor = UIColor(red: 0.39, green: 0.80, blue: 0.39, alpha: 1.00)

    @IBOutlet weak var recordingStatusLabel: UILabel?
    @IBOutlet weak var recordButton: UIButton?
    @IBOutlet weak var audioPlot: EZAudioPlot?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setUpAudioPlot()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func didTouchUpInsideRecordButton(_ sender: UIButton) {
        if isFinishingRecording {
            return
        }
        
        // Bounce the button a bit.
        if let recordButton = recordButton {
            recordButton.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
            
            UIView.animate(
                withDuration: 1.0,
                delay: 0,
                usingSpringWithDamping: 0.30,
                initialSpringVelocity: 15.00,
                options: UIView.AnimationOptions.allowUserInteraction,
                animations: {
                    recordButton.transform = .identity
                },
                completion: nil
            )
        }
        
        if !isCurrentlyRecording {
            switchUIToRecordingMode()
            do {
                try startAudioRecorder()
            }
            catch {
                switchUIToDefaultIdleMode()
            }
            return
        }
        
        if isCurrentlyRecording {
            switchUIToSavingMode()
            stopAudioRecorder()
            saveRecordingInBackground()
            return
        }
    }
    
    private func setUpAudioPlot() {
        guard let audioPlot = audioPlot else {
            return
        }
        audioPlot.plotType = .rolling
        audioPlot.color = recordingInProgressColor
    }

    private func switchUIToDefaultIdleMode() {
        self.isCurrentlyRecording = false
        self.isFinishingRecording = false
        self.updateUIForRecordingState()
    }

    private func switchUIToRecordingMode() {
        isCurrentlyRecording = true
        isFinishingRecording = false
        updateUIForRecordingState()
    }
    
    private func switchUIToSavingMode() {
        isFinishingRecording = true
        updateUIForRecordingState()
    }
    
    private func transitionToMyRecordingsScreen() {
        guard let tabBarController = tabBarController else {
            return
        }
        
        // TODO: Refactor the hardcoded tab indexes & decouple this stuff?
        let tabIndexToSwitchTo = 1
        let fromView = tabBarController.selectedViewController?.view
        let toView = tabBarController.viewControllers?[tabIndexToSwitchTo].view
        
        UIView.transition(
            from: fromView!,
            to: toView!,
            duration: 0.5,
            options: .transitionFlipFromRight,
            completion: { (finished: Bool) -> Void in
                if (finished) {
                    tabBarController.selectedIndex = tabIndexToSwitchTo
                }
            }
        )
    }
    
    private func updateUIForRecordingState() {
        guard let recordingStatusLabel = recordingStatusLabel,
            let recordButton = recordButton,
            let audioPlot = audioPlot else {
                return
        }
        
        if isFinishingRecording {
            recordingStatusLabel.text = NSLocalizedString("Processing...", comment: "Label indicating that the recorded file is being processed")
            recordButton.tintColor = recordingProcessingColor
            audioPlot.isHidden = true
            return
        }
        
        if isCurrentlyRecording {
            recordingStatusLabel.text = NSLocalizedString("Recording...", comment: "Label indicating that the recording is in progress")
            recordButton.tintColor = recordingInProgressColor
            audioPlot.setRollingHistoryLength(100)
            audioPlot.isHidden = false
            return
        }
        
        recordingStatusLabel.text = NSLocalizedString("Tap to Begin Recording", comment: "Label indicating that the user should tap to begin recording")
        recordButton.tintColor = view.tintColor
        audioPlot.clear()
        audioPlot.isHidden = true
    }
    
    private func showErrorAlert(title: String, message: String) {
        let alertController = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert
        )
        let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
        alertController.addAction(okAction)
        self.present(alertController, animated: true, completion: nil)
    }
    
    // MARK: - Audio Recording Operations
    
    private func setUpAudioSession() throws {
        audioSession = AVAudioSession.sharedInstance()
        guard let audioSession = audioSession else {
            throw DechorderErrors.AudioSessionNotAcquired
        }
        
        try audioSession.setCategory(.playAndRecord, mode: .default)
        try audioSession.setActive(true)
        
        audioSession.requestRecordPermission({ (isGranted: Bool) -> Void in
            self.isAudioRecordingPermissionGranted = isGranted
        })
        if !isAudioRecordingPermissionGranted {
            throw DechorderErrors.MicrophoneAccessNotGranted
        }
    }
    
    private func startAudioRecorder() throws {
        do {
            try setUpAudioSession()
            microphone = EZMicrophone(delegate: self)
        }
        catch (let error as NSError) {
            NSLog("Cannot set up audio session: \(error.userInfo)")
            return
        }
        
        guard let microphone = microphone else {
            NSLog("Cannot record: microphone not initialized")
            return
        }
        guard let userDocumentManager = userDocumentManager else {
            NSLog("Cannot acquire userDocumentManager")
            return
        }
        guard let fileURLForNewRecording = userDocumentManager.documentURLForNewTrack() else {
            NSLog("Cannot retrieve URL for new recording")
            return
        }
        
        microphone.startFetchingAudio()
        
        // WAV, 11 kHz, 16 bit, mono.
        let recordingSettings = [
            AVFormatIDKey: NSNumber(value: kAudioFormatLinearPCM),
            AVLinearPCMIsFloatKey: false,
            AVSampleRateKey: 11025.0,
            AVLinearPCMBitDepthKey: 16,
            AVNumberOfChannelsKey: 1,
        ]
        
        do {
            try audioRecorder = AVAudioRecorder(
                url: fileURLForNewRecording,
                settings: recordingSettings
            )
            
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.prepareToRecord()
            audioRecorder?.record()
        }
        catch let error as NSError {
            self.audioRecorder = nil
            NSLog("Cannot start audio recorder: \(error.userInfo)")
            throw error
        }
    }
    
    private func stopAudioRecorder() {
        guard let microphone = microphone,
            let audioRecorder = audioRecorder else {
            return
        }
        microphone.stopFetchingAudio()
        audioRecorder.stop()
    }
    
    // MARK: - Saving and Processing Audio.
    
    private func saveRecordingInBackground() {
        DispatchQueue.global(qos: .userInitiated).async {
            self.saveRecording()
            
            DispatchQueue.main.async {
                self.switchUIToDefaultIdleMode()
                self.transitionToMyRecordingsScreen()
            }
        }
    }
    
    private func saveRecording() {
        guard let trackRepository = trackRepository else {
            NSLog("Cannot acquire track repository")
            return
        }
        
        guard let recognizerServiceClient = recognizerServiceClient else {
            NSLog("Recognizer service client is not initialized")
            return
        }
        
        guard let newTrack = trackRepository.addNewTrack() else {
            NSLog("Cannot add new track")
            return
        }
        
        // Create a blank track.
        newTrack.title = ""
        newTrack.artist = ""
        newTrack.comments = ""
        newTrack.filename = audioRecorder?.url.lastPathComponent
        newTrack.creationDate = NSDate()
        trackRepository.save()

        // Recognize chords and append them to the track.
        var serviceResponse: RecognizeChordsResponse? = nil
        var recognizedChords: [RecognizedChord] = []

        do {
            try serviceResponse = recognizerServiceClient.recognizeChords(forTrack: newTrack)
            recognizedChords = serviceResponse!.chords
        }
        catch (let error as NSError) {
            showErrorAlert(
                title: "Sorry",
                message: "I can't recognize the chords because of an error:\n\n\(error.localizedDescription)"
            )
        }
        
        for recognizedChord in recognizedChords {
            let chord = trackRepository.addNewChord(toTrack: newTrack)
            chord?.name = recognizedChord.name
            chord?.timeOffset = NSNumber(value: recognizedChord.timeOffset)
            chord?.confidence = NSNumber(value: recognizedChord.confidence)
        }
        
        trackRepository.save()
        postTrackCreatedNotification(track: newTrack)
    }
    
    private func postTrackCreatedNotification(track: Track) {
        // Post a notification so that the view controllers can update their views.
        NotificationCenter.default.post(
            name: Notifications.TrackCreatedNotification,
            object: nil,
            userInfo: ["track": track]
        )
    }
    
    // MARK: - Audio Recorder Delegate
    
    @objc func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error = error {
            NSLog(error.localizedDescription)
        }
    }
    
    // MARK: - EZMicrophone Delegate
    
    func microphone(_ microphone: EZMicrophone!,
        hasAudioReceived buffer: UnsafeMutablePointer<UnsafeMutablePointer<Float>?>!,
        withBufferSize bufferSize: UInt32,
        withNumberOfChannels numberOfChannels: UInt32) {
        DispatchQueue.main.async {
            guard let audioPlot = self.audioPlot else {
                return
            }
            audioPlot.updateBuffer(buffer[0], withBufferSize: bufferSize)
        }
    }
}
