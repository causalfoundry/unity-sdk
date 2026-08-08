//
//  RateObject.swift
//
//
//  Created by khushbu on 10/10/23.
//

import Foundation

public struct RateObject: Codable {
    let rateValue: Float
    let type: String
    let subjectId: String
    let meta: Encodable?

    enum CodingKeys: String, CodingKey {
        case rateValue = "rate_value"
        case type
        case subjectId = "subject_id"
        case meta
    }

    public init(rateValue: Float, type: RateType, subjectId: String, meta: Encodable? = nil) {
        self.rateValue = rateValue
        self.type = type.rawValue
        self.subjectId = subjectId
        self.meta = meta
    }

    // MARK: - Encoding

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(rateValue, forKey: .rateValue)
        try container.encode(type, forKey: .type)
        try container.encode(subjectId, forKey: .subjectId)
        if let metaData = meta {
            try container.encode(metaData, forKey: .meta)
        }
    }

    // MARK: - Decoding

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        rateValue = try container.decode(Float.self, forKey: .rateValue)
        type = try container.decode(String.self, forKey: .type)
        subjectId = try container.decode(String.self, forKey: .subjectId)
        if let metaData = try container.decodeIfPresent(Data.self, forKey: .meta) {
            meta = try? (JSONSerialization.jsonObject(with: metaData, options: .allowFragments) as! any Encodable)
        } else {
            meta = nil
        }
    }
}
