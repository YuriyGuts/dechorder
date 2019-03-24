import Foundation

class FileSystemUserDocumentManager: UserDocumentManager {
    
    func documentURLForNewTrack() -> URL? {
        let timestamp = Int64(NSDate().timeIntervalSince1970 * 1000)
        let fileName = "recording-\(timestamp).wav"
        return documentURL(forFileName: fileName)
    }
    
    func documentURL(forFileName fileName: String) -> URL? {
        if let documentsFolderURL = _documentsFolderURL() {
            return documentsFolderURL.appendingPathComponent(fileName)
        }
        return nil
    }
    
    func deleteDocument(forTrack track: Track) throws {
        guard let fileName = track.filename,
            let documentURL = documentURL(forFileName: fileName) else {
                return
        }
        
        // If the file is already missing, tolerate it and return.
        if !FileManager.default.fileExists(atPath: documentURL.path) {
            NSLog("Cannot locate document for: '\(String(describing: track.filename))'")
            return
        }
        
        // Delete the file or die.
        do {
            try FileManager.default.removeItem(at: documentURL)
        }
        catch let error as NSError {
            NSLog("Cannot remove document '\(fileName)': \(error.userInfo)")
            throw error
        }
    }
    
    private func _documentsFolderURL() -> URL? {
        let documentsFolderURL = try? FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return documentsFolderURL
    }
    
}
