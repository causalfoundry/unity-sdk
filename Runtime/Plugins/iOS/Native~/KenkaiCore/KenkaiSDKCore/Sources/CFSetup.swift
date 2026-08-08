//
//  CFSetup.swift
//
//
//  Created by khushbu on 12/09/23.
//

import Foundation
import UIKit

public class CFSetup: NSObject, IngestProtocol {
    public let ingestApiHandler = IngestAPIHandler()
    public let catalogAPIHandler = CatalogAPIHandler()

    private func setup() {
        verifyAccessToken()
       
        CoreConstants.shared.internalInfoObject = getInternalInfo()

        // Change implementation

        CoreConstants.shared.sessionStartTime = Int64(Date().timeIntervalSince1970 * 1000)
        CoreConstants.shared.sessionEndTime = Int64(Date().timeIntervalSince1970 * 1000)
        if !CoreConstants.shared.pauseSDK {
            CFActionListener.shared.beginListening()
        }
    }

    func initalize(pauseSDK: Bool, updateImmediately: Bool) {
        #if DEBUG
        CoreConstants.shared.isAppDebuggable = true
        #else
        CoreConstants.shared.isAppDebuggable = false
        #endif
        CoreConstants.shared.updateImmediately = updateImmediately
        CoreConstants.shared.pauseSDK = pauseSDK
        setup()
    }

    func updateUserId(appUserId: String) {
        if !appUserId.isEmpty {
            CoreConstants.shared.userId = appUserId
            MMKVHelper.shared.writeUserBackup(userId: appUserId)
            if !CoreConstants.shared.pauseSDK {
                CFActionListener.shared.beginListening()
            }
        }
    }

    public func updateCatalogItem<T: Codable>(subject: CatalogSubject, subjectId: String, catalogObject: T) {
        updateCatalogItem(subject: subject.rawValue, subjectId: subjectId, catalogObject: catalogObject)
    }

    func updateCatalogItem<T: Codable>(subject: String, subjectId: String, catalogObject: T) {
        guard !subject.isEmpty, !subjectId.isEmpty else { return }
        catalogAPIHandler.updateCoreCatalogItem(catalogObject: CatalogItemModel(
            id: subjectId,
            type: subject,
            keyValues: catalogObject
        ))
    }

    public func track<T: Codable>(eventName: String, eventProperty: String?, eventCtx: T?, updateImmediately: Bool, eventTime: Int64 = 0) {
        verifyAccessToken()
        ingestApiHandler.ingestTrackAPI(eventName: eventName, eventProperty: eventProperty, eventCtx: eventCtx, updateImmediately: updateImmediately, eventTime: eventTime)
    }

    private func verifyAccessToken() {
        if CoreConstants.shared.sdkKey.isEmpty {
            fatalError("Access key not found")
        }
    }

    // Get Application Info Of app

    private func getInternalInfo() -> InternalInfoObject {
        
        let application = UIApplication.shared
        return InternalInfoObject(
            s_id: "",
            sdk: CoreConstants.shared.SDKVersion,
            app_id: application.bundleIdentifier(),
            app_version: application.versionBuild(),
            device_id: UIDevice.current.identifierForVendor!.uuidString,
            device_os: UIDevice.current.systemName
        )
    }
}
