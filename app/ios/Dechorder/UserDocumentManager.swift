import Foundation

protocol UserDocumentManager {
    
    func documentURLForNewTrack() -> URL?
    
    func documentURL(forFileName: String) -> URL?
    
    func deleteDocument(forTrack: Track) throws
    
}
