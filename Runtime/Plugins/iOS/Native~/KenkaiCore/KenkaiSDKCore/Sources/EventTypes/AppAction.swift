//
//  AppAction.swift
//
//
//  Created by khushbu on 17/09/23.
//

import Foundation

public enum AppAction: String, EnumComposable {
    case Open
    case Close
    case Background
    case Resume
    
    public var rawValue: String {
        switch self {
        case .Open: return "open"
        case .Close: return "close"
        case .Background: return "background"
        case .Resume: return "resume"
        }
    }
}
