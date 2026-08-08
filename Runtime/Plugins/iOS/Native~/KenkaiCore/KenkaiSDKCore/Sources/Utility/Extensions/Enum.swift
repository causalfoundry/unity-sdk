//
//  Enum.swift
//
//
//  Created by khushbu on 05/10/23.
//

import Foundation

extension RawRepresentable where RawValue: CaseIterable {
    static var allRawValues: [RawValue] {
        return RawValue.allCases as! [RawValue]
    }
}
