//
//  File.swift
//  
//
//  Created by MOIZ HASSAN KHAN on 27/8/24.
//

import Foundation

public enum CoreCatalogType: String, CaseIterable, Codable {
    case User
    case Site
    case Media
    case Other
    
    public var rawValue: String {
        switch self {
        case .User: return "user"
        case .Site: return "site"
        case .Media: return "media"
        case .Other: return "other"
        }
    }
    
}
