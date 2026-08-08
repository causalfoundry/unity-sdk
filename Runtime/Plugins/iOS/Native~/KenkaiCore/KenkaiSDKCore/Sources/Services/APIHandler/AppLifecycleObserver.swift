//
//  AppLifecycleObserver.swift
//
//
//  Created by moizhassankh on 28/09/23.
//

import BackgroundTasks
import Foundation
import UIKit

public class Kenkai {
    var startTime: Int64?
    var previousStartTime: Int64?
    var pageCreateTime: Int64? = 0
    var pageRenderTime: Int64? = 0
    var oldPageRenderTime: Int64 = 0
    var appStartTime: Int64 = 0

    public static let shared = Kenkai()
    private var timer: DispatchSourceTimer?
    
    public init() {
        appStartTime = Int64(Date().timeIntervalSince1970 * 1000)
    }

    public func configure() {
        setupNotifications()
    }

    deinit {
        // Unregister for notifications when the instance is deallocated
        removeNotifiations()
    }

    @objc func appDidFinishLaunching() {
        // Register Background Task
        if #available(iOS 13.0, *) {
            if isBackgroundAppRefreshEnabled() {
                WorkerCaller.registerBackgroundTask()
            } else {
                showBackgroudTaskEnableNotification()
            }
        }
        
        var startTime: Int64 = 0
        if(appStartTime != 0){
            let currentTimeMillis = Date().timeIntervalSince1970 * 1000
            startTime = Int64(currentTimeMillis) - appStartTime
        }
        let appObject = AppObject(action: AppAction.Open, startTime: Int(startTime))
        CFCoreSetupInterfaceImpl.shared.trackSDKEvent(eventName: .App, logObject: appObject)
    }

    @objc func appWillEnterForeground() {
        CoreConstants.shared.isAppOpen = true

        if CoreConstants.shared.isAppPaused {
            let currentTimeMillis = Date().timeIntervalSince1970 * 1000
            CoreConstants.shared.sessionStartTime = Int64(currentTimeMillis)
            
            let appObject = AppObject(action: AppAction.Resume, startTime: 0)
            CFCoreSetupInterfaceImpl.shared.trackSDKEvent(eventName: .App, logObject: appObject)
        
        }
        CoreConstants.shared.isAppPaused = false
        
    }

    @objc func appDidBecomeActive() {
        CoreConstants.shared.isAppOpen = true
        
        if #available(iOS 13.0, *){
            CFSDKPerformUpload()
        }
        
        if #available(iOS 13.0, *), !isBackgroundAppRefreshEnabled() {
            // Start the timer when the app enters the foreground to periodically send events when bg permission not provided
            startTimer()
        }
        
        if #available(iOS 13.0, *), isBackgroundAppRefreshEnabled() {
            // stop the timer when the app enters the foreground and bg permission is provided
            stopTimer()
        }
        
    }

    @objc func appWillResignActive() {
        
        CoreConstants.shared.isAppOpen = false
        CoreConstants.shared.isAppPaused = true
        
        if #available(iOS 13.0, *), !isBackgroundAppRefreshEnabled() {
            // Stop the timer when the app enters the background for when the background permission is not provided.
            CFSDKPerformUpload()
            stopTimer()
        }
        
    }
    
    @objc func appDidEnterBackground() {
        
        let currentTimeMillis = Date().timeIntervalSince1970 * 1000
        CoreConstants.shared.sessionEndTime = Int64(currentTimeMillis)
        CoreConstants.shared.isAppOpen = false
        
        let appObject = AppObject(action: AppAction.Background, startTime: 0)
        CFCoreSetupInterfaceImpl.shared.trackSDKEvent(eventName: .App, logObject: appObject)
        

        if #available(iOS 13.0, *), isBackgroundAppRefreshEnabled() {
           WorkerCaller.scheduleBackgroundTasks()
        }
    }

    @objc func appWillTerminate() {
        
        let currentTimeMillis = Date().timeIntervalSince1970 * 1000
        CoreConstants.shared.sessionEndTime = Int64(currentTimeMillis)

        let appObject = AppObject(action: AppAction.Close, startTime: 0)
        CFCoreSetupInterfaceImpl.shared.trackSDKEvent(eventName: .App, logObject: appObject)
        
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(appDidFinishLaunching), name: UIApplication.didFinishLaunchingNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appWillResignActive), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appWillTerminate), name: UIApplication.willTerminateNotification, object: nil)
        // NotificationCenter.default.addObserver(self, selector: #selector(appWillTerminate), name: UIViewController.showDetailTargetDidChangeNotification, object: nil)
    }

    private func removeNotifiations() {
        NotificationCenter.default.removeObserver(self)
    }
    
    func isBackgroundAppRefreshEnabled() -> Bool {
        let backgroundRefreshStatus = UIApplication.shared.backgroundRefreshStatus

        switch backgroundRefreshStatus {
        case .available:
            return true
        case .denied:
            return false
        case .restricted:
            return false
        @unknown default:
            return false
        }
    }
    
    func startTimer() {
           // Invalidate previous timer to avoid multiple timers running simultaneously
           stopTimer()
           // Create a new timer to call your asynchronous function periodically
           timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
           // Set the time interval (in seconds)
           timer?.schedule(deadline: .now(), repeating: .seconds(12))
           // Set the event handler
           timer?.setEventHandler { [weak self] in
               self?.CFSDKPerformUpload()
           }
           timer?.resume()
       }

       func CFSDKPerformUpload() {
           // Your asynchronous function implementation here
           if #available(iOS 13.0, *) {
               Task {
                   do {
                       try await WorkerCaller.performUpload()
                   } catch {
                       print("Error in CFSDKPerformUpload: \(error)")
                   }
               }
           } else {
               // Fallback on earlier versions
           }
       }
    func stopTimer() {
            // Stop the timer if it's running
            timer?.cancel()
            timer = nil
    }
    
}

extension Kenkai {
    func showBackgroudTaskEnableNotification() {
        if #available(iOS 13.0, *) {
            guard let window = UIApplication.shared.windows.first,
                  let rootViewController = window.rootViewController else {
                    return
                }
            
            let alert = UIAlertController(title: "Enable Background App Refresh", message: "To take full advantage of our app's features, please enable Background App Refresh in your device settings.", preferredStyle: .alert)
            let settingsAction = UIAlertAction(title: "Open Settings", style: .default) { _ in
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            }
            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
            alert.addAction(settingsAction)
            alert.addAction(cancelAction)
            rootViewController.present(alert, animated: true, completion: nil)
        }
    }
}

// Call this in your AppDelegate or somewhere early in your app lifecycle

