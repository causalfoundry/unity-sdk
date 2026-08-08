//
//  ContentBlock.swift
//
//
//  Created by khushbu on 11/09/23.
//

import Foundation

public enum ContentBlock: String, EnumComposable {
    case Core,
         ECommerce,
         ELearning,
         Payment,
         Social,
         Loyalty,
         PatientMgmt
    

    public var rawValue: String {
        switch self {
        case .Core: return "core"
        case .ECommerce: return "e-commerce"
        case .ELearning: return "e-learning"
        case .Payment: return "payment"
        case .Social: return "social"
        case .Loyalty: return "loyalty"
        case .PatientMgmt: return "patient_mgmt"
        }
    }
    
}
