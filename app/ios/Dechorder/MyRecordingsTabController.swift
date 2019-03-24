import CoreData
import UIKit

class MyRecordingsTabController: UITableViewController {

    private let _trackCellIdentifier = "TrackTableViewCell"
    
    private var _dateFormatter: DateFormatter?
    private var _trackCreatedObserver: NSObjectProtocol?
    private var _trackUpdatedObserver: NSObjectProtocol?
    private var _cachedDisplayedTracks: [Track]?
    
    var trackRepository: TrackRepository? = nil {
        didSet {
            invalidateDisplayedTracks()
        }
    }
    
    var displayedTracks: [Track] {
        if _cachedDisplayedTracks == nil {
            _cachedDisplayedTracks = fetchTracks()
        }
        return _cachedDisplayedTracks!
    }
    
    var userDocumentManager: UserDocumentManager?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        setUpTableView()
        setUpDateFormatter()
        setUpNotificationObservers()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    private func setUpTableView() {
        // Register custom cells.
        let nib = UINib(nibName: _trackCellIdentifier, bundle: nil)
        tableView?.register(nib, forCellReuseIdentifier: _trackCellIdentifier)
    }
    
    private func setUpDateFormatter() {
        _dateFormatter = DateFormatter()
        _dateFormatter?.dateStyle = .none
        _dateFormatter?.timeStyle = .short
    }
    
    private func setUpNotificationObservers() {
        let notificationCenter = NotificationCenter.default
        let mainQueue = OperationQueue.main
        
        _trackCreatedObserver = notificationCenter.addObserver(
            forName: Notifications.TrackCreatedNotification,
            object: nil,
            queue: mainQueue,
            using: handleTrackCreatedNotification
        )
        
        _trackUpdatedObserver = notificationCenter.addObserver(
            forName: Notifications.TrackUpdatedNotification,
            object: nil,
            queue: mainQueue,
            using: handleTrackUpdatedNotification
        )
    }
    
    private func handleTrackCreatedNotification(notification: Notification) {
        invalidateDisplayedTracks(animated: true)
    }
    
    private func handleTrackUpdatedNotification(notification: Notification) {
        invalidateDisplayedTracks(animated: true)
    }
    
    private func invalidateDisplayedTracks(animated: Bool = false) {
        _cachedDisplayedTracks = nil
        if animated {
            tableView?.reloadSections(
                IndexSet(integer: 0),
                with: .automatic
            )
        } else {
            tableView?.reloadData()
        }
    }
    
    // MARK: - Table View
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return displayedTracks.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: _trackCellIdentifier, for: indexPath) as! TrackTableViewCell
        
        let track = displayedTracks[indexPath.row]

        cell.titleLabel?.text = String.alternativeIfNilOrEmpty(track.title, alternative: "(untitled)")
        cell.artistLabel?.text = String.alternativeIfNilOrEmpty(track.artist, alternative: "(unknown artist)")
        cell.commentsLabel?.text = String.alternativeIfNilOrEmpty(track.comments, alternative: formattedListOfChords(forTrack: track))
        cell.dateLabel?.text = _dateFormatter?.string(from: track.creationDate! as Date)
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        performSegue(withIdentifier: "showPlaybackScreen", sender: self)
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            deleteTrack(at: indexPath)
        }
    }
    
    // MARK: - Display Formatting
    
    private func formattedListOfChords(forTrack track: Track) -> String {
        guard let trackRepository = trackRepository else {
            return ""
        }
        let chords = trackRepository.allChordsOrderedByTimeOffset(inTrack: track)
        return chords.map { $0.name ?? "" }.joined(separator: " ")
    }
    
    // MARK: - Table Data Manipulation
    
    private func fetchTracks() -> [Track] {
        guard let trackRepository = trackRepository else {
            return []
        }
        return trackRepository.allTracksOrderedByCreationDateDescending()
    }
    
    private func displayedTrack(at indexPath: IndexPath) -> Track {
        return displayedTracks[indexPath.row]
    }
    
    private func deleteTrack(at indexPath: IndexPath) {
        guard let trackRepository = trackRepository,
            let userDocumentManager = userDocumentManager else {
            return
        }
        
        let trackToDelete = displayedTrack(at: indexPath)
        
        // Deleting the audio file for the track.
        guard let _ = try? userDocumentManager.deleteDocument(forTrack: trackToDelete) else {
            return
        }

        // Deleting the track from the DB.
        trackRepository.deleteTrack(trackToDelete)
        trackRepository.save()
        
        invalidateDisplayedTracks(animated: true)
    }
    
    // MARK: - Segues
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showPlaybackScreen" {
            prepareForShowPlaybackSegue(segue: segue, sender: sender)
        }
    }
    
    private func prepareForShowPlaybackSegue(segue: UIStoryboardSegue, sender: Any?) {
        guard let indexPath = self.tableView.indexPathForSelectedRow else {
            return
        }
        
        let track = displayedTracks[indexPath.row]
        let playbackController = segue.destination as! PlaybackViewController
        
        playbackController.trackRepository = trackRepository
        playbackController.userDocumentManager = userDocumentManager
        playbackController.track = track
    }
}

