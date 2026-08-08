//
//  MediaObject.swift
//
//
//  Created by khushbu on 09/10/23.
//

import Foundation

public struct MediaObject: Codable {
    var mediaId: String
    var mediaType: String
    var mediaAction: String
    var seekTime: Int
    var meta: Encodable?

    public init(mediaId: String, mediaType: MediaType, mediaAction: MediaAction, seekTime: Int, meta: Encodable? = nil) {
        self.mediaId = mediaId
        self.mediaType = mediaType.rawValue
        self.mediaAction = mediaAction.rawValue
        self.seekTime = seekTime
        self.meta = meta
    }

    enum CodingKeys: String, CodingKey {
        case id = "media_id"
        case type
        case action
        case seekTime = "seek_time"
        case meta
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        mediaId = try values.decode(String.self, forKey: .id)
        mediaType = try values.decode(String.self, forKey: .type)
        mediaAction = try values.decode(String.self, forKey: .action)
        seekTime = try values.decode(Int.self, forKey: .seekTime)
        if let metaData = try? values.decodeIfPresent(Data.self, forKey: .meta) {
            meta = try? (JSONSerialization.jsonObject(with: metaData, options: .allowFragments) as! any Encodable)
        } else {
            meta = nil
        }
    }

    // MARK: Encodable

    public func encode(to encoder: Encoder) throws {
        var baseContainer = encoder.container(keyedBy: CodingKeys.self)
        try baseContainer.encode(mediaId, forKey: .id)
        try baseContainer.encode(mediaType, forKey: .type)
        try baseContainer.encode(mediaAction, forKey: .action)
        try baseContainer.encode(seekTime, forKey: .seekTime)
        if let metaData = meta {
            try baseContainer.encode(metaData, forKey: .meta)
        }
    }
}
