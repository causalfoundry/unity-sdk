//
//  IngestAPIHandler.swift
//
//
//  Created by moizhassankh on 12/09/23.
//

import Combine
import Foundation

public class IngestAPIHandler: NSObject {

    static let shared = IngestAPIHandler()
    
    private let reachability = try? Reachability()

    func ingestTrackAPI<T: Codable>(eventName: String,
                                    eventProperty: String?,
                                    eventCtx: T,
                                    updateImmediately: Bool,
                                    eventTime _: Int64 = 0)
    {
        if #available(iOS 13.0, *) {
            guard !CoreConstants.shared.pauseSDK else { return }
            
            let isInternetAvailable = reachability?.connection == .wifi || reachability?.connection == .cellular
            let eventObject = EventDataObject(ol: isInternetAvailable, ts: Date(), name: eventName, property: eventProperty ?? "", ctx: eventCtx)

            if updateImmediately && isInternetAvailable {
                updateEventTrack(eventArray: [eventObject]) { [weak self] success in
                    if !success {
                        self?.storeEventTrack(eventObject: eventObject)
                    }
                }
            } else {
                storeEventTrack(eventObject: eventObject)
            }
            if(CoreConstants.shared.logoutEvent){
                Task {
                    do {
                        try await WorkerCaller.performUpload()
                        MMKVHelper.shared.deleteAllUserID()
                        CoreConstants.shared.logoutEvent = false
                        CoreConstants.shared.userId = ""
                        
                    } catch {
                        print("unable to log sdk events")
                    }
                }
            }
        }
    }

    /// Calls back exactly once; `false` means the events were not sent and must stay stored.
    func updateEventTrack(eventArray: [EventDataObject], callback: @escaping (Bool) -> Void) {
        guard #available(iOS 13.0, *) else {
            callback(false)
            return
        }

        // The logged-in user comes first; the device id stands in only when anonymous users are allowed.
        var userId = MMKVHelper.shared.fetchUserID()
        if userId?.isEmpty != false {
            userId = MMKVHelper.shared.fetchUserBackupID()
        }
        if userId?.isEmpty != false, CoreConstants.shared.isAnonymousUserAllowed {
            userId = CoreConstants.shared.internalInfoObject?.device_id
        }

        // No user to attribute the events to yet (or not initialized): keep them stored for a later upload.
        guard let userID = userId, !userID.isEmpty, CoreConstants.shared.internalInfoObject != nil else {
            callback(false)
            return
        }
        print("Uploading \(eventArray.count) events for user \(userID): \(eventArray.map { $0.name })")

        do {
            CoreConstants.shared.internalInfoObject?.s_id = "\(userID)_\(CoreConstants.shared.sessionStartTime)_\(CoreConstants.shared.sessionEndTime)"

            let mainBody = MainBody(
                userID: userID,
                timezone: CoreConstants.shared.getUserTimeZone(),
                internalInfoObject: CoreConstants.shared.internalInfoObject!,
                data: eventArray)

            let dictionary = mainBody.dictionary ?? [:]

            if dictionary.isEmpty {
                print("Unable to encode ingest events")
                callback(false)
                return
            }
            guard let url = URL(string: APIConstants.trackEvent) else {
                callback(false)
                return
            }
            BackgroundRequestController.shared.request(url: url, httpMethod: .post, params: dictionary) { result in
                switch result {
                case .success:
                    callback(true)
                case .failure:
                    callback(false)
                }
            }
        }
    }

    private func storeEventTrack(eventObject: EventDataObject) {
        if #available(iOS 13.0, *) {
            MMKVHelper.shared.appendInjectEvent(eventObject)
        }
    }
}

