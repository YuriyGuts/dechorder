import CoreData
import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?


    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        guard let managedObjectContext = self.managedObjectContext else {
            NSLog("Cannot acquire managed object context")
            return false
        }

        let trackRepository = CoreDataTrackRepository(withManagedObjectContext: managedObjectContext)
        let userDocumentManager = FileSystemUserDocumentManager()
        // let recognizerServiceClient = InternetRecognizerServiceClient(withUserDocumentManager: userDocumentManager)
        let recognizerServiceClient = FakeRecognizerServiceClient(withUserDocumentManager: userDocumentManager)

        let rootTabController = self.window!.rootViewController as! RootTabController
        rootTabController.trackRepository = trackRepository
        rootTabController.userDocumentManager = userDocumentManager
        rootTabController.recognizerServiceClient = recognizerServiceClient
        
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }


    // MARK: - Core Data stack
    
    lazy var applicationDocumentsDirectory: URL = {
        // The directory the application uses to store the Core Data store file.
        let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return urls.last!
    }()
    
    lazy var managedObjectModel: NSManagedObjectModel = {
        // The managed object model for the application. This property is not optional.
        // It is a fatal error for the application not to be able to find and load its model.
        let modelURL = Bundle.main.url(forResource: "DechorderModel", withExtension: "momd")!
        return NSManagedObjectModel(contentsOf: modelURL)!
    }()
    
    lazy var persistentStoreCoordinator: NSPersistentStoreCoordinator? = {
        // The persistent store coordinator for the application.
        // This implementation creates and return a coordinator,
        // having added the store for the application to it.
        // This property is optional since there are legitimate
        // error conditions that could cause the creation of the store to fail.
        
        // Create the coordinator and store
        var coordinator: NSPersistentStoreCoordinator? = NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
        let url = self.applicationDocumentsDirectory.appendingPathComponent("Dechorder.sqlite")

        do {
            try coordinator!.addPersistentStore(
                ofType: NSSQLiteStoreType,
                configurationName: nil,
                at: url,
                options: nil
            )
        } catch var loadError as NSError {
            coordinator = nil
            self.reportCoreDataLoadError(loadError: loadError)
            abort()
        } catch {
            fatalError()
        }
        
        return coordinator
    }()
    
    lazy var managedObjectContext: NSManagedObjectContext? = {
        // Returns the managed object context for the application
        // (which is already bound to the persistent store coordinator for the application.)
        // This property is optional since there are legitimate error conditions that could
        // cause the creation of the context to fail.
        let coordinator = self.persistentStoreCoordinator
        if coordinator == nil {
            return nil
        }
        
        var managedObjectContext = NSManagedObjectContext.init(concurrencyType: .mainQueueConcurrencyType)
        managedObjectContext.persistentStoreCoordinator = coordinator
        
        return managedObjectContext
    }()
    
    func reportCoreDataLoadError(loadError: NSError) {
        var dict = [String: Any]()
        dict[NSLocalizedDescriptionKey] = "Failed to initialize the application's saved data"
        dict[NSLocalizedFailureReasonErrorKey] = "There was an error creating or loading the application's saved data."
        dict[NSUnderlyingErrorKey] = loadError
        
        let appDomain = Bundle.main.bundleIdentifier!
        let error = NSError(domain: appDomain, code: 9999, userInfo: dict)
        NSLog("Unresolved error \(error), \(error.userInfo)")
    }
}
