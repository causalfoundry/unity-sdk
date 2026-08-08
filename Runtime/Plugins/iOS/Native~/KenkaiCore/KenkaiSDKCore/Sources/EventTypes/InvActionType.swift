//
//  InvActionType.swift
//  KenkaiSDK
//
//  Created by MOIZ HASSAN KHAN on 13/8/25.
//

import Foundation

public enum InvActionType: String, EnumComposable {
    case Message
    case UIComponent
    
    public var rawValue: String {
            switch self {
            case .Message: return "message"
            case .UIComponent: return "ui-component"
            }
        }
}
