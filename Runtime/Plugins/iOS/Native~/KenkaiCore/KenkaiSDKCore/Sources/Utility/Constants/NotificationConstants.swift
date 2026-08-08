//
//  NotificationConstants.swift
//
//
//  Created by khushbu on 12/09/23.
//

import Foundation

class NotificationConstants {
    static let shared = NotificationConstants()

    var INGEST_NOTIFICATION_TITLE: String = "Backing up events"
    var INGEST_NOTIFICATION_DESCRIPTION: String = "Please wait while we are backing up events."
    var INGEST_NOTIFICATION_ENABLED: Bool = true
    var INGEST_NOTIFICATION_INTERVAL_TIME: TimeInterval = 10 // 10 sec

    // in-app message initial delay
    var IN_APP_MESSAGE_INITIAL_DELAY: TimeInterval = 3

    // props for notification values regarding exception notification
    var EXCEPTION_NOTIFICATION_TITLE: String = "Backing up exceptions"
    var EXCEPTION_NOTIFICATION_DESCRIPTION: String = "Please wait while we are backing up exceptions."
    var EXCEPTION_NOTIFICATION_INTERVAL_TIME: TimeInterval = 10 // 10 sec
    var EXCEPTION_NOTIFICATION_ENABLED = true
}
