import Foundation

class RecognizedChord {
    
    var name: String
    
    var timeOffset: Double
    
    var confidence: Double
    
    init(name: String, timeOffset: Double, confidence: Double) {
        self.name = name
        self.timeOffset = timeOffset
        self.confidence = confidence
    }
    
}