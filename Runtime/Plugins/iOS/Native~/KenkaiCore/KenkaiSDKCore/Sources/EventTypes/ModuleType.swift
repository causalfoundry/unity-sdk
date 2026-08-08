//
//  SearchModuleType.swift
//
//
//  Created by moizhassankh on 14/03/25.
//

import Foundation

public enum ModuleType: String, EnumComposable {
    case Core
    case ECommerce
    case ELearning
    case Screening
    case Assessment
    case Enrolment
    case MedicalReview
    case MyPatients
    case Prescription
    case LifestyleMgmt
    case PsychologicalMgmt
    case CounselingMgmt
    case Investigation
    case TreatmentPlan
    case Transfers
    case Appointments
    case HCWMgmt
    case Break
    case CallerHistory
    case AttendCall
    case Single
    case Dashboard
    case Map
    case Other
    
    public var rawValue: String {
        switch self {
        case .Core: return "core"
        case .ECommerce: return "e_commerce"
        case .ELearning: return "e_learning"
        case .Screening: return "screening"
        case .Assessment: return "assessment"
        case .Enrolment: return "enrolment"
        case .MedicalReview: return "medical_review"
        case .MyPatients: return "my_patients"
        case .Appointments: return "appointments"
        case .Prescription: return "prescription"
        case .LifestyleMgmt: return "lifestyle_mgmt"
        case .PsychologicalMgmt: return "psychological_mgmt"
        case .CounselingMgmt: return "counseling_mgmt"
        case .Investigation: return "investigation"
        case .TreatmentPlan: return "treatment_plan"
        case .Transfers: return "transfers"
        
        case .HCWMgmt: return "hcw_mgmt"
        case .Break: return "break"
        case .CallerHistory: return "caller_history"
        case .AttendCall: return "attend_call"
        case .Single: return "single"
        case .Dashboard: return "dashboard"
        case .Map: return "map"
            
        case .Other: return "other"
        }
    }
}
