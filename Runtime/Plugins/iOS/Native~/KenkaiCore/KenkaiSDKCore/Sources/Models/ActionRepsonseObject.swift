//
//  NudgeRepsonseObject.swift
//
//
//  Created by MOIZ HASSAN KHAN on 22/01/25.
//

import Foundation


/// The `ActionResponse` event body: how the user responded to an action. Pass `payload.internalObject`
/// from the fetched action so the response is attributed to it, or use `CFCoreEvent.logActionResponse`.
public struct ActionRepsonseObject: Codable {

  public let response: String
  public let details: String
  public let internalObject: [String: CodableValue]?

  public init(response: ActionRepsonse, details: String = "", internalObject: [String: CodableValue]? = nil) {
      self.response = response.rawValue
      self.details = details
      self.internalObject = internalObject
  }

  enum CodingKeys: String, CodingKey {
      case response, details
      case internalObject = "internal"
  }
  
  
}


/// A JSON value, used for the `internal` part of an action that the SDK passes back untouched.
public enum CodableValue: Codable, Equatable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case dictionary([String: CodableValue])
    case array([CodableValue])
    case null

  public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let v = try? container.decode(String.self) {
            self = .string(v)
        } else if let v = try? container.decode(Int.self) {
            self = .int(v)
        } else if let v = try? container.decode(Double.self) {
            self = .double(v)
        } else if let v = try? container.decode(Bool.self) {
            self = .bool(v)
        } else if let v = try? container.decode([String: CodableValue].self) {
            self = .dictionary(v)
        } else if let v = try? container.decode([CodableValue].self) {
            self = .array(v)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported type"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let v): try container.encode(v)
        case .int(let v): try container.encode(v)
        case .double(let v): try container.encode(v)
        case .bool(let v): try container.encode(v)
        case .dictionary(let v): try container.encode(v)
        case .array(let v): try container.encode(v)
        case .null: try container.encodeNil()
        }
    }
}
