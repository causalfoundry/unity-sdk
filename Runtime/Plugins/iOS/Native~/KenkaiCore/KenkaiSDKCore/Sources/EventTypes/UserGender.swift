//
//  UserGender.swift
//
//
//  Created by MOIZ HASSAN KHAN on 25/4/24.
//

import Foundation

public enum UserGender: String, EnumComposable {
    case Male
    case Female
    case Other
    case UnDisclosed
    
    public var rawValue: String {
        switch self {
        case .Male: return "male"
        case .Female: return "female"
        case .Other: return "other"
        case .UnDisclosed: return "undisclosed"
        }
    }
    
}
