import CoreData

class Track: NSManagedObject {

    func addChord(_ chord: Chord) {
        let chords = self.mutableSetValue(forKey:"chords")
        chords.add(chord)
    }
    
    func chordsAsArray() -> [Chord] {
        guard let chords = self.chords else {
            return []
        }
        return chords.allObjects as! [Chord]
    }
    
}
