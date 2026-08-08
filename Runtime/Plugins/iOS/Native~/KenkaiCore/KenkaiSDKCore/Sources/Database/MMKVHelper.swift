//
//  MMKVHelper.swift
//
//
//  Created by khushbu on 10/10/23.
//

import Foundation
import MMKV
import UIKit

public class MMKVHelper {
    private enum Key: String {
        case user
        case userBackup
        case userCatalog
        case exceptionData
        case eventData
        case currency
        case actions
        case localCFDimensionsKey
    }

    private struct CatalogHelper: Codable {
        let data: Data
    }

    public static let shared = MMKVHelper()

    private let mmkv: MMKV

    public init() {
        MMKV.initialize(rootDir: nil)
        mmkv = MMKV(mmapID: "Core")!
    }
}

extension MMKVHelper {
    func readExceptionsData() -> [ExceptionDataObject] {
        let object: [ExceptionDataObject]? = read(for: Key.exceptionData.rawValue)
        return object ?? []
    }

    func writeExceptionEvents(eventArray: [ExceptionDataObject]) {
        write(eventArray, for: Key.exceptionData.rawValue)
    }
    
    func deleteExceptionEvents() {
        delete(for: Key.exceptionData.rawValue)
    }

    func writeUser(user: String?) {
        write(user, for: Key.user.rawValue)
    }

    func fetchUserID() -> String? {
        read(for: Key.user.rawValue)
    }
    
    func writeUserBackup(userId: String?) {
        write(userId, for: Key.userBackup.rawValue)
    }

    func fetchUserBackupID() -> String? {
        read(for: Key.userBackup.rawValue)
    }
    
    func deleteAllUserID() {
        delete(for: Key.userBackup.rawValue)
        delete(for: Key.userBackup.rawValue)
    }
    
    func readInjectEvents() -> [EventDataObject] {
        let object: [EventDataObject]? = read(for: Key.eventData.rawValue)
        return object ?? []
    }
    
    func writeEvents(eventsArray: [EventDataObject]) {
        write(eventsArray, for: Key.eventData.rawValue)
    }

    func deleteDataEventLogs() {
        delete(for: Key.eventData.rawValue)
    }

    func writeCatalogData(data: [CatalogItemModel]) {
        write(data, for: Key.localCFDimensionsKey.rawValue)
    }

    func readCatalogData() -> [CatalogItemModel] {
        let object: [CatalogItemModel]? = read(for: Key.localCFDimensionsKey.rawValue)
        return object ?? []
    }
    
    func deleteCatalogData() {
        delete(for: Key.localCFDimensionsKey.rawValue)
    }

    func readActions() -> [NudgeResponseItem] {
        let object: [NudgeResponseItem]? = read(for: Key.actions.rawValue)
        return object ?? []
    }

    func writeActions(objects: [NudgeResponseItem]) {
        write(objects, for: Key.actions.rawValue)
    }
    
    private func write<T: Codable>(_ object: T?, for key: String) {
        let encoder = JSONEncoder.new
        guard let data = try? encoder.encode(object) else {
            mmkv.removeValue(forKey: key)
            return
        }
        mmkv.set(data, forKey: key)
    }
    
    private func read<T: Codable>(for key: String) -> T? {
        guard let data = mmkv.data(forKey: key) else {
            return nil
        }
        let decoder = JSONDecoder.new
        return try? decoder.decode(T.self, from: data)
    }
    
    private func delete(for key: String) {
        mmkv.removeValue(forKey: key)
    }
}

public extension Encodable {
    func toData(using encoder: JSONEncoder = JSONEncoder.new) -> Data? {
        do {
            return try encoder.encode(self)
        } catch {
            print("Error encoding data: \(error)")
            return nil
        }
    }
}
