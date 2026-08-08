//
//  IngestProtocol.swift
//
//
//  Created by khushbu on 12/09/23.
//

import Foundation
import UIKit

protocol IngestProtocol {
    func initalize(pauseSDK: Bool,
                   updateImmediately: Bool)

    func updateUserId(appUserId: String)

    func updateCatalogItem(subject: CatalogSubject,
                               subjectId: String,
                               catalogObject: Data)

    func track<T: Codable>(
                           eventName: String,
                           eventProperty: String?,
                           eventCtx: T?,
                           updateImmediately: Bool,
                           eventTime: Int64)
}
