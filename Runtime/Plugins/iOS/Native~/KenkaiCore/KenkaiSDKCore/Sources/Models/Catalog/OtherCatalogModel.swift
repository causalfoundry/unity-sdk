import Foundation

public struct OtherCatalogModel: Codable {
    public var name: String
    public var meta: [String: Any]

    public init(name: String, meta: [String: Any]) {
        self.name = name
        self.meta = meta
    }

    enum CodingKeys: String, CodingKey {
        case name
        case meta
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        meta = try container.decodeIfPresent([String: Any].self, forKey: .meta) ?? [:]
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(meta, forKey: .meta)
    }
}
