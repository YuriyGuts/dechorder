import UIKit

class RootTabController: UITabBarController {
    
    var trackRepository: TrackRepository? = nil {
        didSet {
            newRecordingTabController.trackRepository = trackRepository
            myRecordingsTabController.trackRepository = trackRepository
        }
    }
    
    var userDocumentManager: UserDocumentManager? = nil {
        didSet {
            newRecordingTabController.userDocumentManager = userDocumentManager
            myRecordingsTabController.userDocumentManager = userDocumentManager
        }
    }
    
    var recognizerServiceClient: RecognizerServiceClient? = nil {
        didSet {
            newRecordingTabController.recognizerServiceClient = recognizerServiceClient
        }
    }
    
    var newRecordingTabController: NewRecordingTabController {
        return viewControllers![0] as! NewRecordingTabController
    }
    
    var myRecordingsTabController: MyRecordingsTabController {
        let navigationController = viewControllers![1] as! UINavigationController
        return navigationController.viewControllers[0] as! MyRecordingsTabController
    }
    
}