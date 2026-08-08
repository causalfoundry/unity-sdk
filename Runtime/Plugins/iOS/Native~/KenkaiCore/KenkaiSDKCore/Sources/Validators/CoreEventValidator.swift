//
//  File.swift
//  
//
//  Created by MOIZ HASSAN KHAN on 28/8/24.
//

import Foundation

public class CoreEventValidator {

    static func validateAppObject<T:Codable>(logObject: T?) -> AppObject? {
        let appObject: AppObject? = {
            if let appObject = logObject as? AppObject {
                return appObject
            } else {
                ExceptionManager.throwInvalidException(eventType: CoreEventType.App.rawValue,
                                                       paramName: "AppObject", className: "AppObject")
                return nil
            }
        }()
        if let appObject = appObject {
            // Will throw an exception if the action provided is null or no action is provided at all.
            if appObject.action.isEmpty {
                ExceptionManager.throwInvalidException(eventType: CoreEventType.App.rawValue,
                                                       paramName: String(describing: AppAction.self),
                                                       className: String(describing: AppAction.self))
            } else if !CoreConstants.shared.enumContains(AppAction.self, name: appObject.action) {
                ExceptionManager.throwEnumException(eventType: CoreEventType.App.rawValue,
                                                       className: String(describing: AppAction.self))
            } else if appObject.startTime < 0 {
                ExceptionManager.throwInvalidException(eventType: CoreEventType.App.rawValue,
                                                       paramName: "startTime",
                                                       className: String(describing: Int.self))
            } else {
                return appObject
            }
        }
        return nil
    }
    
    static func validateSearchObject<T:Codable>(logObject: T?) -> SearchObject? {
        let eventObject: SearchObject? = {
            if let eventObject = logObject as? SearchObject {
                return eventObject
            } else {
                ExceptionManager.throwInvalidException(eventType: CoreEventType.Search.rawValue,
                                                       paramName: "SearchObject", className: "SearchObject")
                return nil
            }
        }()
        if let eventObject = eventObject {
            // Will throw an exception if the action provided is null or no action is provided at all.
            if eventObject.page < 0 {
                ExceptionManager.throwInvalidException(eventType: CoreEventType.Search.rawValue,
                                                       paramName: "page",
                                                       className: String(describing: Int.self))
            } else {
                
                let allItemsValid = eventObject.resultsList.allSatisfy { item in
                    CoreConstants.shared.isSearchItemModelObjectValid(itemValue: item,  eventType: CoreEventType.Search)
                }
                
                if(allItemsValid){
                    return eventObject
                }
            }
        }
        return nil
    }
    
    static func validateIdentifyObject<T:Codable>(logObject: T?) -> IdentifyObject? {
        
        let eventObject: IdentifyObject? = {
            if let eventObject = logObject as? IdentifyObject {
                return eventObject
            } else {
                ExceptionManager.throwInvalidException(eventType: CoreEventType.Identify.rawValue,
                                                       paramName: "IdentifyObject", className: "IdentifyObject")
                return nil
            }
        }()
        if let eventObject = eventObject {
            // Will throw an exception if the action provided is null or no action is provided at all.
            if eventObject.userId == nil || eventObject.userId!.isEmpty {
                ExceptionManager.throwInvalidException(eventType: CoreEventType.Identify.rawValue,
                                                       paramName: "userId",
                                                       className: "userId")
            } else if [IdentifyAction.Blocked.rawValue, IdentifyAction.Unblocked.rawValue].contains(eventObject.action),
                      eventObject.blockedReason?.isEmpty ?? true {
                
                ExceptionManager.throwInvalidException(eventType: CoreEventType.Identify.rawValue,
                                                       paramName: "blocked object reason",
                                                       className: "blocked object reason")
            } else {
                
                if eventObject.action == IdentifyAction.Logout.rawValue {
                    CoreConstants.shared.logoutEvent = true
                }else{
                    CFSetup().updateUserId(appUserId: eventObject.userId!)
                }
                
                return eventObject
            }
        }
        return nil
    }
    
    static func validateMediaObject<T:Codable>(logObject: T?) -> MediaObject? {
        let eventObject: MediaObject? = {
            if let eventObject = logObject as? MediaObject {
                return eventObject
            } else {
                ExceptionManager.throwInvalidException(eventType: CoreEventType.Media.rawValue,
                                                       paramName: "MediaObject", className: "MediaObject")
                return nil
            }
        }()
        if var eventObject = eventObject {
            // Will throw an exception if the action provided is null or no action is provided at all.
            if eventObject.mediaId.isEmpty {
                ExceptionManager.throwIsRequiredException(eventType: CoreEventType.Media.rawValue, elementName: "media Id")
            } else if eventObject.seekTime < 0 {
                ExceptionManager.throwInvalidException(eventType: CoreEventType.Media.rawValue,
                                                       paramName: "media seek time",
                                                       className: String(describing: Float.self))
            } else {
                
                if (eventObject.mediaType == MediaType.Image.rawValue) {
                    eventObject.mediaAction = MediaAction.View.rawValue
                    eventObject.seekTime = 0
                }
                
                return eventObject
            }
        }
        return nil
    }
    
