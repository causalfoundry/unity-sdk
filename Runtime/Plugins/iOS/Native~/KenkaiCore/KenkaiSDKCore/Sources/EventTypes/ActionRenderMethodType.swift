//
//  ActionRenderMethodType.swift
//  KenkaiSDK
//
//  Created by MOIZ HASSAN KHAN on 13/8/25.
//

import Foundation

public enum ActionRenderMethodType: String, EnumComposable {
    case PushNotification
    case InAppMessage
    case InAppComponent
    
    public var rawValue: String {
            switch self {
            case .PushNotification: return "push_notification"
            case .InAppMessage: return "in_app_message"
            case .InAppComponent: return "in_app_component"
            }
        }
}
