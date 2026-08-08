//
//  UserCatalogModel.swift
//
//
//  Created by khushbu on 19/10/23.
//

import Foundation

struct CatalogItemModel: Codable, Hashable {
    var id: String
    var type: String
    var keyValues: [String: String]?
    
    enum CodingKeys: String, CodingKey {
        case id = "id"
        case type = "type"
        case keyValues = "kv"
    }
    

    init<T: Codable>(id: String, type: String, keyValues: T) {
        self.id = id
        self.type = type
        self.keyValues = keyValues.serializeToFlatMapString()
    }
    
    var isTypeOrSubjectEmpty: Bool {
        return type.isEmpty || id.isEmpty
    }
    
    // MARK: - Encoding
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(keyValues, forKey: .keyValues)
    }

    // MARK: - Decoding

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        type = try container.decode(String.self, forKey: .type)
        keyValues = try container.decode([String: String].self, forKey: .keyValues)
    }
    
    
    // Hashable conformance with props inclusion
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(type)
        
        if let keyValues = propsAsJSONData() {
            hasher.combine(keyValues)
        }
    }

    static func == (lhs: CatalogItemModel, rhs: CatalogItemModel) -> Bool {
        return lhs.id == rhs.id &&
               lhs.type == rhs.type &&
               lhs.propsAsJSONData() == rhs.propsAsJSONData()
    }

    // Convert props dictionary to JSON data for accurate comparison
    private func propsAsJSONData() -> Data? {
        guard let keyValues = keyValues else { return nil}
        return try? JSONSerialization.data(withJSONObject: keyValues, options: .sortedKeys)
    }

}
