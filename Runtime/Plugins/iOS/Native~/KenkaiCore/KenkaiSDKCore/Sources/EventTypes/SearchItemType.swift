//
//  SearchItemType.swift
//
//
//  Created by khushbu on 16/10/23.
//

import Foundation

public enum SearchItemType: String, EnumComposable {
    case Blood
    case Oxygen
    case Drug
    case Grocery
    case Facility
    case MedicalEquipment
    case Appointment
    case Assessment
    case MedicalRecord
    case Subscription
    case Electronics
    case Clothing
    case Book
    case PatientRecord
    case LifestylePlanItem
    case PsychologicalPlanItem
    case CounselingPlanItem
    case InvestigationTestItem
    case TreatmentPlanItem
    case ItemVerification
    case ItemReport
    case Reward
    case Survey
    case Other
    
    public var rawValue: String {
        switch self {
        case .Blood: return "blood"
        case .Oxygen: return "oxygen"
        case .Drug: return "drug"
        case .Grocery: return "grocery"
        case .Facility: return "facility"
        case .MedicalEquipment: return "medical_equipment"
        case .Appointment: return "appointment"
        case .Assessment: return "assessment"
        case .MedicalRecord: return "medical_record"
        case .Subscription: return "subscription"
        case .Electronics: return "electronics"
        case .Clothing: return "clothing"
        case .Book: return "book"
        case .PatientRecord: return "patient_record"
        case .LifestylePlanItem: return "lifestyle_plan_item"
        case .PsychologicalPlanItem: return "psychological_plan_item"
        case .CounselingPlanItem: return "counseling_plan_item"
        case .InvestigationTestItem: return "investigation_test_item"
        case .TreatmentPlanItem: return "treatment_plan_item"
        case .ItemVerification: return "item_verification"
        case .ItemReport: return "item_report"
        case .Reward: return "reward"
        case .Survey: return "survey"
        case .Other: return "other"
        }
    }
}
