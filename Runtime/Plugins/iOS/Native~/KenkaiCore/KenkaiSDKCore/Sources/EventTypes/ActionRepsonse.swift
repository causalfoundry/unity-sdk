//
//  ActionRepsonse.swift
//  KenkaiSDK
//
//  Created by MOIZ HASSAN KHAN on 13/8/25.
//
import Foundation

public enum ActionRepsonse: String, EnumComposable {
    case Open
    case Discard
    case Block
    case Shown
    case Error
    case Expired
    
    public var rawValue: String {
            switch self {
            case .Open: return "open"
            case .Discard: return "discard"
            case .Block: return "block"
            case .Shown: return "shown"
            case .Error: return "error"
            case .Expired: return "expired"
            }
        }
}
