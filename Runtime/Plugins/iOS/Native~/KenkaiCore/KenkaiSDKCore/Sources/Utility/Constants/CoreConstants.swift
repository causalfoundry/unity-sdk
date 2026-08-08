//
//  CoreConstants.swift
//
//
//  Created by khushbu on 11/09/23.
//

import Foundation
import UIKit

public class CoreConstants {
    public static let shared = CoreConstants()

    public let devUrl = "https://api.kenkai.io/v1/"
    public let prodUrl = "https://api.kenkai.io/v1/"
    public private(set) var apiUrl: String

    
    
    private init() {
            // Initialize apiUrl with the default prodUrl
            self.apiUrl = prodUrl
        }
    public func setApiUrl(to url: String) {
            apiUrl = url
        }
    
    public var userId: String? {
        get {
            var id = MMKVHelper.shared.fetchUserID()
            if id?.isEmpty == true {
                id = UIDevice.current.identifierForVendor?.uuidString
            }
            return id
        }
        set { MMKVHelper.shared.writeUser(user: newValue) }
    }
    
    public var applicationContext: UIApplication? = nil
    var sdkKey: String = ""
    var isDebugMode: Bool = true
    var allowAutoPageTrack: Bool = true
    var isAnonymousUserAllowed: Bool = false
    public var contentBlock: ContentBlock = .Core
    var contentBlockName: String {
        return contentBlock.rawValue
    }

    var SDKVersion: String = "ios/1.0.10"

    public var updateImmediately: Bool = false

    public var pauseSDK: Bool = false
    public var autoShowInAppMessage: Bool = true
    var sessionStartTime: Int64 = 0
    var sessionEndTime: Int64 = 0

    var internalInfoObject: InternalInfoObject?
    
    public var previousSearchId: String = ""

    public var userIdKey: String = "userIdKey"

    public var isAppDebuggable: Bool = true

    public var logoutEvent: Bool = false

    public var isAppOpen: Bool = false
    public var isAppPaused: Bool = false

    public var impressionItemsList = [String]()

    public var isAgainRate: Bool = false

    /// Unity bridge extension: apply a runtime consent change to ingestion and automatic actions.
    public func setUnityRuntimePaused(_ paused: Bool) {
        pauseSDK = paused
        if paused {
            CFActionListener.shared.endListening()
        } else {
            CFActionListener.shared.beginListening()
        }
    }

    public func enumContains<T: EnumComposable>(_: T.Type, name: String?) -> Bool where T.RawValue == String {
        if(name == nil || name!.isEmpty){
            return false
        }
        return T.allCases.contains { $0.rawValue == name }
    }
}

public protocol EnumComposable: Codable, RawRepresentable, CaseIterable {}

extension CoreConstants {
    func isSearchItemModelObjectValid(itemValue: String, eventType: CoreEventType) -> Bool {

        let eventName = eventType.rawValue
        guard !itemValue.isEmpty else {
            ExceptionManager.throwIsRequiredException(eventType: eventName, elementName: "item_id")
            return false
        }
        
        return true
        
    }


    func getUserTimeZone() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "XXX" // ISO 8601 timezone format with colon
        return dateFormatter.string(from: Date())
    }

    public func checkIfNull(_ inputValue: String?) -> String {
        if let value = inputValue, !value.isEmpty {
            return value
        }
        return ""
    }
    private static func getDateTime(milliSeconds: Int64) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        let date: Date
        if milliSeconds == 0 {
            date = Date()
        } else {
            date = Date(timeIntervalSince1970: TimeInterval(milliSeconds) / 1000)
        }
        
        return dateFormatter.string(from: date)
    }

    public static func getTimeConvertedToString(_ eventTime: Int64) -> String {
        if eventTime != 0 {
            return getDateTime(milliSeconds: eventTime)
        } else {
            return ""
        }
    }

}
