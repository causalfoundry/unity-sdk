

import Foundation

// MARK: - MainBody

struct MainBody: Codable {
    let userID: String
    let timezone: String
    let internalInfoObject: InternalInfoObject
    let data: [EventDataObject]

    enum CodingKeys: String, CodingKey {
        case userID = "id"
        case timezone = "tz"
        case internalInfoObject = "internal"
        case data
    }
}

struct MainCatalogBody: Codable {
    let data: [CatalogItemModel]

    enum CodingKeys: String, CodingKey {
        case data
    }
}

// MARK: - Helper functions for creating encoders and decoders

public extension JSONEncoder {
    static var new: JSONEncoder = {
        let encoder = JSONEncoder()
        if #available(iOS 10.0, OSX 10.12, tvOS 10.0, watchOS 3.0, *) {
            encoder.dateEncodingStrategy = .iso8601
        }
        return encoder
    }()
}

public extension JSONDecoder {
    static var new: JSONDecoder = {
        let decoder = JSONDecoder()
        if #available(iOS 10.0, OSX 10.12, tvOS 10.0, watchOS 3.0, *) {
            decoder.dateDecodingStrategy = .iso8601
        }
        return decoder
    }()
}