    public static func mapStringToMediaObject(objectString: String) -> MediaObject? {
        guard let data = objectString.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(MediaObject.self, from: data)
    }
    
    static func validateModuleSelectionObject<T:Codable>(logObject: T?) -> ModuleSelectionObject? {
        guard let eventObject = logObject as? ModuleSelectionObject else {
            ExceptionManager.throwInvalidException(
                eventType: CoreEventType.ModuleSelection.rawValue,
                paramName: "ModuleSelectionObject",
                className: "ModuleSelectionObject"
            )
            return nil
        }
        return eventObject
    }
    
    static func validatePageObject<T:Codable>(logObject: T?) -> PageObject? {
        
        let eventObject: PageObject? = {
            if let eventObject = logObject as? PageObject {
                return eventObject
            } else {
                ExceptionManager.throwInvalidException(eventType: CoreEventType.Page.rawValue,
                                                       paramName: "PageObject", className: "PageObject")
                return nil
            }
        }()
        if let eventObject = eventObject {
            // Will throw an exception if the action provided is null or no action is provided at all.
            if eventObject.path.isEmpty {
                ExceptionManager.throwInvalidException(eventType: CoreEventType.Page.rawValue,
                                                       paramName: "path",
                                                       className: "path")
            } else if eventObject.title.isEmpty {
                ExceptionManager.throwInvalidException(eventType: CoreEventType.Page.rawValue,
                                                       paramName: "title",
                                                       className: "title")
            } else if eventObject.renderTime < 0 {
                ExceptionManager.throwInvalidException(eventType: CoreEventType.Page.rawValue,
                                                       paramName: "render_time",
                                                       className: "render_time")
            } else {
                return eventObject
            }
        }
        return nil
    }
    
    static func validateRateObject<T:Codable>(logObject: T?) -> RateObject? {
        let eventObject: RateObject? = {
            if let eventObject = logObject as? RateObject {
                return eventObject
            } else {
                ExceptionManager.throwInvalidException(eventType: CoreEventType.Rate.rawValue,
                                                       paramName: "RateObject", className: "RateObject")
                return nil
            }
        }()
        if let eventObject = eventObject {
            // Will throw an exception if the action provided is null or no action is provided at all.
            if eventObject.subjectId.isEmpty {
                ExceptionManager.throwIsRequiredException(eventType: CoreEventType.Rate.rawValue, elementName: "rate subject Id")
            } else if eventObject.rateValue < 0 {
                ExceptionManager.throwInvalidException(eventType: CoreEventType.Rate.rawValue,
                                                       paramName: "rate value",
                                                       className: String(describing: Int.self))
            } else {
                return eventObject
            }
        }
        return nil
    }
    
    static func validateTrackObject<T:Codable>(logObject: T?) -> TrackEventObject? {
        
        let eventObject: TrackEventObject? = {
            if let eventObject = logObject as? TrackEventObject {
                return eventObject
            } else {
                ExceptionManager.throwInvalidException(eventType: CoreEventType.Track.rawValue,
                                                       paramName: "TrackEventObject", className: "TrackEventObject")
                return nil
            }
        }()
    
        
        if var eventObject = eventObject {
            let snakeCaseName = eventObject.name.toSnakeCase()
            // Will throw an exception if the action provided is null or no action is provided at all.
            if eventObject.name.isEmpty {
                ExceptionManager.throwIsRequiredException(
                    eventType: CoreEventType.Track.rawValue,
                    elementName: "Track Event Name"
                )
            }
            else if CoreConstants.shared.enumContains(GlobalSDKEventTypes.self, name: snakeCaseName) {
                ExceptionManager.throwNameAlreadyInUseException(
                    eventObject.name
                )
            }
            else {
                eventObject.name = snakeCaseName
                return eventObject
            }
        }
        return nil
    }
    
    static func validateActionResponseObject<T:Codable>(logObject: T?) -> ActionRepsonseObject? {
        
        let eventObject: ActionRepsonseObject? = {
            if let eventObject = logObject as? ActionRepsonseObject {
                return eventObject
            } else {
                ExceptionManager.throwInvalidException(eventType: CoreEventType.ActionResponse.rawValue,
                                                       paramName: "response", className: "ActionResponse")
                return nil
            }
        }()
    
        
        if let eventObject = eventObject {
            // Will throw an exception if the action provided is null or no action is provided at all.
            if eventObject.response.isEmpty {
                ExceptionManager.throwIsRequiredException(eventType: CoreEventType.ActionResponse.rawValue, elementName:  "action.response")
            }
            else if !CoreConstants.shared.enumContains(ActionRepsonse.self, name: eventObject.response) {
                ExceptionManager.throwEnumException(eventType: CoreEventType.ActionResponse.rawValue, className:  "action_response")
            }
            else {
                return eventObject
            }
        }
        return nil
        
    }

}
