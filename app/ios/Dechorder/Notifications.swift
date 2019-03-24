import Foundation

class Notifications {
    
    private static let prefix: String = Bundle.main.bundleIdentifier! + ".notifications."
    
    static let TrackCreatedNotification = NSNotification.Name(rawValue: Notifications.prefix + "TrackCreatedNotification")
    
    static let TrackUpdatedNotification = NSNotification.Name(rawValue: Notifications.prefix + "TrackUpdatedNotification")
    
    static let TrackDeletedNotification = NSNotification.Name(rawValue: Notifications.prefix + "TrackDeletedNotification")

}
