//
//  APIConstants.swift
//
//
//  Created by khushbu on 25/09/23.
//

import Foundation

enum APIConstants {
    static let trackEvent = "\(CoreConstants.shared.apiUrl)ingest/events"
    static let updateCatalog = "\(CoreConstants.shared.apiUrl)ingest/dimensions"
    static let fetchAction = "\(CoreConstants.shared.apiUrl)action/sdk/pull"
}
