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
    // Static so a second configure() (on any instance) can't add duplicate observers and re-register BG tasks, which crashes.
    private static var isConfigured = false

    public init() {
        appStartTime = Int64(Date().timeIntervalSince1970 * 1000)
    }

    public func configure() {
        guard !Kenkai.isConfigured else { return }
        Kenkai.isConfigured = true
        setupNotifications()
        // Configured after launch (e.g. after login): the foreground notifications already fired, so in-app
        // messages would stay off until the app is backgrounded and reopened. `.inactive` counts as open:
        // iOS 26 can leave an app inactive after the keyboard is dismissed.
        if UIApplication.shared.applicationState != .background {
            CoreConstants.shared.isAppOpen = true
        }
    }

    /// Registers the SDK's background tasks. `configure()` does this for you when called during launch.
    /// If you call `configure()` later (for example after login), call this from
    /// `application(_:didFinishLaunchingWithOptions:)`: iOS only accepts registration during launch.
    /// Safe to call more than once.
    public static func registerBackgroundTasks() {
        if #available(iOS 13.0, *) {
            WorkerCaller.registerBackgroundTask()
        }
    }

    deinit {
        // Unregister for notifications when the instance is deallocated
        removeNotifiations()
    }

    @objc func appDidFinishLaunching() {
        // Register Background Task
        if #available(iOS 13.0, *) {
            WorkerCaller.registerBackgroundTask()
        }
        
        trackAppOpen()
    }

    private var appOpenTracked = false

    private func trackAppOpen() {
        // Before build() there is no SDK key and the event would be dropped; a late build() logs it instead.
        guard !CoreConstants.shared.sdkKey.isEmpty else { return }
        appOpenTracked = true
        var startTime: Int64 = 0
        if(appStartTime != 0){
            let currentTimeMillis = Date().timeIntervalSince1970 * 1000
            startTime = Int64(currentTimeMillis) - appStartTime
        }
        let appObject = AppObject(action: AppAction.Open, startTime: Int(startTime))
        CFCoreSetupInterfaceImpl.shared.trackSDKEvent(eventName: .App, logObject: appObject)
    }

    /// Called by `CFLogBuilder.build()`. When the SDK is initialized after launch (for example after login),
    /// the launch and foreground notifications have already fired, so their work happens here instead:
    /// the app-open event is logged and stored events are synced right away, without waiting for a
    /// background task or the next foreground. During launch this runs after the launch notification and
    /// only repeats the (idempotent) sync.
    func appInitialized() {
        guard Kenkai.isConfigured, UIApplication.shared.applicationState != .background else { return }
        if !appOpenTracked {
            trackAppOpen()
        }
        syncOnForeground()
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
        // iOS does not always follow this with didBecomeActive (seen on iOS 26 after the keyboard was
        // dismissed), so the app-open sync runs here as well; overlapping uploads are skipped.
        syncOnForeground()
    }

    @objc func appDidBecomeActive() {
        CoreConstants.shared.isAppOpen = true
        syncOnForeground()
    }

    /// Uploads stored events now and keeps the periodic fallback upload running while Background App
    /// Refresh is unavailable (background tasks will not run then).
    private func syncOnForeground() {
        guard #available(iOS 13.0, *) else { return }
        CFSDKPerformUpload()
        if isBackgroundAppRefreshEnabled() {
            stopTimer()
        } else {
            startTimer()
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

       private let uploadLock = NSLock()
       private var uploadInFlight = false

       func CFSDKPerformUpload() {
           if #available(iOS 13.0, *) {
               // The foreground notifications and the fallback timer can all ask for an upload at the same
               // time; a second upload while one is in flight would resend the same stored events.
               uploadLock.lock()
               let alreadyRunning = uploadInFlight
               uploadInFlight = true
               uploadLock.unlock()
               if alreadyRunning { return }
               Task {
                   do {
                       try await WorkerCaller.performUpload()
                   } catch {
                       print("Error in CFSDKPerformUpload: \(error)")
                   }
                   uploadLock.lock()
                   uploadInFlight = false
                   uploadLock.unlock()
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
