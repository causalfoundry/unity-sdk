//
//  WorkerCaller.swift
//
//
//  Created by moizhassankh on 08/11/23.
//

import BackgroundTasks
import UIKit

@available(iOS 13.0, *)
public enum WorkerCaller {
    // Method to update events at session end

    private static var eventUploadTaskIdentifier = "io.kenkai.ingestAppEvents"
    private static var actionDownloadTaskIdentifier = "io.kenkai.fetchActions"
    // iOS throws if a task is submitted without a registered handler, so scheduling checks this.
    private static var isRegistered = false

    // Always register: iOS only runs registered handlers, and a user may turn refresh on mid-session.
    static func registerBackgroundTask() {
        guard !isRegistered else { return }
        // iOS also throws when registering an identifier that is missing from Info.plist.
        let permitted = Bundle.main.object(forInfoDictionaryKey: "BGTaskSchedulerPermittedIdentifiers") as? [String] ?? []
        guard permitted.contains(eventUploadTaskIdentifier), permitted.contains(actionDownloadTaskIdentifier) else {
            print("Skipping background task registration: add \(eventUploadTaskIdentifier) and \(actionDownloadTaskIdentifier) to BGTaskSchedulerPermittedIdentifiers in Info.plist")
            return
        }
        registerEventUploadTask()
        registerActionDownloadTask()
        isRegistered = true
    }

    static func scheduleBackgroundTasks() {
        guard isRegistered else {
            print("Skipping background task scheduling: handlers were not registered during app launch")
            return
        }
        if(Kenkai.shared.isBackgroundAppRefreshEnabled()){
            scheduleEventUploadTask()
            scheduleActionDownloadTask()
        }
    }

    private static func registerEventUploadTask() {
        print("Register background task: \(WorkerCaller.eventUploadTaskIdentifier)")
        BGTaskScheduler.shared.register(forTaskWithIdentifier: WorkerCaller.eventUploadTaskIdentifier, using: nil) { task in
            // A background launch can happen before the host initializes the SDK; stored events wait for the next upload.
            guard !CoreConstants.shared.sdkKey.isEmpty else {
                task.setTaskCompleted(success: true)
                return
            }
            Task {
                do {
                    
                    try await InjestEvenstuploader.uploadEvents()
                    try await CatalogEventsUploader.uploadEvents()
                    print("Background task \(task.identifier) completed")
                    task.setTaskCompleted(success: true)
                    
                } catch {
                    scheduleEventUploadTask(earliestBeginDate: Date(timeIntervalSinceNow: 10 * 60)) // try again in 10 minutes
                    print("Background task error: \(error.localizedDescription)")
                    task.setTaskCompleted(success: false)
                }
            }
        }
    }

    private static func registerActionDownloadTask() {
        print("Register background task: \(WorkerCaller.actionDownloadTaskIdentifier)")
        BGTaskScheduler.shared.register(forTaskWithIdentifier: WorkerCaller.actionDownloadTaskIdentifier, using: nil) { task in
            guard !CoreConstants.shared.sdkKey.isEmpty else {
                task.setTaskCompleted(success: true)
                return
            }
            Task {
                do {
                    try await CFActionListener.shared.fetchAndDisplayPushNotificationActions()
                    if(CoreConstants.shared.isAppOpen && CoreConstants.shared.autoShowInAppMessage){
                        try await CFActionListener.shared.fetchAndDisplayInAppMessagesAction(actionScreenType: ActionScreenType.None)
                    }
                    print("Background task \(task.identifier) completed")
                    task.setTaskCompleted(success: true)
                } catch {
                    print("Background task error: \(error.localizedDescription)")
                    task.setTaskCompleted(success: false)
                }
                scheduleActionDownloadTask()
            }
        }
    }

    private static func scheduleEventUploadTask(earliestBeginDate: Date? = nil) {
        let request = BGProcessingTaskRequest(identifier: WorkerCaller.eventUploadTaskIdentifier)
        request.requiresNetworkConnectivity = true // Set as needed
        request.requiresExternalPower = false // Set as needed
        request.earliestBeginDate = earliestBeginDate
        do {
            try BGTaskScheduler.shared.submit(request)
            print("Submitted background task: \(request.identifier)")
        } catch {
            print("Unable to schedule background task: \(error.localizedDescription)")
            if let nsError = error as NSError? {
                print("Error domain: \(nsError.domain)")
            }
        }
    }

    private static func scheduleActionDownloadTask(earliestBeginDate: Date = Date(timeIntervalSinceNow: CFActionListener.shared.timeInterval)) {
        let request = BGAppRefreshTaskRequest(identifier: WorkerCaller.actionDownloadTaskIdentifier)
        request.earliestBeginDate = earliestBeginDate
        do {
            try BGTaskScheduler.shared.submit(request)
            print("Submitted background task: \(request.identifier)")
            // add breakpoint to print statement above and execute command:
            // e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"io.kenkai.fetchActions"]
        } catch {
            print("Unable to schedule background task: \(error)")
        }
    }

    public static func performUpload() async throws {
        try await InjestEvenstuploader.uploadEvents()
        try await CatalogEventsUploader.uploadEvents()
    }
    
    public static func performSanitizedUpload(indexToRemove : Int?){
        if(indexToRemove == nil){
            return
        }
        
        Task {
            do {
                try await InjestEvenstuploader.uploadEventsAfterRemovingSanitize(indexToRemove: indexToRemove!)
            } catch {
            }
        }
    }
}

