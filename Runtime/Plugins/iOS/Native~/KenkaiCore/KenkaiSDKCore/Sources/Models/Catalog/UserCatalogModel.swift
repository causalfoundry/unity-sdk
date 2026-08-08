//
//  UserCatalogModel.swift
//
//
//  Created by khushbu on 19/10/23.
//

import Foundation

public struct UserCatalogModel: Codable, Equatable {
    var name: String?
    var country: String?
    var regionState: String?
    var city: String?
    var workplace: String?
    var profession: String?
    var zipcode: String?
    var language: String?
    var experience: String?
    var educationLevel: String?
    var organizationId: String?
    var organizationName: String?
    var accountType: String?
    var birthYear: Int?
    var gender: String?
    var maritalStatus: String?
    var familyMembers: String?
    var childrenUnderFive: String?
    let meta: [String: String]?
    

    
    enum CodingKeys: String, CodingKey {
        case name
        case country
        case regionState = "region_state"
        case city
        case workplace
        case profession
        case zipcode
        case language
        case experience
        case educationLevel = "education_level"
        case organizationId = "organization_id"
        case organizationName = "organization_name"
        case accountType = "account_type"
        case birthYear = "birth_year"
        case gender
        case maritalStatus = "marital_status"
        case familyMembers = "family_members"
        case childrenUnderFive = "children_under_five"
        case meta
    }
    

    public init(name: String? = "", country: String? = "", regionState: String? = "", city: String? = "", workplace: String? = "", profession: String? = "", zipcode: String? = "", language: String? = "", experience: String? = "", educationLevel: String? = "", organizationId: String? = "", organizationName: String? = "", accountType: String? = "", birthYear: Int? = 0, gender: String? = "", maritalStatus: String? = "", familyMembers: String? = "", childrenUnderFive: String? = "", meta: [String: String]? = nil) {
        
        self.name = name
        self.country = country
        self.regionState = regionState
        self.city = city
        self.workplace = workplace
        self.profession = profession
        self.zipcode = zipcode
        self.language = language
        self.experience = experience
        self.educationLevel = educationLevel
        self.organizationId = organizationId
        self.organizationName = organizationName
        self.accountType = accountType
        self.birthYear = birthYear
        self.gender = gender
        self.maritalStatus = maritalStatus
        self.familyMembers = familyMembers
        self.childrenUnderFive = childrenUnderFive
        self.meta = meta
    }
    
    // MARK: - Encoding
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(country, forKey: .country)
        try container.encodeIfPresent(regionState, forKey: .regionState)
        try container.encodeIfPresent(city, forKey: .city)
        try container.encodeIfPresent(workplace, forKey: .workplace)
        try container.encodeIfPresent(profession, forKey: .profession)
        try container.encodeIfPresent(zipcode, forKey: .zipcode)
        try container.encodeIfPresent(language, forKey: .language)
        try container.encodeIfPresent(experience, forKey: .experience)
        try container.encodeIfPresent(educationLevel, forKey: .educationLevel)
        try container.encodeIfPresent(organizationId, forKey: .organizationId)
        try container.encodeIfPresent(organizationName, forKey: .organizationName)
        try container.encodeIfPresent(accountType, forKey: .accountType)
        try container.encodeIfPresent(birthYear, forKey: .birthYear)
        try container.encodeIfPresent(gender, forKey: .gender)
        try container.encodeIfPresent(maritalStatus, forKey: .maritalStatus)
        try container.encodeIfPresent(familyMembers, forKey: .familyMembers)
        try container.encodeIfPresent(childrenUnderFive, forKey: .childrenUnderFive)
        try container.encodeIfPresent(meta, forKey: .meta)
        
    }

    // MARK: - Decoding

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        country = try container.decodeIfPresent(String.self, forKey: .country)
        regionState = try container.decodeIfPresent(String.self, forKey: .regionState)
        city = try container.decodeIfPresent(String.self, forKey: .city)
        workplace = try container.decodeIfPresent(String.self, forKey: .workplace)
        profession = try container.decodeIfPresent(String.self, forKey: .profession)
        zipcode = try container.decodeIfPresent(String.self, forKey: .zipcode)
        language = try container.decodeIfPresent(String.self, forKey: .language)
        experience = try container.decodeIfPresent(String.self, forKey: .experience)
        educationLevel = try container.decodeIfPresent(String.self, forKey: .educationLevel)
        organizationId = try container.decodeIfPresent(String.self, forKey: .organizationId)
        organizationName = try container.decodeIfPresent(String.self, forKey: .organizationName)
        accountType = try container.decodeIfPresent(String.self, forKey: .accountType)
        birthYear = try container.decodeIfPresent(Int.self, forKey: .birthYear)
        gender = try container.decodeIfPresent(String.self, forKey: .gender)
        maritalStatus = try container.decodeIfPresent(String.self, forKey: .maritalStatus)
        familyMembers = try container.decodeIfPresent(String.self, forKey: .familyMembers)
        childrenUnderFive = try container.decodeIfPresent(String.self, forKey: .childrenUnderFive)
        meta = try container.decodeIfPresent([String: String].self, forKey: .meta)
    }
}

extension UserCatalogModel {
    func toInternalUserCatalogModel() async -> InternalUserCatalogModel {
        
        
        // Get notification permission
        let isEnabled = await CFNotificationController.shared.checkNotificationsEnabled()
        let notifPermission = isEnabled ? "granted" : "denied"
        
        return InternalUserCatalogModel(
            name: self.name,
            country: self.country,
            regionState: self.regionState,
            city: self.city,
            workplace: self.workplace,
            profession: self.profession,
            zipcode: self.zipcode,
            language: self.language,
            experience: self.experience,
            educationLevel: self.educationLevel,
            organizationId: self.organizationId,
            organizationName: self.organizationName,
            timezone: CoreConstants.shared.getUserTimeZone(),
            accountType: self.accountType,
            birthYear: self.birthYear,
            gender: self.gender,
            maritalStatus: self.maritalStatus,
            familyMembers: self.familyMembers,
            childrenUnderFive: self.childrenUnderFive,
            notificationPermission: notifPermission,
            meta: self.meta
        )
    }
}


