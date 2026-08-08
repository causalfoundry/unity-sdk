//
//  DateExtension.swift
//
//
//  Created by khushbu on 21/09/23.
//

import Foundation

extension Date {
    func convertMillisToTimeString() -> String {
        var returnDate: String? = ""
        let dateFMT = DateFormatter()
        dateFMT.locale = Locale(identifier: "en_US_POSIX")
        dateFMT.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
        returnDate = dateFMT.string(from: self)
        return returnDate!
    }
}
