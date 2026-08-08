//
//  MMKVHelper+Core.swift
//
//
//  Created by khushbu on 08/11/23.
//

import Foundation

public extension MMKVHelper {
    func getCoreCatalogTypeData(newData: Data, oldData: Data, subject: CatalogSubject) -> Data? {
        var newUpdatedData: Data?
        do {
            let decoder = JSONDecoder.new
            if subject == .user {
                var catalogTableData = try decoder.decode([InternalUserCatalogModel].self, from: oldData)
                let catalogNewData = try decoder.decode([InternalUserCatalogModel].self, from: newData)
//                catalogTableData.removeAll(where: { $0.userId == catalogNewData.first?.userId })
                catalogTableData.append(catalogNewData.first!)
                newUpdatedData = catalogTableData.toData()
            } else if subject == .site {
                var catalogTableData = try decoder.decode([SiteCatalogModel].self, from: oldData)
                let catalogNewData = try decoder.decode([SiteCatalogModel].self, from: newData)
//                catalogTableData.removeAll(where: { $0.siteId == catalogNewData.first?.siteId })
                catalogTableData.append(catalogNewData.first!)
                newUpdatedData = catalogTableData.toData()
            } else if subject == .media {
                var catalogTableData = try decoder.decode([MediaCatalogModel].self, from: oldData)
                let catalogNewData = try decoder.decode([MediaCatalogModel].self, from: newData)
//                catalogTableData.removeAll(where: { $0.mediaId == catalogNewData.first?.mediaId })
                catalogTableData.append(catalogNewData.first!)
                newUpdatedData = catalogTableData.toData()
            }
        } catch {
            MMKVHelper.shared.deleteCatalogData()
            print("Error decoding data into Person: \(error)")
        }
        return newUpdatedData
    }
}
