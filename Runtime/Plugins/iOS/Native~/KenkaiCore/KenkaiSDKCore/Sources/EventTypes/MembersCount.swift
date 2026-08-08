//
//  MembersCount.swift
//
//
//  Created by MOIZ HASSAN KHAN on 25/4/24.
//

import Foundation

public enum MembersCount: String, EnumComposable {
    case None
    case One
    case Two
    case Three
    case Four
    case FiveOrMore
    case Undisclosed
    
    public var rawValue: String {
        switch self {
        case .None: return "none"
        case .One: return "1"
        case .Two: return "2"
        case .Three: return "3"
        case .Four: return "4"
        case .FiveOrMore: return "5_or_more"
        case .Undisclosed: return "undisclosed"
        }
    }
}
