import Foundation
import CoreData

extension Track {

    @NSManaged var title: String?
    
    @NSManaged var artist: String?
    
    @NSManaged var comments: String?
    
    @NSManaged var creationDate: NSDate?
    
    @NSManaged var filename: String?
    
    @NSManaged var chords: NSSet?

}
