//
//  SiteCatalogType.swift
//
//  Created by MOIZ HASSAN KHAN on 5/11/24.
//


import Foundation

public enum SiteCatalogType: String, EnumComposable {
    case Pharmacy
    case Clinic
    case Community
    
    public var rawValue: String {
            switch self {
            case .Pharmacy: return "pharmacy"
            case .Clinic: return "clinic"
            case .Community: return "community"
            }
        }
}
