//
//  GlobalSDKEventTypes.swift
//  KenkaiSDK
//
//  Created by MOIZ HASSAN KHAN on 12/8/25.
//
public enum GlobalSDKEventTypes: String, EnumComposable {
    
    // CORE
    case Identify
    case Page
    case App
    case Search
    case Media
    case ActionResponse
    case Rate
    case ModuleSelection
    case Track
    
    // ECommerce
    case Item
    case Delivery
    case Checkout
    case Cart
    case CancelCheckout
    case ItemReport
    case ItemRequest
    
    // ELearning
    case Module
    case Exam
    case Question
    
    // Loyalty
    case Level
    case Milestone
    case Promo
    case Survey
    case Reward
    
    // Payments
    case Payment
    
    // Patient Mgmt
    case Patient
    case Encounter
    case Appointment
    case Diagnosis
    
    public var rawValue: String {
        switch self {
        // CORE
        case .Identify: return "identify"
        case .Page: return "page"
        case .App: return "app"
        case .Search: return "search"
        case .Media: return "media"
        case .ActionResponse: return "action_response"
        case .Rate: return "rate"
        case .ModuleSelection: return "module_selection"
        case .Track: return "track"
            
        // ECommerce
        case .Item: return "item"
        case .Delivery: return "delivery"
        case .Checkout: return "checkout"
        case .Cart: return "cart"
        case .CancelCheckout: return "cancel_checkout"
        case .ItemReport: return "item_report"
        case .ItemRequest: return "item_request"
            
        // ELearning
        case .Module: return "module"
        case .Exam: return "exam"
        case .Question: return "question"
            
        // Loyalty
        case .Level: return "level"
        case .Milestone: return "milestone"
        case .Promo: return "promo"
        case .Survey: return "survey"
        case .Reward: return "reward"
            
        // Payments
        case .Payment: return "payment"
            
        // Patient Mgmt
        case .Patient: return "patient"
        case .Encounter: return "encounter"
        case .Appointment: return "appointment"
        case .Diagnosis: return "diagnosis"
        }
    }
}


