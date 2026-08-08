//
//  MaritalStatus.swift
//
//
//  Created by MOIZ HASSAN KHAN on 25/4/24.
//

import Foundation

public enum MaritalStatus: String, EnumComposable {
    case Single
    case Married
    case Widowed
    case Divorced
    case Separated
    case Other
    case UnDisclosed
    
    public var rawValue: String {
            switch self {
            case .Single: return "single"
            case .Married: return "married"
            case .Widowed: return "widowed"
            case .Divorced: return "divorced"
            case .Separated: return "separated"
            case .Other: return "other"
            case .UnDisclosed: return "undisclosed"
            }
        }
}
