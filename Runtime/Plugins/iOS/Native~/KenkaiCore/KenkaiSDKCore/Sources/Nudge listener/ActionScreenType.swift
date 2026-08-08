//
//  ActionScreenType.swift
//
//
//  Created by MOIZ HASSAN KHAN on 25/4/24.
//

import Foundation

public enum ActionScreenType: String, EnumComposable {
    case None
    case Home
    case Search
    case Product
    case Cart
    case Checkout
    case Reminder
    case Favorite
    case Other
    
    public var rawValue: String {
        switch self {
        case .None: return ""
        case .Home: return "home"
        case .Search: return "search"
        case .Product: return "product"
        case .Cart: return "cart"
        case .Checkout: return "checkout"
        case .Reminder: return "reminder"
        case .Favorite: return "favorite"
        case .Other: return "other"
        }
    }
    
    public init?(rawValue: String) {
            switch rawValue {
            case "": self = .None
            case "home": self = .Home
            case "search": self = .Search
            case "product": self = .Product
            case "cart": self = .Cart
            case "checkout": self = .Checkout
            case "reminder": self = .Reminder
            case "favorite": self = .Favorite
            case "other": self = .Other
            default: return nil
            }
        }
    
}
