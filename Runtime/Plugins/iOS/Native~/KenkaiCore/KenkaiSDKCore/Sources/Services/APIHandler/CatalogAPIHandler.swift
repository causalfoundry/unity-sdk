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
            MMKVHelper.shared.appendCatalogItem(catalogObject)
        }
    }
    
    
    func callCatalogAPI(catalogMainObject: [CatalogItemModel], callback: @escaping (Bool) -> Void) {
        if #available(iOS 13.0, *) {
            guard let url = URL(string: APIConstants.updateCatalog) else {
                callback(false)
                return
            }
            
            
            let mainBody = MainCatalogBody(
                data: catalogMainObject
            )
            
            let dictionary = mainBody.dictionary ?? [:]
            
            if dictionary.isEmpty {
                print("No More Injest events")
                callback(false)
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
