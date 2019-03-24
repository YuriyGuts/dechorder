import Foundation

protocol RecognizerServiceClient {
    
    func recognizeChords(forTrack: Track) throws -> RecognizeChordsResponse
    
}
