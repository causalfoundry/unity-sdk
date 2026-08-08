//
//  File.swift
//
//
//  Created by MOIZ HASSAN KHAN on 27/8/24.
//

import Foundation

internal class CFCoreSetupInterfaceImpl: CFCoreSetupInterface {
    
    
    // Singleton instance
    static let shared = CFCoreSetupInterfaceImpl()
    
    // Private initializer to prevent external instantiation
    private init() {}
    
    
    func trackSDKEvent<T: Codable>(
        eventName: CoreEventType,
        logObject: T?,
        isUpdateImmediately: Bool? = CoreConstants.shared.updateImmediately,
        eventTime: Int64? = 0) {
            
            if CoreConstants.shared.pauseSDK {
                return
            }
        
            validateCoreEvent(eventName: eventName, logObject: logObject, isUpdateImmediately: isUpdateImmediately, eventTime: eventTime)
            
        }
    
    func trackCatalogEvent<T: Codable>(coreCatalogType: CoreCatalogType, subjectId: String, catalogModel: T) {
        if CoreConstants.shared.pauseSDK{
            return
        }
        validateCoreCatalogEvent(coreCatalogType: coreCatalogType,subjectId:subjectId, catalogObject: catalogModel)
    }
    
    private func validateCoreCatalogEvent<T: Codable>(coreCatalogType: CoreCatalogType, subjectId: String, catalogObject: T) {
        switch coreCatalogType {
        case .User:
            switch catalogObject {
            case let userCatalogModel as UserCatalogModel:
                CfCoreCatalog.updateUserCatalogData(subjectId: subjectId, userCatalogModel: userCatalogModel)
            default:
                ExceptionManager.throwInvalidException(
                    eventType: "User Catalog", paramName: "UserCatalogModel", className: String(describing: UserCatalogModel.self)
                )
            }
        case .Site:
            switch catalogObject {
            case let catalogObject as SiteCatalogModel:
                CfCoreCatalog.updateSiteCatalog(subjectId: subjectId, siteCatalogModel: catalogObject)
            default:
                ExceptionManager.throwInvalidException(
                    eventType: "Site Catalog", paramName: "SiteCatalogModel", className: String(describing: SiteCatalogModel.self)
                )
            }
        case .Media:
            switch catalogObject {
            case let mediaCatalogModel as MediaCatalogModel:
                CfCoreCatalog.updateMediaCatalogData(subjectId: subjectId, mediaCatalogModel: mediaCatalogModel)
            default:
                ExceptionManager.throwInvalidException(
                    eventType: "Media Catalog", paramName: "MediaCatalogModel", className: String(describing: MediaCatalogModel.self)
                )
            }
        case .Other:
            switch catalogObject {
            case let otherCatalogModel as OtherCatalogModel:
                CfCoreCatalog.updateOtherCatalog(subjectId: subjectId, otherCatalogModel: otherCatalogModel)
            default:
                ExceptionManager.throwInvalidException(
                    eventType: "Other Catalog", paramName: "OtherCatalogModel", className: String(describing: OtherCatalogModel.self)
                )
            }
        }
    }
    
    private func validateCoreEvent<T: Codable>(eventName: CoreEventType, logObject: T?, isUpdateImmediately: Bool?, eventTime: Int64?) {
        switch eventName {
        case .App:
            let logobj = CoreEventValidator.validateAppObject(logObject: logObject)
            CFSetup().track(
                eventName: CoreEventType.App.rawValue,
                eventProperty: logobj?.action,
                eventCtx: logobj,
                updateImmediately: isUpdateImmediately ?? CoreConstants.shared.updateImmediately,
                eventTime: eventTime ?? 0
            )
        
        case .Page:
            let logobj = CoreEventValidator.validatePageObject(logObject: logObject)
            CFSetup().track(
                eventName: CoreEventType.Page.rawValue,
                eventProperty: logobj?.title,
                eventCtx: logobj,
                updateImmediately: isUpdateImmediately ?? CoreConstants.shared.updateImmediately,
                eventTime: eventTime ?? 0
            )
            
        case .Identify:
            let logobj =  CoreEventValidator.validateIdentifyObject(logObject: logObject)
            CFSetup().track(
                eventName: CoreEventType.Identify.rawValue,
                eventProperty: logobj?.action,
                eventCtx: logobj,
                updateImmediately: isUpdateImmediately ?? CoreConstants.shared.updateImmediately,
                eventTime: eventTime ?? 0
            )
            
        case .Media:
            let logobj =  CoreEventValidator.validateMediaObject(logObject: logObject)
            CFSetup().track(
                eventName: CoreEventType.Media.rawValue,
                eventProperty: logobj?.mediaType,
                eventCtx: logobj,
                updateImmediately: isUpdateImmediately ?? CoreConstants.shared.updateImmediately,
                eventTime: eventTime ?? 0
            )
            
        case .Rate:
            let logobj =  CoreEventValidator.validateRateObject(logObject: logObject)
            CFSetup().track(
                eventName: CoreEventType.Rate.rawValue,
                eventProperty: logobj?.type,
                eventCtx: logobj,
                updateImmediately: isUpdateImmediately ?? CoreConstants.shared.updateImmediately,
                eventTime: eventTime ?? 0
            )
            
        case .Search:
            let logobj =  CoreEventValidator.validateSearchObject(logObject: logObject)
            CFSetup().track(
                eventName: CoreEventType.Search.rawValue,
                eventProperty: logobj?.query,
                eventCtx: logobj,
                updateImmediately: isUpdateImmediately ?? CoreConstants.shared.updateImmediately,
                eventTime: eventTime ?? 0
            )
            
        case .ModuleSelection:
            let logobj =  CoreEventValidator.validateModuleSelectionObject(logObject: logObject)
            CFSetup().track(
                eventName: CoreEventType.ModuleSelection.rawValue,
                eventProperty: logobj?.type,
                eventCtx: logobj,
                updateImmediately: isUpdateImmediately ?? CoreConstants.shared.updateImmediately,
                eventTime: eventTime ?? 0
            )
            
        case .Track:
            if let logobj = CoreEventValidator.validateTrackObject(logObject: logObject) {
                CFSetup().track(
                    eventName: logobj.name, // already a String
                    eventProperty: logobj.property,
                    eventCtx: logobj,
                    updateImmediately: isUpdateImmediately ?? CoreConstants.shared.updateImmediately,
                    eventTime: eventTime ?? 0
                )
            }
            
        case .ActionResponse:
            if let logobj = CoreEventValidator.validateActionResponseObject(logObject: logObject) {
                CFSetup().track(
                    eventName:CoreEventType.ActionResponse.rawValue,
                    eventProperty: logobj.response,
                    eventCtx: logobj,
                    updateImmediately: isUpdateImmediately ?? CoreConstants.shared.updateImmediately,
                    eventTime: eventTime ?? 0
                )
            }
        }
        
    }
}
