//
//  EducationalLevel.swift
//
//
//  Created by khushbu on 25/10/23.
//

import Foundation

public enum EducationalLevel: String, EnumComposable {
    case Primary
    case LowerSecondary
    case UpperSecondary
    case NonTertiary
    case Tertiary
    case Bachelors
    case Masters
    case Doctorate
    
    public var rawValue: String {
        switch self {
        case .Primary: return "primary"
        case .LowerSecondary: return "lower_secondary"
        case .UpperSecondary: return "upper_secondary"
        case .NonTertiary: return "non_tertiary"
        case .Tertiary: return "tertiary"
        case .Bachelors: return "bachelors"
        case .Masters: return "masters"
        case .Doctorate: return "doctorate"
        }
    }
    
}
