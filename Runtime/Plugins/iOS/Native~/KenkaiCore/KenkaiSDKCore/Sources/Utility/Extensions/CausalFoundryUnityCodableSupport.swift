//
//  CausalFoundryUnityCodableSupport.swift
//
//  Independently implemented for Causal Foundry Unity packaging.
//  SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

extension KeyedDecodingContainer {
    func decodeIfPresent(
        _ type: [String: Any].Type,
        forKey key: Key
    ) throws -> [String: Any]? {
        _ = type

        guard contains(key), try !decodeNil(forKey: key) else {
            return nil
        }

        let value = try decode(_CFJSONValue.self, forKey: key)
        guard case let .object(object) = value else {
            throw DecodingError.typeMismatch(
                [String: Any].self,
                DecodingError.Context(
                    codingPath: codingPath + [key],
                    debugDescription: "Expected a JSON object."
                )
            )
        }

        return object.mapValues { $0.foundationValue }
    }
}

extension KeyedEncodingContainer {
    mutating func encodeIfPresent(
        _ value: [String: Any]?,
        forKey key: Key
    ) throws {
        guard let value = value, !value.isEmpty else {
            return
        }

        let jsonValue = try _CFJSONValue(
            value,
            codingPath: codingPath + [key]
        )
        try encode(jsonValue, forKey: key)
    }
}

extension Encodable {
    var dictionary: [String: Any]? {
        guard
            let data = try? JSONEncoder().encode(self),
            let object = try? JSONSerialization.jsonObject(with: data, options: []),
            let dictionary = object as? [String: Any]
        else {
            return nil
        }

        return dictionary
    }

    func serializeToFlatMap() -> [String: Any] {
        guard let dictionary = dictionary else {
            return [:]
        }

        return _cfFlatten(dictionary)
    }

    func serializeToFlatMapString() -> [String: String] {
        var result: [String: String] = [:]

        for (key, value) in serializeToFlatMap() {
            if let stringValue = _cfStringValue(value), !stringValue.isEmpty {
                result[key] = stringValue
            }
        }

        return result
    }
}

private struct _CFJSONCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        intValue = nil
    }

    init?(intValue: Int) {
        stringValue = String(intValue)
        self.intValue = intValue
    }
}

