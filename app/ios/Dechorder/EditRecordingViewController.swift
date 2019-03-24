import UIKit

class EditRecordingViewController: UITableViewController {
    
    var trackRepository: TrackRepository?
    var userDocumentManager: UserDocumentManager?
    
    var track: Track? {
        didSet {
            loadTrackIntoUI()
        }
    }
    
    @IBOutlet weak var titleEditor: UITextField?
    @IBOutlet weak var artistEditor: UITextField?
    @IBOutlet weak var commentsEditor: UITextField?
    
    override func viewWillAppear(_ animated: Bool) {
        loadTrackIntoUI()
        super.viewWillDisappear(animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        saveTrack()
        super.viewWillDisappear(animated)
    }
    
    private func loadTrackIntoUI() {
        guard let titleEditor = titleEditor,
            let artistEditor = artistEditor,
            let commentsEditor = commentsEditor else {
            return
        }
        
        if let track = track {
            titleEditor.text = track.title
            artistEditor.text = track.artist
            commentsEditor.text = track.comments
        }
        else {
            titleEditor.text = ""
            artistEditor.text = ""
            commentsEditor.text = ""
        }
    }
    
    private func saveTrack() {
        guard let track = track,
            let titleEditor = titleEditor,
            let artistEditor = artistEditor,
            let commentsEditor = commentsEditor,
            let trackRepository = trackRepository else {
            return
        }
        
        track.title = titleEditor.text
        track.artist = artistEditor.text
        track.comments = commentsEditor.text
        
        trackRepository.save()
        postTrackUpdatedNotification()
    }
    
    private func postTrackUpdatedNotification() {
        guard let track = track else {
            return
        }
        
        // Post a notification so that the view controllers can update their views.
        NotificationCenter.default.post(
            name: Notifications.TrackUpdatedNotification,
            object: nil,
            userInfo: ["track": track]
        )
    }
}
