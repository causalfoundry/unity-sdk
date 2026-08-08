//
//  CFNotificationController.swift
//
//
//  Created by kenkai on 29.11.23.
//

import Foundation
import UIKit
import UserNotifications

public final class CFNotificationController: NSObject {
    public static let shared = CFNotificationController()

    private let center = UNUserNotificationCenter.current()
    private weak var forwardedDelegate: UNUserNotificationCenterDelegate?

    private let userInfoKey = "object"
    private let options: UNNotificationPresentationOptions = [.alert, .badge, .sound]

    /// Installs Kenkai for notification delivery while retaining a delegate already owned by the
    /// host. The host delegate remains responsible for retaining itself, matching Apple's contract.
    public func installAsDelegate() {
        if center.delegate === self {
            return
        }

        forwardedDelegate = center.delegate
        center.delegate = self
    }

    public func request(completionHandler: @escaping (Bool, Error?) -> Void) {
        installAsDelegate()
        center.requestAuthorization(options: [.alert, .badge, .sound], completionHandler: completionHandler)
    }

    /*
     public func handle(launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
         guard let notification = launchOptions?[UIApplication.LaunchOptionsKey.localNotification] as? UILocalNotification,
               let data = notification.userInfo?["object"] as? Data,
               let object = data.toObject() else { return }
         track(object: object, response: .shown)
     }
     */

    func triggerActionNotification(object: Nudge) {
        if #available(iOS 13.0, *) {
            Task {
                let settings = await checkNotificationsEnabled()
                if !settings {
                    track(payload: object, response: ActionRepsonse.Block, details: "")
                    return
                }
                let identifier = UUID().uuidString
                let content = UNMutableNotificationContent()
                content.title = object.content?["title"] ?? ""
                content.body = (object.content?["body"] ?? "").htmlAttributedString().with(font:UIFont.preferredFont(forTextStyle: .body)).string
                content.categoryIdentifier = "Nudge"
                if let data = object.toData() {
                    content.userInfo = [userInfoKey: data]
                }
                content.sound = UNNotificationSound.default
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
                let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
                try await center.add(request)
                
            }
        }
    }
    
    func checkNotificationsEnabled() async -> Bool {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus == .authorized
    }
    
    func track(payload: Nudge?, response: ActionRepsonse, details : String = "") {
        let actionResponseObj = ActionRepsonseObject(response: response.rawValue, details: details, internalObject: payload?.internalObject)
        CFCoreEvent.shared.logIngest(eventType: .ActionResponse, logObject: actionResponseObj, isUpdateImmediately: true)
    }
    
    func trackAndOpen(object: Nudge) {
        track(payload:object, response: ActionRepsonse.Open, details: "")
        ActionOnClickObject.actionOnClickInterface?(object.attr)
    }
}

extension CFNotificationController: UNUserNotificationCenterDelegate {
    public func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        var kenkaiOptions: UNNotificationPresentationOptions = []
        if let data = notification.request.content.userInfo[userInfoKey] as? Data, let object = data.toObject() {
            track(payload:object, response: ActionRepsonse.Shown, details: "")
            kenkaiOptions = options
        }

        let selector = #selector(
            UNUserNotificationCenterDelegate.userNotificationCenter(
                _:willPresent:withCompletionHandler:))
        guard let delegate = forwardedDelegate, delegate.responds(to: selector) else {
            completionHandler(kenkaiOptions)
            return
        }

        delegate.userNotificationCenter?(
            center,
            willPresent: notification,
            withCompletionHandler: { forwardedOptions in
                completionHandler(kenkaiOptions.union(forwardedOptions))
            })
    }

    public func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        if let data = response.notification.request.content.userInfo[userInfoKey] as? Data, let object = data.toObject() {
            trackAndOpen(object: object)
        }

        let selector = #selector(
            UNUserNotificationCenterDelegate.userNotificationCenter(
                _:didReceive:withCompletionHandler:))
        guard let delegate = forwardedDelegate, delegate.responds(to: selector) else {
            completionHandler()
            return
        }

        delegate.userNotificationCenter?(
            center,
            didReceive: response,
            withCompletionHandler: completionHandler)
    }

    @available(iOS 12.0, *)
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        openSettingsFor notification: UNNotification?
    ) {
        let selector = #selector(
            UNUserNotificationCenterDelegate.userNotificationCenter(
                _:openSettingsFor:))
        guard let delegate = forwardedDelegate, delegate.responds(to: selector) else {
            return
        }

        delegate.userNotificationCenter?(center, openSettingsFor: notification)
    }
}

private extension Data {
    func toObject() -> Nudge? {
        let decoder = JSONDecoder.new
        return try? decoder.decode(Nudge.self, from: self)
    }
}
