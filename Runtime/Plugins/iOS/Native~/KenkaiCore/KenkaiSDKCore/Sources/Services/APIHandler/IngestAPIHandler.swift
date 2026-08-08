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
    
    private let reachability = try! Reachability()

    func ingestTrackAPI<T: Codable>(eventName: String,
                                    eventProperty: String?,
                                    eventCtx: T,
                                    updateImmediately: Bool,
                                    eventTime _: Int64 = 0)
    {
        if #available(iOS 13.0, *) {
            guard !CoreConstants.shared.pauseSDK else { return }
            
            let isInternetAvailable = reachability.connection == .wifi || reachability.connection == .cellular
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

    func updateEventTrack(eventArray: [EventDataObject], callback: @escaping (Bool) -> Void) {
        if #available(iOS 13.0, *) {
            if(!CoreConstants.shared.isAnonymousUserAllowed){
                return
            }
            
            var userId = CoreConstants.shared.userId
            
            if(userId == nil || userId?.isEmpty == true){
                userId = MMKVHelper.shared.fetchUserBackupID()
            }
            
            if(userId ==  nil || userId?.isEmpty == true){
                userId = CoreConstants.shared.internalInfoObject?.device_id
            }
            
            CoreConstants.shared.internalInfoObject?.s_id = "\(userId!)_\(CoreConstants.shared.sessionStartTime)_\(CoreConstants.shared.sessionEndTime)"
            
            let mainBody = MainBody(
                userID: userId!,
                timezone: CoreConstants.shared.getUserTimeZone(),
                internalInfoObject: CoreConstants.shared.internalInfoObject!,
                data: eventArray)
            
            let dictionary = mainBody.dictionary ?? [:]
            
            if dictionary.isEmpty {
                print("No More Injest events")
                return
            }
            let url = URL(string: APIConstants.trackEvent)!
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
            var prevEvent = MMKVHelper.shared.readInjectEvents()
            prevEvent.append(eventObject)
            MMKVHelper.shared.writeEvents(eventsArray: prevEvent)
        }
    }
}

