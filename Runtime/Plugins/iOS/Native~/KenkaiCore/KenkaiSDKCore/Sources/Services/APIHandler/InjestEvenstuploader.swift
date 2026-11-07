//
//  InjestEvenstuploader.swift
//
//
//  Created by khushbu on 08/11/23.
//

import Foundation


enum InjestEvenstuploader {
    @available(iOS 13.0, *)
    static func uploadEvents() async throws {
        let injestAPIHandler = IngestAPIHandler()
        // Remove everything that was read on success: unnamed events are never uploaded and would otherwise stay forever.
        let stored = MMKVHelper.shared.readInjectEvents()
        let filteredArray = stored.filter { !$0.isTypeOrPropsEmpty }.removingDuplicates()
        guard filteredArray.count > 0 else {
            print("No More Injest events")
            if !stored.isEmpty { MMKVHelper.shared.removeInjectEvents(stored) }
            return
        }
        try await withCheckedThrowingContinuation { continuation in
            injestAPIHandler.updateEventTrack(eventArray: filteredArray) { success in
                if success {
                    MMKVHelper.shared.removeInjectEvents(stored)
                    continuation.resume(with: .success(()))
                } else {
                    continuation.resume(with: .failure(NSError(domain: "InjestEvenstuploader.uploadEvents", code: 0)))
                }
            }
        }
    }
    
    
    @available(iOS 13.0, *)
    static func uploadEventsAfterRemovingSanitize(indexToRemove : Int) async throws {
        let stored = MMKVHelper.shared.readInjectEvents()
        var filteredArray = stored.filter { !$0.isTypeOrPropsEmpty }.removingDuplicates()
        guard filteredArray.count > 0 else {
            print("No More Injest events")
            if !stored.isEmpty { MMKVHelper.shared.removeInjectEvents(stored) }
            return
        }
        
        if indexToRemove >= 0 && indexToRemove < filteredArray.count {
            let rejected = filteredArray.remove(at: indexToRemove)
            MMKVHelper.shared.removeInjectEvents([rejected])
        }
        
        try await withCheckedThrowingContinuation { continuation in
            IngestAPIHandler().updateEventTrack(eventArray: filteredArray) { success in
                if success {
                    MMKVHelper.shared.removeInjectEvents(stored)
                    continuation.resume(with: .success(()))
                } else {
                    continuation.resume(with: .failure(NSError(domain: "InjestEvenstuploader.uploadEvents", code: 0)))
                }
            }
        }
    }
}

public enum CatalogEventsUploader {
    @available(iOS 13.0, *)
    public static func uploadEvents() async throws {
        guard !CoreConstants.shared.pauseSDK else { return }
        // Before build() there is no SDK key: the API answers 401 and the items would be deleted as if uploaded.
        guard !CoreConstants.shared.sdkKey.isEmpty else { return }
        let catalogAPIHandler = CatalogAPIHandler()
        let stored = MMKVHelper.shared.readCatalogData()
        let filteredArray = stored.filter { !$0.isTypeOrSubjectEmpty }.removingDuplicates()
        guard filteredArray.count > 0 else {
            print("No More Catalog events")
            if !stored.isEmpty { MMKVHelper.shared.removeCatalogData(stored) }
            return
        }
        try await withCheckedThrowingContinuation { continuation in
            catalogAPIHandler.callCatalogAPI(catalogMainObject: filteredArray) { success in
                if success {
                    MMKVHelper.shared.removeCatalogData(stored)
                    continuation.resume(with: .success(()))
                } else {
                    continuation.resume(with: .failure(NSError(domain: "CatalogEventsUploader.uploadEvents", code: 0)))
                }
            }
        }
    }
}
