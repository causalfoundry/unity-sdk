//
//  Array.swift
//  KenkaiSDK
//
//  Created by MOIZ HASSAN KHAN on 5/11/24.
//
extension Array where Element: Hashable {
    public func removingDuplicates() -> [Element] {
        var addedDict = [Element: Bool]()
return filter {
            addedDict.updateValue(true, forKey: $0) == nil
        }
    }
    mutating func removeDuplicates() {
        self = self.removingDuplicates()
    }
}
