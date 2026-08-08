//
//  MediaType.swift
//
//
//  Created by khushbu on 09/10/23.
//

import Foundation

public enum MediaType: String, EnumComposable {
    case Audio
    case Video
    case Image
    
    public var rawValue: String {
        switch self {
        case .Audio: return "audio"
        case .Video: return "video"
        case .Image: return "image"
        }
    }
    
}
