//
//  ChwSiteCatalogModel.swift
//
//
//  Created by MOIZ HASSAN KHAN on 05/11/24.
//

import Foundation

public struct SiteCatalogModel: Codable, Equatable {
    var name: String
    var type: String
    var country: String?
    var regionState: String?
    var city: String?
    var streetAddress: String?
    var zipcode: String?
    var level: String?
    var category: String?
    var isActive: Bool?
    var latitude: Double?
    var longitude: Double?
    var culture: String?
    var parentSiteId: String?
    var serviceList: [String]?
    let meta: [String: String]?
    
    
    public enum CodingKeys: String, CodingKey {
        case name
        case type
        case country
        case regionState = "region_state"
        case city
        case streetAddress = "street_address"
        case zipcode
        case level
        case category
        case isActive = "is_active"
        case latitude
        case longitude
        case culture
        case parentSiteId = "parent_id"
        case serviceList = "service_list"
        case meta
    }
    

    public init(name: String = "", type: String = "", country: String? = "", regionState: String? = "", city: String? = "", streetAddress: String? = "", zipcode: String? = "", level: String? = "", category: String? = "", isActive: Bool? = true, latitude: Double? = 0, longitude: Double? = 0, culture: String? = "", parentSiteId: String? = "", serviceList: [String]? = [], meta: [String: String]? = nil) {
        self.name = name
        self.type = type
        self.country = country
        self.regionState = regionState
        self.city = city
        self.streetAddress = streetAddress
        self.zipcode = zipcode
        self.level = level
        self.category = category
        self.isActive = isActive
        self.latitude = latitude
        self.longitude = longitude
        self.culture = culture
        self.parentSiteId = parentSiteId
        self.serviceList = serviceList
        self.meta = meta
    }
    
    
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(country, forKey: .country)
        try container.encodeIfPresent(regionState, forKey: .regionState)
        try container.encodeIfPresent(city, forKey: .city)
        try container.encodeIfPresent(streetAddress, forKey: .streetAddress)
        try container.encodeIfPresent(zipcode, forKey: .zipcode)
        try container.encodeIfPresent(level, forKey: .level)
        try container.encodeIfPresent(category, forKey: .category)
        try container.encodeIfPresent(isActive, forKey: .isActive)
        try container.encodeIfPresent(latitude, forKey: .latitude)
        try container.encodeIfPresent(longitude, forKey: .longitude)
        try container.encodeIfPresent(culture, forKey: .culture)
        try container.encodeIfPresent(parentSiteId, forKey: .parentSiteId)
        try container.encodeIfPresent(serviceList, forKey: .serviceList)
        try container.encodeIfPresent(meta, forKey: .meta)
        
    }

    // Decoding
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decode(String.self, forKey: .type)
        country = try container.decodeIfPresent(String.self, forKey: .country)
        regionState = try container.decodeIfPresent(String.self, forKey: .regionState)
        city = try container.decodeIfPresent(String.self, forKey: .city)
        streetAddress = try container.decodeIfPresent(String.self, forKey: .streetAddress)
        zipcode = try container.decodeIfPresent(String.self, forKey: .zipcode)
        level = try container.decodeIfPresent(String.self, forKey: .level)
        category = try container.decodeIfPresent(String.self, forKey: .category)
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive)
        latitude = try container.decodeIfPresent(Double.self, forKey: .latitude)
        longitude = try container.decodeIfPresent(Double.self, forKey: .longitude)
        culture = try container.decodeIfPresent(String.self, forKey: .culture)
        parentSiteId = try container.decodeIfPresent(String.self, forKey: .parentSiteId)
        serviceList = try container.decodeIfPresent([String].self, forKey: .serviceList)
        meta = try container.decodeIfPresent([String: String].self, forKey: .meta)
        
    }

    
}