private indirect enum _CFJSONValue: Codable {
    case null
    case bool(Bool)
    case signedInteger(Int64)
    case unsignedInteger(UInt64)
    case double(Double)
    case string(String)
    case array([_CFJSONValue])
    case object([String: _CFJSONValue])

    init(from decoder: Decoder) throws {
        let singleValueContainer = try decoder.singleValueContainer()

        if singleValueContainer.decodeNil() {
            self = .null
            return
        }
        if let value = try? singleValueContainer.decode(Bool.self) {
            self = .bool(value)
            return
        }
        if let value = try? singleValueContainer.decode(Int64.self) {
            self = .signedInteger(value)
            return
        }
        if let value = try? singleValueContainer.decode(UInt64.self) {
            self = .unsignedInteger(value)
            return
        }
        if let value = try? singleValueContainer.decode(Double.self) {
            self = .double(value)
            return
        }
        if let value = try? singleValueContainer.decode(String.self) {
            self = .string(value)
            return
        }

        if var container = try? decoder.unkeyedContainer() {
            var values: [_CFJSONValue] = []
            while !container.isAtEnd {
                values.append(try container.decode(_CFJSONValue.self))
            }
            self = .array(values)
            return
        }

        if let container = try? decoder.container(keyedBy: _CFJSONCodingKey.self) {
            var values: [String: _CFJSONValue] = [:]
            for key in container.allKeys {
                values[key.stringValue] = try container.decode(
                    _CFJSONValue.self,
                    forKey: key
                )
            }
            self = .object(values)
            return
        }

        throw DecodingError.typeMismatch(
            _CFJSONValue.self,
            DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Expected a JSON-compatible value."
            )
        )
    }

    init(_ value: Any, codingPath: [CodingKey]) throws {
        guard let unwrappedValue = _cfUnwrapOptional(value) else {
            self = .null
            return
        }

        if unwrappedValue is NSNull {
            self = .null
            return
        }
        if Swift.type(of: unwrappedValue) == Bool.self {
            self = .bool(unwrappedValue as! Bool)
            return
        }
        if let string = unwrappedValue as? String {
            self = .string(string)
            return
        }
        if let number = unwrappedValue as? NSNumber,
           CFGetTypeID(number) == CFBooleanGetTypeID() {
            self = .bool(number.boolValue)
            return
        }

        if let number = _cfNativeNumber(unwrappedValue) {
            self = try number.jsonValue(codingPath: codingPath, originalValue: unwrappedValue)
            return
        }

        if let array = unwrappedValue as? [Any] {
            var values: [_CFJSONValue] = []
            values.reserveCapacity(array.count)
            for (index, element) in array.enumerated() {
                let indexKey = _CFJSONCodingKey(intValue: index)!
                values.append(try _CFJSONValue(
                    element,
                    codingPath: codingPath + [indexKey]
                ))
            }
            self = .array(values)
            return
        }

        if let object = unwrappedValue as? [String: Any] {
            var values: [String: _CFJSONValue] = [:]
            for (key, element) in object {
                let codingKey = _CFJSONCodingKey(stringValue: key)!
                values[key] = try _CFJSONValue(
                    element,
                    codingPath: codingPath + [codingKey]
                )
            }
            self = .object(values)
            return
        }

        throw EncodingError.invalidValue(
            unwrappedValue,
            EncodingError.Context(
                codingPath: codingPath,
                debugDescription: "Only JSON-compatible values can be encoded."
            )
        )
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case .null:
            var container = encoder.singleValueContainer()
            try container.encodeNil()
        case let .bool(value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case let .signedInteger(value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case let .unsignedInteger(value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case let .double(value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case let .string(value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case let .array(values):
            var container = encoder.unkeyedContainer()
            for value in values {
                try container.encode(value)
            }
        case let .object(values):
            var container = encoder.container(keyedBy: _CFJSONCodingKey.self)
            for key in values.keys.sorted() {
                let codingKey = _CFJSONCodingKey(stringValue: key)!
                try container.encode(values[key]!, forKey: codingKey)
            }
        }
    }

    var foundationValue: Any {
        switch self {
        case .null:
            return NSNull()
        case let .bool(value):
            return value
        case let .signedInteger(value):
            if value >= Int64(Int.min), value <= Int64(Int.max) {
                return Int(value)
            }
            return value
        case let .unsignedInteger(value):
            if value <= UInt64(Int.max) {
                return Int(value)
            }
            return value
        case let .double(value):
            return value
        case let .string(value):
            return value
        case let .array(values):
            return values.map { $0.foundationValue }
        case let .object(values):
            return values.mapValues { $0.foundationValue }
        }
    }
}

private enum _CFNumber {
    case signed(Int64)
    case unsigned(UInt64)
    case floating(Double)

    func jsonValue(
        codingPath: [CodingKey],
        originalValue: Any
    ) throws -> _CFJSONValue {
        switch self {
        case let .signed(value):
            return .signedInteger(value)
        case let .unsigned(value):
            return .unsignedInteger(value)
        case let .floating(value):
            guard value.isFinite else {
                throw EncodingError.invalidValue(
                    originalValue,
                    EncodingError.Context(
                        codingPath: codingPath,
                        debugDescription: "Non-finite numbers are not valid JSON."
                    )
                )
            }
            return .double(value)
        }
    }
}

private func _cfNativeNumber(_ value: Any) -> _CFNumber? {
    switch Swift.type(of: value) {
    case is Int.Type:
        return .signed(Int64(value as! Int))
    case is Int8.Type:
        return .signed(Int64(value as! Int8))
    case is Int16.Type:
        return .signed(Int64(value as! Int16))
    case is Int32.Type:
        return .signed(Int64(value as! Int32))
    case is Int64.Type:
        return .signed(value as! Int64)
    case is UInt.Type:
        return .unsigned(UInt64(value as! UInt))
    case is UInt8.Type:
        return .unsigned(UInt64(value as! UInt8))
    case is UInt16.Type:
        return .unsigned(UInt64(value as! UInt16))
    case is UInt32.Type:
        return .unsigned(UInt64(value as! UInt32))
    case is UInt64.Type:
        return .unsigned(value as! UInt64)
    case is Float.Type:
        return .floating(Double(value as! Float))
    case is Double.Type:
        return .floating(value as! Double)
    case is CGFloat.Type:
        return .floating(Double(value as! CGFloat))
    default:
        break
    }

    guard let number = value as? NSNumber else {
        return nil
    }
    if CFGetTypeID(number) == CFBooleanGetTypeID() {
        return nil
    }
    if CFNumberIsFloatType(number) {
        return .floating(number.doubleValue)
    }

    let typeCode = String(cString: number.objCType)
    if ["C", "S", "I", "L", "Q"].contains(typeCode) {
        return .unsigned(number.uint64Value)
    }
    return .signed(number.int64Value)
}

private func _cfUnwrapOptional(_ value: Any) -> Any? {
    let mirror = Mirror(reflecting: value)
    guard mirror.displayStyle == .optional else {
        return value
    }
    guard let wrappedValue = mirror.children.first?.value else {
        return nil
    }
    return _cfUnwrapOptional(wrappedValue)
}

private func _cfFlatten(_ object: [String: Any]) -> [String: Any] {
    var result: [String: Any] = [:]

    // Nested objects are promoted first so an explicit value at the current
    // level wins if flattening creates the same key.
    for key in object.keys.sorted() {
        guard let nestedObject = object[key] as? [String: Any] else {
            continue
        }
        for (nestedKey, nestedValue) in _cfFlatten(nestedObject)
            where result[nestedKey] == nil {
            result[nestedKey] = nestedValue
        }
    }

    for key in object.keys.sorted() {
        guard let value = object[key], !(value is [String: Any]) else {
            continue
        }
        guard let flatValue = _cfFlatValue(value) else {
            continue
        }
        result[key.toSnakeCase()] = flatValue
    }

    return result
}

private func _cfFlatValue(_ value: Any) -> Any? {
    guard let unwrappedValue = _cfUnwrapOptional(value),
          !(unwrappedValue is NSNull) else {
        return nil
    }

    if let string = unwrappedValue as? String {
        return string.isEmpty ? nil : string
    }
    if let array = unwrappedValue as? [Any] {
        let joined = array.compactMap(_cfStringValue).joined(separator: ", ")
        return joined.isEmpty ? nil : joined
    }
    if Swift.type(of: unwrappedValue) == Bool.self {
        return unwrappedValue as! Bool
    }
    if let number = unwrappedValue as? NSNumber {
        if CFGetTypeID(number) == CFBooleanGetTypeID() {
            return number.boolValue
        }
        if CFNumberIsFloatType(number) {
            return number.doubleValue
        }
        let typeCode = String(cString: number.objCType)
        if ["C", "S", "I", "L", "Q"].contains(typeCode),
           number.uint64Value > UInt64(Int.max) {
            return number.uint64Value
        }
        return Int(number.int64Value)
    }

    return nil
}

private func _cfStringValue(_ value: Any) -> String? {
    guard let unwrappedValue = _cfUnwrapOptional(value),
          !(unwrappedValue is NSNull) else {
        return nil
    }
    if let string = unwrappedValue as? String {
        return string.isEmpty ? nil : string
    }
    if Swift.type(of: unwrappedValue) == Bool.self {
        return (unwrappedValue as! Bool) ? "true" : "false"
    }
    if let number = unwrappedValue as? NSNumber {
        if CFGetTypeID(number) == CFBooleanGetTypeID() {
            return number.boolValue ? "true" : "false"
        }
        return number.stringValue
    }
    if let array = unwrappedValue as? [Any] {
        let joined = array.compactMap(_cfStringValue).joined(separator: ", ")
        return joined.isEmpty ? nil : joined
    }
    if let object = unwrappedValue as? [String: Any],
       JSONSerialization.isValidJSONObject(object),
       let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
       let string = String(data: data, encoding: .utf8) {
        return string
    }
    return nil
}
