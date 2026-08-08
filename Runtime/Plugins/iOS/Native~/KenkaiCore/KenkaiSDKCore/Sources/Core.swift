// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import UIKit

public class CFLog {
    var appSdkKey: String = ""
    var showInAppBudge: Bool = true
    var updateImmediately: Bool = true
    var pauseSDK: Bool = false

    init(appSdkKey: String, showInAppBudge: Bool, updateImmediately: Bool, pauseSDK: Bool) {
        self.appSdkKey = appSdkKey
        self.showInAppBudge = showInAppBudge
        self.updateImmediately = updateImmediately
        self.pauseSDK = pauseSDK
    }
}

public class CFLogBuilder {
    var appSdkKey: String = ""
    var autoShowInAppMessage: Bool = true
    var updateImmediately: Bool = true
    var pauseSDK: Bool = false

    public init() {}
    /**
     * Using this will set the SDK on pause that it will not log any event and will not listen
     * for the actions but FCM based actions will still work base on the device token status.
     * DEFAULT value is FALSE
     */
    @discardableResult
    public func setPauseSDK(pauseSDK: Bool) -> CFLogBuilder {
        self.pauseSDK = pauseSDK
        return self
    }

    /**
     * Using this will set the SDK key for the successful initialisation. You can either set
     * the API key from info.plist or using this endpoint. SDK key can be obtained from
     * the CF platform.
     */
    @discardableResult
    public func setSdkKey(sdkKey: String) -> CFLogBuilder {
        self.appSdkKey = sdkKey
        return self
    }
    
    @discardableResult
    public func setUsageForReactNative() -> CFLogBuilder {
        CoreConstants.shared.SDKVersion = "rn/"+CoreConstants.shared.SDKVersion
        return self
    }

    /**
     * Using this will disable the SDK debug mode. Using this will stop the SDK from throwing
     * any exception which can result in app crash. By default it is recommended to not use
     * this as then you can validate all the values are correct or not. Debug mode is enabled
     * by default.
     */

    @discardableResult
    public func disableDebugMode() -> CFLogBuilder {
        CoreConstants.shared.isDebugMode = false
        return self
    }

    /**
     * Using this will disable the SDK Auto Page track and you have to include the page
     * event at your own based on your navigation graph pr page/activity change logic.
     * Auto Page Track mode is enabled by default.
     */
    @discardableResult
    public func disableAutoPageTrack() -> CFLogBuilder {
        CoreConstants.shared.allowAutoPageTrack = false
        return self
    }

    /**
     * SDK will not log events until the user is logged in, and once logged in, it will
     * associate those events to the logged in user id. Default is set to false. enabling
     * this flag, will send the events data regardless of the login state of the user.
     * In such cases, the device Id will be used as the userId
     */
    @discardableResult
    public func allowAnonymousUsers(allowed: Bool = true) -> CFLogBuilder {
        CoreConstants.shared.isAnonymousUserAllowed = allowed
        return self
    }

    /**
     * setAppLevelContentBlock is used to specify the type of module the app is used for.
     * content block can be in any modules i.e. core, e-commerce, e-learning, ...
     * SDK provides enum ContentBlock to log the module, you can also use string function as
     * well in order to log the content block. Below is the function for the usage of enum type
     * function.
     *
     * NOTE that this will only update for the values in the core block and not for the rest.
     */
    @discardableResult
    public func setAppLevelContentBlock(contentBlock: ContentBlock) -> CFLogBuilder {
        CoreConstants.shared.contentBlock = contentBlock
        return self
    }

