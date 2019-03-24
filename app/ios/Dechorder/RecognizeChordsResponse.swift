import Foundation

class RecognizeChordsResponse {
    
    var chords: [RecognizedChord] = []

    init (chords: [RecognizedChord]) {
        self.chords = chords
    }
    
    static func empty() -> RecognizeChordsResponse {
        return RecognizeChordsResponse(chords: [])
    }
    
}