import CoreData
import Foundation

class CoreDataTrackRepository : TrackRepository {
    
    private var _managedObjectContext: NSManagedObjectContext
    
    init(withManagedObjectContext managedObjectContext: NSManagedObjectContext) {
        _managedObjectContext = managedObjectContext
    }
    
    func allTracksOrderedByCreationDateDescending() -> [Track] {
        guard let fetchRequest = _fetchRequestForTracks() else {
            NSLog("fetchTracks: fetchRequest is nil")
            return []
        }
        
        do {
            let fetchResults = try _managedObjectContext.fetch(fetchRequest)
            if let results = fetchResults as? [Track] {
                return results
            }
        }
        catch let error as NSError {
            NSLog("Error while fetching data: \(error), \(error.userInfo)")
        }
        
        return []
    }
    
    func allChordsOrderedByTimeOffset(inTrack track: Track) -> [Chord] {
        var rawChords = track.chords?.allObjects as! [Chord]
        rawChords.sort(by: { (chord1, chord2) -> Bool in chord1.timeOffset!.compare(chord2.timeOffset!) == .orderedAscending })
        return rawChords
    }
    
    func addNewTrack() -> Track? {
        return NSEntityDescription.insertNewObject(
            forEntityName: "Track",
            into: _managedObjectContext
        ) as? Track
    }
    
    func deleteTrack(_ track: Track) {
        _managedObjectContext.delete(track)
    }
    
    func addNewChord(toTrack track: Track) -> Chord? {
        let chord = NSEntityDescription.insertNewObject(
            forEntityName: "Chord",
            into: _managedObjectContext
        ) as? Chord
        
        if let chord = chord {
            track.addChord(chord)
        }
        return chord
    }
    
    func save() {
        if !_managedObjectContext.hasChanges {
            return
        }
        
        do {
            try _managedObjectContext.save()
        }
        catch let errorDuringSave as NSError {
            NSLog("Error while saving data: \(errorDuringSave), \(errorDuringSave.userInfo)")
        }
    }
    
    private func _fetchRequestForTracks() -> NSFetchRequest<NSFetchRequestResult>? {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>()
        fetchRequest.entity = NSEntityDescription.entity(forEntityName: "Track", in: _managedObjectContext)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        return fetchRequest
    }
}
