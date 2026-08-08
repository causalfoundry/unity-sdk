//
//  UserCatalogModel.swift
//
//
//  Created by khushbu on 19/10/23.
//

import Foundation

public struct MediaCatalogModel: Codable, Equatable {
    var mediaName: String?
    var mediaDescription: String?
    var length: Int?
    var type: String?
    var resolution: String?
    var language: String?
    let meta: [String: String]?
    
    enum CodingKeys: String, CodingKey {
        case mediaName = "name"
        case mediaDescription = "description"
        case length = "length"
        case type
        case resolution
        case language
        case meta
    }
    

    public init(mediaName: String, mediaDescription: String? = "", length: Int? = 0, type: String, resolution: String? = "", language: String? = "", meta: [String: String]? = nil) {
        
        self.mediaName = mediaName
        self.mediaDescription = mediaDescription
        self.length = length
        self.type = type
        self.resolution = resolution
        self.language = language
        self.meta = meta
    }
    
    // MARK: - Encoding
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(mediaName, forKey: .mediaName)
        try container.encodeIfPresent(mediaDescription, forKey: .mediaDescription)
        try container.encodeIfPresent(length, forKey: .length)
        try container.encodeIfPresent(type, forKey: .type)
        try container.encodeIfPresent(resolution, forKey: .resolution)
        try container.encodeIfPresent(language, forKey: .language)
        try container.encodeIfPresent(meta, forKey: .meta)
    }

    // MARK: - Decoding

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        mediaName = try container.decodeIfPresent(String.self, forKey: .mediaName)
        mediaDescription = try container.decodeIfPresent(String.self, forKey: .mediaDescription)
        length = try container.decodeIfPresent(Int.self, forKey: .length)
        type = try container.decodeIfPresent(String.self, forKey: .type)
        resolution = try container.decodeIfPresent(String.self, forKey: .resolution)
        language = try container.decodeIfPresent(String.self, forKey: .language)
        meta = try container.decodeIfPresent([String: String].self, forKey: .meta)
    }
}
