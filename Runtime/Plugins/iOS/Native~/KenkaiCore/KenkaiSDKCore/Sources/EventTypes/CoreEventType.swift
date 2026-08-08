//
//  CoreEventType.swift
//
//
//  Created by khushbu on 17/09/23.
//

import Foundation

public enum CoreEventType: String, EnumComposable {
    case Identify
    case Page
    case App
    case Search
    case Media
    case ActionResponse
    case Rate
    case Track
    case ModuleSelection

    public var rawValue: String {
        switch self {
        case .Identify: return "identify"
        case .Page: return "page"
        case .App: return "app"
        case .Search: return "search"
        case .Media: return "media"
        case .ActionResponse: return "action_response"
        case .Rate: return "rate"
        case .Track: return "track"
        case .ModuleSelection: return "module_selection"
        }
    }
}
