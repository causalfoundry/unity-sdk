//
//  IdentityObject.swift
//
//
//  Created by moizhassankh on 29/08/24.
//

import Foundation

public struct IdentifyObject: Codable {
    var userId: String?
    var action: String
    var referralCode: String
    var blockedReason: String?
    var blockedRemarks: String?
    var meta: Encodable?

    public init(userId: String, action: IdentifyAction, referralCode: String = "", blockedReason: String? = nil, blockedRemarks: String? = nil, meta: Encodable? = nil) {
        self.userId = userId
        self.action = action.rawValue
        self.referralCode = referralCode
        self.blockedReason = blockedReason
        self.blockedRemarks = blockedRemarks
        self.meta = meta
    }

    enum CodingKeys: String, CodingKey {
        case action
        case referralCode = "referral_code"
        case blockedReason = "reason"
        case blockedRemarks = "remarks"
        case meta
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        action = try values.decode(String.self, forKey: .action)
        referralCode = try values.decode(String.self, forKey: .referralCode)
        blockedReason = try values.decode(String.self, forKey: .blockedReason)
        blockedRemarks = try values.decode(String.self, forKey: .blockedRemarks)
        if let meatData = try? values.decodeIfPresent(Data.self, forKey: .meta) {
            meta = try? (JSONSerialization.jsonObject(with: meatData, options: .allowFragments) as! any Encodable)
        } else {
            meta = nil
        }
    }

    // MARK: Encodable

    public func encode(to encoder: Encoder) throws {
        var baseContainer = encoder.container(keyedBy: CodingKeys.self)
        try baseContainer.encode(action, forKey: .action)
        try baseContainer.encode(referralCode, forKey: .referralCode)
        try baseContainer.encode(blockedReason, forKey: .blockedReason)
        try baseContainer.encode(blockedRemarks, forKey: .blockedRemarks)
        if let meta_Data = meta {
            try baseContainer.encode(meta_Data, forKey: .meta)
        }
    }
}
