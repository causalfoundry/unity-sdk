//
//  MediaAction.swift
//
//
//  Created by khushbu on 09/10/23.
//

import Foundation

public enum MediaAction: String, EnumComposable {
    case View
    case Play
    case Pause
    case Seek
    case Finish
    case Impression
    
    public var rawValue: String {
            switch self {
            case .View: return "view"
            case .Play: return "play"
            case .Pause: return "pause"
            case .Seek: return "seek"
            case .Finish: return "finish"
            case .Impression: return "impression"
            }
        }
}
