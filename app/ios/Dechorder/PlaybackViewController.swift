import AudioKit
import AudioKitUI
import UIKit

class PlaybackViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, EZAudioPlayerDelegate {
    
    private let _chordCellIdentifier = "ChordChartCollectionViewCell"
    private let _seekJumpDurationSeconds: TimeInterval = 10
    private let _inactiveChordAlpha: CGFloat = 0.2
    private let _playedAudioContainerBorderColor: CGColor = UIColor.darkText.cgColor
    private let _frameUpdateThreshold = 3000
    private var _lastPlayedAudioFrameIndex: Int64 = 0

    private var _trackUpdatedObserver: NSObjectProtocol?
    private var _audioPlayer: EZAudioPlayer?
    private var _audioFile: EZAudioFile?
    
    var track: Track? {
        didSet {
            loadTrackIntoUI()
            if let track = track, let trackRepository = trackRepository {
                displayedChords = trackRepository.allChordsOrderedByTimeOffset(inTrack: track)
            }
            else {
                displayedChords = []
            }
        }
    }
    
    var displayedChords: [Chord] = []
    var trackRepository: TrackRepository?
    var userDocumentManager: UserDocumentManager?

    @IBOutlet weak var chordCollectionView: UICollectionView?
    @IBOutlet weak var playedAudioContainerView: UIView?
    @IBOutlet weak var audioPlot: EZAudioPlot?
    @IBOutlet weak var playedAudioPlot: EZAudioPlot?
    @IBOutlet weak var currentPlaybackTimeIndicator: UILabel?
    @IBOutlet weak var playButton: UIButton?
    @IBOutlet weak var rewindButton: UIButton?
    @IBOutlet weak var forwardButton: UIButton?
    @IBOutlet weak var volumeSlider: UISlider?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setUpNotificationObservers()
        setUpCollectionView()
        setUpWaveformDisplay()
        setUpAudioPlayer()
        loadTrackIntoUI()
    }
    
    override func viewDidLayoutSubviews() {
        playedAudioPlot?.isHidden = false
        markCurrentPlaybackPositionOnWaveform()
        adjustCollectionViewLayout()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        stopPlayerIfPlaying()
        super.viewWillDisappear(animated)
    }
    
    func setUpNotificationObservers() {
        let notificationCenter = NotificationCenter.default
        let mainQueue = OperationQueue.main
        
        _trackUpdatedObserver = notificationCenter.addObserver(
            forName: Notifications.TrackUpdatedNotification,
            object: nil,
            queue: mainQueue,
            using: handleTrackUpdatedNotification
        )
    }
    
    func handleTrackUpdatedNotification(notification: Notification) {
        guard let userInfo = notification.userInfo,
            let updatedTrack = userInfo["track"] as? Track else {
            return
        }
        if updatedTrack.objectID == self.track?.objectID {
            track = updatedTrack
        }
    }
    
    private func setUpCollectionView() {
        guard let chordCollectionView = chordCollectionView else {
            return
        }
        
        // Register custom cells.
        let nib = UINib(nibName: _chordCellIdentifier, bundle: nil)
        chordCollectionView.register(nib, forCellWithReuseIdentifier: _chordCellIdentifier)
    }
    
    private func adjustCollectionViewLayout() {
        guard let chordCollectionView = chordCollectionView else {
            return
        }
        
        // Move the first chord to the center, but not further.
        let layout = chordCollectionView.collectionViewLayout as! UICollectionViewFlowLayout
        let insetWidth = chordCollectionView.frame.size.width / 2 - layout.itemSize.width / 2
        layout.sectionInset = UIEdgeInsets(top: 0, left: insetWidth, bottom: 0, right: insetWidth)
    }
    
    private func setUpWaveformDisplay() {
        guard let currentPlaybackTimeIndicator = currentPlaybackTimeIndicator else {
            return
        }
        guard let playedAudioContainerView = playedAudioContainerView else {
            return
        }
        playedAudioContainerView.layer.borderColor = _playedAudioContainerBorderColor
        currentPlaybackTimeIndicator.font = UIFont.monospacedDigitSystemFont(ofSize: currentPlaybackTimeIndicator.font.pointSize, weight: UIFont.Weight.regular)
    }
    
    private func setUpAudioPlayer() {
        _audioPlayer = EZAudioPlayer(delegate: self)
        do {
            try AVAudioSession.sharedInstance().overrideOutputAudioPort(.speaker)
        }
        catch (let error as NSError) {
            NSLog("Failed to switch audio output port: \(error.userInfo)")
        }
    }
    
    private func loadTrackIntoUI() {
        guard let track = track,
            let fileName = track.filename,
            let _audioPlayer = _audioPlayer,
            let volumeSlider = volumeSlider else {
            return
        }
        
        navigationItem.title = track.title
        let trackFileURL = userDocumentManager?.documentURL(forFileName: fileName)
        
        _audioFile = EZAudioFile(url: trackFileURL!)
        _audioPlayer.audioFile = _audioFile
        volumeSlider.value = _audioPlayer.volume
        
        loadWaveformFromFile()
    }
    
    private func loadWaveformFromFile() {
        guard let _audioFile = _audioFile,
            let audioPlot = audioPlot,
            let playedAudioPlot = playedAudioPlot else {
            return
        }
        
        audioPlot.plotType = .buffer
        let waveformData = _audioFile.getWaveformData()!
        audioPlot.updateBuffer(waveformData.buffers[0], withBufferSize: waveformData.bufferSize)
        
        playedAudioPlot.plotType = .buffer
        playedAudioPlot.updateBuffer(waveformData.buffers[0], withBufferSize: waveformData.bufferSize)
    }
    
    // MARK: - Collection View Data Source
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        guard let track = track,
            let chords = track.chords else {
            return 0
        }
        return chords.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = chordCollectionView?.dequeueReusableCell(withReuseIdentifier: _chordCellIdentifier, for: indexPath) as! ChordChartCollectionViewCell
        
        cell.chordChartView?.loadChord(displayedChords[indexPath.row])
        cell.chordChartView?.alpha = _inactiveChordAlpha
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if let seekPosition = displayedChords[indexPath.row].timeOffset {
            seekToPosition(seconds: Double(truncating: seekPosition) + 0.1)
        }
    }
    
    // MARK: - Playback Controls
    
    @IBAction func didTouchUpInsidePlayButton(_ sender: UIButton) {
        guard let _audioPlayer = _audioPlayer else {
            return
        }
        if _audioPlayer.isPlaying {
            switchUIToNotPlayingMode()
            _audioPlayer.pause()
        }
        else {
            switchUIToPlayingMode()
            _audioPlayer.play()
        }
    }
    
    @IBAction func didTouchUpInsideRewindButton(_ sender: UIButton) {
        guard let _audioPlayer = _audioPlayer else {
            return
        }
        seekToPosition(seconds: _audioPlayer.currentTime - _seekJumpDurationSeconds)
    }
    
    @IBAction func didTouchUpInsideForwardButton(_ sender: UIButton) {
        guard let _audioPlayer = _audioPlayer else {
            return
        }
        seekToPosition(seconds: _audioPlayer.currentTime + _seekJumpDurationSeconds)
    }
    
    @IBAction func didChangeVolumeSliderValue(_ sender: UISlider) {
        guard let _audioPlayer = _audioPlayer else {
            return
        }
        _audioPlayer.volume = sender.value
    }
    
    private func seekToPosition(seconds: TimeInterval) {
        guard let _audioPlayer = _audioPlayer, let _audioFile = _audioFile else {
            return
        }
        var targetTime = seconds
        if targetTime < 0 {
            targetTime = 0
        }
        if targetTime > _audioFile.duration {
            targetTime = _audioFile.duration - 0.1
        }
        
        let newChordIndex = self.indexOfChord(atPlaybackPosition: targetTime)
        let previousChordIndex = self.indexOfChord(atPlaybackPosition: _audioPlayer.currentTime)
        self.setActiveChordAnimated(newChordIndex: newChordIndex, previousChordIndex: previousChordIndex)
        
        _audioPlayer.currentTime = targetTime
    }
    
    private func switchUIToPlayingMode() {
        playButton?.setImage(UIImage(named: "playback_pause"), for: UIControl.State.normal)
    }
    
    private func switchUIToNotPlayingMode() {
        playButton?.setImage(UIImage(named: "playback_play"), for: UIControl.State.normal)
    }
    
    private func stopPlayerIfPlaying() {
        if let _audioPlayer = _audioPlayer {
            if _audioPlayer.isPlaying {
                switchUIToNotPlayingMode()
                _audioPlayer.pause()
            }
        }
    }
    
    private func updateUIAccordingToCurrentPlaybackPosition() {
        guard let currentPlaybackTimeIndicator = self.currentPlaybackTimeIndicator,
            let _audioPlayer = _audioPlayer else {
            return
        }
        
        markCurrentPlaybackPositionOnWaveform()
        currentPlaybackTimeIndicator.text = _audioPlayer.currentTime.formattedForPlayer()
        
        let newChordIndex = indexOfChord(atPlaybackPosition: _audioPlayer.currentTime)
        let previousChordIndex = newChordIndex > 0 ? newChordIndex - 1 : displayedChords.count - 1
        setActiveChordAnimated(newChordIndex: newChordIndex, previousChordIndex: previousChordIndex)
    }

    private func markCurrentPlaybackPositionOnWaveform() {
        guard let _audioPlayer = _audioPlayer,
            let audioPlot = audioPlot,
            let playedAudioPlot = playedAudioPlot else {
            return
        }
        
        let playbackPositionRatio = CGFloat(_audioPlayer.currentTime / _audioPlayer.duration)

        // Place two rectangular masks over the two plots to make them look like one painted in two colors.
        let playedWaveformMaskLayer = CAShapeLayer()
        let remainingWaveformMaskLayer = CAShapeLayer()
        
        let splittingPointX = playbackPositionRatio * audioPlot.bounds.width
        let remainingMaskRect = CGRect(x: 0, y: 0, width: splittingPointX, height: audioPlot.bounds.height)
        let playedMaskRect = CGRect(x: splittingPointX, y: 0, width: audioPlot.bounds.width - splittingPointX, height: audioPlot.bounds.height)
        
        let playedPath = CGPath(rect: playedMaskRect, transform: nil)
        let remainingPath = CGPath(rect: remainingMaskRect, transform: nil)
        
        playedWaveformMaskLayer.path = playedPath
        remainingWaveformMaskLayer.path = remainingPath
        
        audioPlot.layer.mask = playedWaveformMaskLayer
        playedAudioPlot.layer.mask = remainingWaveformMaskLayer
    }
    
    private func setActiveChordAnimated(newChordIndex: Int, previousChordIndex: Int) {
        if newChordIndex == previousChordIndex || newChordIndex >= displayedChords.count {
            return
        }
        
        let newChordCell = cellForChord(atIndex: newChordIndex)
        let previousChordCell = cellForChord(atIndex: previousChordIndex)
        
        UIView.animate(withDuration: 0.5, animations: {
            if let previousChordCell = previousChordCell {
                previousChordCell.chordChartView?.alpha = self._inactiveChordAlpha
            }
            if let newChordCell = newChordCell {
                newChordCell.chordChartView?.alpha = 1.0
            }
            self.chordCollectionView?.scrollToItem(at: IndexPath(row: newChordIndex, section: 0), at: .centeredHorizontally, animated: true)
        })
    }
    
    @IBAction func didTapInsideAudioPlot(_ sender: UITapGestureRecognizer) {
        guard let audioPlot = audioPlot,
            let _audioPlayer = _audioPlayer,
            let audioFile = _audioPlayer.audioFile else {
            return
        }
        
        let locationOfTap = sender.location(in: audioPlot)
        let seekRatio = Double(locationOfTap.x) / Double(audioPlot.bounds.width)
        seekToPosition(seconds: audioFile.duration * seekRatio)
    }
    
    private func indexOfChord(atPlaybackPosition position: TimeInterval) -> Int {
        guard displayedChords.count > 0 else {
            return 0
        }
        if Double(truncating: displayedChords[0].timeOffset!) > position {
            return 0
        }
        
        for index in 0..<displayedChords.count - 1 {
            if Double(truncating: displayedChords[index].timeOffset!) <= position
                && Double(truncating: displayedChords[index + 1].timeOffset!) > position {
                    return index
            }
        }
        return displayedChords.count - 1
    }
    
    private func cellForChord(atIndex index: Int) -> ChordChartCollectionViewCell? {
        let indexPath = IndexPath(row: index, section: 0)
        if let cell = chordCollectionView?.cellForItem(at: indexPath) {
            return cell as? ChordChartCollectionViewCell
        }
        return nil
    }
    
    // MARK: - EZAudioPlayer Delegate
    
    func audioPlayer(_ audioPlayer: EZAudioPlayer!, reachedEndOf audioFile: EZAudioFile!) {
        DispatchQueue.main.async {
            let newChordIndex = 0
            let previousChordIndex = self.indexOfChord(atPlaybackPosition: audioFile.duration)
            self.setActiveChordAnimated(newChordIndex: newChordIndex, previousChordIndex: previousChordIndex)
            self.switchUIToNotPlayingMode()
        }
    }
    
    func audioPlayer(_ audioPlayer: EZAudioPlayer!, updatedPosition framePosition: Int64, in audioFile: EZAudioFile!) {
        // This method gets called very often, which leads to excessive UI updates.
        // We'll set a manual throttling threshold, allowing the UI to update only on every Nth frame.
        if abs(framePosition - _lastPlayedAudioFrameIndex) < _frameUpdateThreshold {
            return
        }
        _lastPlayedAudioFrameIndex = framePosition

        DispatchQueue.main.async {
            self.updateUIAccordingToCurrentPlaybackPosition()
        }
    }
    
    // MARK: - Segues
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showEditRecordingScreen" {
            prepareForShowEditRecordingSegue(segue: segue, sender: sender)
        }
    }
    
    private func prepareForShowEditRecordingSegue(segue: UIStoryboardSegue, sender: Any?) {
        stopPlayerIfPlaying()
        let editRecordingController = segue.destination as! EditRecordingViewController
        editRecordingController.trackRepository = trackRepository
        editRecordingController.userDocumentManager = userDocumentManager
        editRecordingController.track = track
    }
}
