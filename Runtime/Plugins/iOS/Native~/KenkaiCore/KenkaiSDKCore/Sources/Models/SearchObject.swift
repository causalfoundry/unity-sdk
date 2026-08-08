//
//  SearchObject.swift
//
//
//  Created by khushbu on 16/10/23.
//

import Foundation

public struct SearchObject: Codable {
    var query: String
    var searchModule: String
    var resultsList: [String]
    var filter: [String: Any]?
    var page: Int
    var meta: Encodable?

    public init(
         query: String,
         searchModule: ModuleType,
         resultsList: [String] = [],
         filter: [String: Any]? = nil,
         page: Int = 1,
         meta: Encodable? = nil)
    {
        self.query = query
        self.searchModule = searchModule.rawValue
        self.resultsList = resultsList
        self.filter = filter
        self.page = page
        self.meta = meta
    }

    private enum CodingKeys: String, CodingKey {
        case query
        case searchModule = "module"
        case resultsList = "results_list"
        case filter
        case page
        case meta
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        searchModule = try values.decode(String.self, forKey: .searchModule)
        query = try values.decode(String.self, forKey: .query)
        page = try values.decode(Int.self, forKey: .page)
        resultsList = try values.decode([String].self, forKey: .resultsList)
        filter = try values.decodeIfPresent([String: Any].self, forKey: .filter)
        
        if let metaData = try? values.decodeIfPresent(Data.self, forKey: .meta) {
            meta = try? (JSONSerialization.jsonObject(with: metaData, options: .allowFragments) as! any Encodable)
        } else {
            meta = nil
        }
    }

    // MARK: Encodable

    public func encode(to encoder: Encoder) throws {
        var baseContainer = encoder.container(keyedBy: CodingKeys.self)
        
        try baseContainer.encode(query, forKey: .query)
        try baseContainer.encode(searchModule, forKey: .searchModule)
        try baseContainer.encode(page, forKey: .page)
        try baseContainer.encode(resultsList, forKey: .resultsList)
        try baseContainer.encodeIfPresent(filter, forKey: .filter)
        if let metaData = meta {
            try baseContainer.encode(metaData, forKey: .meta)
        }
    }
}
