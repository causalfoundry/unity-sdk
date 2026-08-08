//
//  ActionDeliveryMode.swift
//  KenkaiSDK
//
//  Created by MOIZ HASSAN KHAN on 07/11/25.
//

import Foundation

public enum ActionDeliveryMode: String, EnumComposable {
    case OneOff
    case Cached
    
    public var rawValue: String {
            switch self {
            case .OneOff: return "one-off"
            case .Cached: return "cached"
            }
        }
}
