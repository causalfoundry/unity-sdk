//
//  TrackEventObject.swift
//  KenkaiSDK
//
//  Created by MOIZ HASSAN KHAN on 12/8/25.
//

import Foundation

public struct TrackEventObject: Codable {
    var name: String
    var property: String?
    var meta: [String: Any]?

    public init(name: String, property: String? = nil, meta: [String: Any]? = nil) {
        self.name = name
        self.property = property
        self.meta = meta
    }

    enum CodingKeys: String, CodingKey {
        case name
        case property
        case meta
    }

    // MARK: Decodable
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        name = try values.decode(String.self, forKey: .name)
        property = try values.decodeIfPresent(String.self, forKey: .property)
        meta = try values.decodeIfPresent([String: Any].self, forKey: .meta)
    }

    // MARK: Encodable
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(property, forKey: .property)
        try container.encodeIfPresent(meta, forKey: .meta)
    }
}

