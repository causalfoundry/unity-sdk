//
//  InternalInfoObject.swift
//
//
//  Created by moizhassankh on 12/08/25.
//

import Foundation

struct InternalInfoObject: Codable {
    var s_id, sdk, app_id, app_version, device_id, device_os: String

    enum CodingKeys: String, CodingKey {
        case s_id, sdk, app_id, app_version, device_id, device_os
    }
}
