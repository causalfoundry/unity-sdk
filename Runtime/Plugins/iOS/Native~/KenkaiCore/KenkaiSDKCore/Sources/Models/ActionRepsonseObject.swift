//
//  NudgeRepsonseObject.swift
//
//
//  Created by MOIZ HASSAN KHAN on 22/01/25.
//

import Foundation


struct ActionRepsonseObject: Codable {

  let response: String
  let details: String
  let internalObject: [String: CodableValue]?

  enum CodingKeys: String, CodingKey {
      case response, details
      case internalObject = "internal"
  }
  
  
}


enum CodableValue: Codable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case dictionary([String: CodableValue])
    case array([CodableValue])
    case null

  init(from decoder: Decoder) throws {
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

    func encode(to encoder: Encoder) throws {
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

