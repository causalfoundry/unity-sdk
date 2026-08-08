//
//  CatalogAPIHandler.swift
//
//
//  Created by khushbu on 12/09/23.
//

import Foundation

public class CatalogAPIHandler {
    func updateCoreCatalogItem(catalogObject: CatalogItemModel) {
        if #available(iOS 13.0, *) {
            var prevEvent = MMKVHelper.shared.readCatalogData()
            prevEvent.append(catalogObject)
            MMKVHelper.shared.writeCatalogData(data: prevEvent)
        }
    }
    
    
    func callCatalogAPI(catalogMainObject: [CatalogItemModel], callback: @escaping (Bool) -> Void) {
        if #available(iOS 13.0, *) {
            let url = URL(string: "\(APIConstants.updateCatalog)")!
            
            
            let mainBody = MainCatalogBody(
                data: catalogMainObject
            )
            
            let dictionary = mainBody.dictionary ?? [:]
            
            if dictionary.isEmpty {
                print("No More Injest events")
                return
            }
            BackgroundRequestController.shared.request(url: url, httpMethod: .post, params: dictionary) { result in
                switch result {
                case .success:
                    callback(true)
                case .failure:
                    callback(false)
                }
            }
        }
    }
}
