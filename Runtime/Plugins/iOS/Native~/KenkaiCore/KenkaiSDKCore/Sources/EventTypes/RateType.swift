//
//  RateType.swift
//
//
//  Created by khushbu on 10/10/23.
//

import Foundation

public enum RateType: String, EnumComposable {
    case Order
    case Item
    case Media
    case Exam
    case Question
    case Module
    case Process
    case Form
    case Section
    case App
    case Other
    case HCW
    case HcwSite
    case Facility
    case Assessment
    case Customer
    
    public var rawValue: String {
        switch self {
        case .Order: return "order"
        case .Item: return "item"
        case .Media: return "media"
        case .Exam: return "exam"
        case .Question: return "question"
        case .Module: return "module"
        case .Process: return "process"
        case .Form: return "form"
        case .Section: return "section"
        case .App: return "app"
        case .Other: return "other"
        case .HCW: return "hcw"
        case .HcwSite: return "hcw_site"
        case .Facility: return "facility"
        case .Assessment: return "assessment"
        case .Customer: return "customer"
        }
    }
    
}
