import AudioKit
import Foundation

class FakeRecognizerServiceClient: RecognizerServiceClient {
    
    private var _userDocumentManager: UserDocumentManager
    
    init(withUserDocumentManager userDocumentManager: UserDocumentManager) {
        _userDocumentManager = userDocumentManager
    }
    
    func recognizeChords(forTrack track: Track) throws -> RecognizeChordsResponse {
        let audioFileURL = _userDocumentManager.documentURL(forFileName: track.filename!)
        let audioFile = try AKAudioFile(forReading: audioFileURL!)
        
        let duration = Int(audioFile.duration)
        var recognizedChords = [randomChordWithinTimeFrame(begin: 0, end: 0)]
        
        let avgChordDuration = 4
        if duration > avgChordDuration {
            for begin in stride(from: avgChordDuration, to: duration, by: avgChordDuration) {
                let randomChord = randomChordWithinTimeFrame(begin: begin, end: begin + avgChordDuration - 1)
                recognizedChords.append(randomChord)
            }
        }
        
        return RecognizeChordsResponse(chords: recognizedChords)
    }
    
    func randomChordWithinTimeFrame(begin: Int, end: Int) -> RecognizedChord {
        let chordNames = [
            "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B",
            "Cm", "C#m", "Dm", "D#m", "Em", "Fm", "F#m", "Gm", "G#m", "Am", "A#m", "Bm",
        ]
        
        let randomChordIndex = Int.randomInRange(min: 0, max: chordNames.count - 1)
        
        let chord = RecognizedChord(
            name: chordNames[randomChordIndex],
            timeOffset: Double(Int.randomInRange(min: begin, max: end)),
            confidence: 1.0
        )
        return chord
    }
}
