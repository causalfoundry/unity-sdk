//
//  Dicitionary.swift
//
//
//  Created by khushbu on 25/09/23.
//

import Foundation

extension Dictionary {
    var json: String {
        let invalidJson = "Not a valid JSON"
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: self, options: .prettyPrinted)
            return String(bytes: jsonData, encoding: String.Encoding.utf8) ?? invalidJson
        } catch {
            return invalidJson
        }
    }

    func printJson() {
        print(json)
    }
}


extension Dictionary where Key == String, Value == CodableValue {
    var jsonData: Data? {
        return try? JSONSerialization.data(
            withJSONObject: mapValues { $0.toAny() },
            options: [.sortedKeys]
        )
    }
}

extension CodableValue {
    func toAny() -> Any {
        switch self {
        case .string(let v): return v
        case .int(let v): return v
        case .double(let v): return v
        case .bool(let v): return v
        case .dictionary(let d): return d.mapValues { $0.toAny() }
        case .array(let a): return a.map { $0.toAny() }
        case .null: return NSNull()
        }
    }
}
