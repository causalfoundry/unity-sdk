//
//  BackendNudgeMainObject.swift
//
//
//  Created by MOIZ HASSAN KHAN on 22/01/25.
//

import Foundation

// MARK: - BackendNudgeMainObject


public struct ActionRequestObject: Codable {
  let user_id: String // ref provided in the nudge fetch API.
  let type: String // open, shown, error, block
  let render_method: String // reason for error
  let delivery_mode: String
  let attr: [String: String]?
  
    init(userId: String, actionType: String, renderMethod: String, deliveryMode: String, attr: [String: String]? = nil) {
    self.user_id = userId
    self.type = actionType
    self.render_method = renderMethod
    self.delivery_mode = deliveryMode
    self.attr = attr
  }
}


public struct ActionAPIResponse:Codable {
  let data: [NudgeResponseItem]? // ref provided in the nudge fetch API.
}


public struct NudgeResponseItem: Codable, Equatable, Hashable {
  let payload: Nudge?
  let error: String?
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(payload?.ref) // or some unique identifier of Nudge
    }

    public static func == (lhs: NudgeResponseItem, rhs: NudgeResponseItem) -> Bool {
        return lhs.payload?.ref == rhs.payload?.ref
    }
    
}

struct Nudge: Codable {
    let type: String
    let render_method: String
    let content: [String: String]?
    let attr: [String: String]?
    let internalObject: [String: CodableValue]?

    var ref: String? {
        guard let internalObject = internalObject else { return nil }
        if case let .string(outputId)? = internalObject["output_id"], !outputId.isEmpty { return outputId }
        if case let .string(ref)? = internalObject["ref_time"] { return ref }
        return nil
    }

    var isExpired: Bool {
        guard let internalObject = internalObject,
              let value = internalObject["expired_at"],
              case let .string(stringValue) = value else { return false }

        if stringValue.isEmpty || stringValue == "0001-01-01T00:00:00Z" { return false }
        if let date = ISO8601DateFormatter().date(from: stringValue) {
            return Date() > date
        }
        return false
    }

    enum CodingKeys: String, CodingKey {
        case type, render_method, content, attr
        case internalObject = "internal"
    }
}

extension Nudge: Equatable {
    static func == (lhs: Nudge, rhs: Nudge) -> Bool {
        return lhs.type == rhs.type &&
               lhs.render_method == rhs.render_method &&
               lhs.content == rhs.content &&
               lhs.attr == rhs.attr &&
               lhs.internalObject?.jsonData == rhs.internalObject?.jsonData
    }
}