    /**
     * setAppLevelContentBlock is used to specify the type of module the app is used for.
     * content block can be in any modules i.e. core, e-commerce, e-learning, ...
     * SDK provides enum ContentBlock to log the module, you can also use string function as
     * well in order to log the content block. Below is the function for the usage of string type
     * function. Remember to note that you need to use the same enum types as provided by the
     * enums or else the events will be discarded.
     *
     * NOTE that this will only update for the values in the core block and not for the rest.
     //         */
    //                public func setAppLevelxContentBlock(content_block: String) {
    //                    if (ContentBlock.RawValue == content_block ) {
    //                        CoreConstants.contentBlockName = content_block
    //                    } else {
    //                        ExceptionManager.throwEnumException("CFLog", ContentBlock::class.java.simpleName)
    //                    }
    //                }
    @discardableResult
    public func setAutoShowInAppMessages(showInAppMessage: Bool) -> CFLogBuilder {
        CoreConstants.shared.autoShowInAppMessage = showInAppMessage
        return self
    }

    /**
     * Using this will set the update immediately level for all of the events to be either
     * fired immediately ot after the end of the session. You can also set the
     * updateImmediately for each event.
     * DEFAULT value is FALSE
     */
    @discardableResult
    public func updateImmediately(updateImmediately: Bool) -> CFLogBuilder {
        self.updateImmediately = updateImmediately
        return self
    }

    /**
     * Set the properties for the notification elements, for push notifications for
     * ingest workflow. By default the SDK will show the notification if the API call
     * takes more then 10 seconds as recommended by google. You can use the below provided
     * properties to update the values as per your app configurations.
     *
     * `setIngestNotificationTitle` is for setting your own custom title for the
     * notification, by default SDK shows `Backing up events` in LOCALE EN
     */
    @discardableResult
    public func setIngestNotificationTitle(notificationTitle: String) -> CFLogBuilder { NotificationConstants.shared.INGEST_NOTIFICATION_TITLE = notificationTitle
        return self
    }

    /**
     * `setIngestNotificationDescription` is for setting your own custom description for the
     * notification, by default SDK shows `Please wait while we are backing
     * up events.` in LOCALE EN
     */
    @discardableResult
    public func setIngestNotificationDescription(notificationDescription: String) -> CFLogBuilder {
        NotificationConstants.shared.INGEST_NOTIFICATION_DESCRIPTION = notificationDescription
        return self
    }

    /**
     * `setIngestNotificationEnabled` is for setting the preference to show ingest
     * notification, if you want to show the notification or not. By default the SDK
     * shows the notification and this is set as true, but the SDK only shows the
     * notification if the API takes more then 10 seconds as per recommended by google.
     * You can change that to false based on your app configuration but it is not recommended.
     */
    @discardableResult
    public func setIngestNotificationEnabled(isNotificationEnabled: Bool) -> CFLogBuilder {
        NotificationConstants.shared.INGEST_NOTIFICATION_ENABLED = isNotificationEnabled
        return self
    }

    /**
     * `updateIngestNotificationShowInterval` is for setting the time interval the SDK
     * will wait for the API to complete. By default this is set to 10 seconds as
     * recommended by google but you can change that based on your app configuration.
     * However it is not recommended to do so.
     */
    @discardableResult
    public func updateIngestNotificationShowInterval(notificationShowInterval: TimeInterval) -> CFLogBuilder {
        NotificationConstants.shared.INGEST_NOTIFICATION_INTERVAL_TIME = notificationShowInterval
        return self
    }

    /**
     * `updateInAppMessageInitialDelay` is for setting the time interval the SDK
     * will wait before showing the In App message after the app is opened. By default,
     * the SDK waits for 5 seconds (5000L). However, you can pass a value as per your app's
     * configuration.
     */
    @discardableResult
    public func updateInAppMessageInitialDelay(initialDelay: TimeInterval) -> CFLogBuilder {
        NotificationConstants.shared.IN_APP_MESSAGE_INITIAL_DELAY = initialDelay
        return self
    }

    /**
     * Using this will validate the endpoints provided and initialise the SDK
     */
    public func build() {
        if #available(iOS 13.0, *) {
            if(appSdkKey.isEmpty){
                ExceptionManager.throwIsRequiredException(eventType: "CFLog", elementName: "SDK KEY")
            }else {
                CoreConstants.shared.sdkKey = "Bearer \(appSdkKey)"
            }
            CFSetup().initalize(pauseSDK: pauseSDK, updateImmediately: updateImmediately)
        }
    }
}
