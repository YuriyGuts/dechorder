import Foundation

protocol TrackRepository {

    func allTracksOrderedByCreationDateDescending() -> [Track]
    
    func allChordsOrderedByTimeOffset(inTrack: Track) -> [Chord]
    
    func addNewTrack() -> Track?
    
    func deleteTrack(_ track: Track)

    func addNewChord(toTrack: Track) -> Chord?
    
    func save()
    
}
