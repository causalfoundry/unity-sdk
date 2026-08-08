//
//  StringExtension.swift
//
//
//  Created by khushbu on 09/10/23.
//

import Foundation

extension String {
    func isNilOREmpty() -> Bool {
        if self == "" {
            return true
        } else {
            return false
        }
    }
    
    func toSnakeCase() -> String {
        return self
            .replacingOccurrences(of: #"^[\s\p{Z}\uFEFF]+|[\s\p{Z}\uFEFF]+$"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"[\s\p{Z}\uFEFF]+"#, with: "_", options: .regularExpression)
            .lowercased()
    }
}
