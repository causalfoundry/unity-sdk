//
//  AppObject.swift
//
//
//  Created by moizhassankh on 28/08/24.
//

import Foundation

public struct AppObject: Codable {
    var action: String
    var startTime: Int
    var meta: Encodable?

    public init(action: AppAction, startTime: Int, meta: Encodable? = nil) {
        self.action = action.rawValue
        self.startTime = startTime
        self.meta = meta
    }

    enum CodingKeys: String, CodingKey {
        case action
        case start_time
        case meta
    }
    
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        action = try values.decode(String.self, forKey: .action)
        startTime = try values.decode(Int.self, forKey: .start_time)
        if let metaData = try? values.decodeIfPresent(Data.self, forKey: .meta) {
            meta = try? (JSONSerialization.jsonObject(with: metaData, options: .allowFragments) as! any Encodable)
        } else {
            meta = nil
        }
    }

    // MARK: Encodable

    public func encode(to encoder: Encoder) throws {
        var baseContainer = encoder.container(keyedBy: CodingKeys.self)
        try baseContainer.encode(action, forKey: .action)
        try baseContainer.encode(startTime, forKey: .start_time)
        if let metaData = meta {
            try baseContainer.encode(metaData, forKey: .meta)
        }
    }
    
}
