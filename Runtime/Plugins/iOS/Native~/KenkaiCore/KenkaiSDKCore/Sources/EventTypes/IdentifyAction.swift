//
//  IdentifyAction.swift
//
//
//  Created by khushbu on 28/09/23.
//

import Foundation

public enum IdentifyAction: String, EnumComposable {
    case Register
    case Login
    case Logout
    case Blocked
    case Unblocked
    
    public var rawValue: String {
            switch self {
            case .Register: return "register"
            case .Login: return "login"
            case .Logout: return "logout"
            case .Blocked: return "blocked"
            case .Unblocked: return "unblocked"
            }
        }
}
