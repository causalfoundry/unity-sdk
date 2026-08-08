import Foundation
import UIKit
import KenkaiSDKCore

private func CFUBooleanValue(_ value: Any?) -> Bool? {
    guard let number = value as? NSNumber,
          CFGetTypeID(number) == CFBooleanGetTypeID() else {
        return nil
    }
    return number.boolValue
}

private func CFUNormalizeCatalogName(_ value: String) -> String {
    return value
        .replacingOccurrences(
            of: #"^[\s\p{Z}\uFEFF]+|[\s\p{Z}\uFEFF]+$"#,
            with: "",
            options: .regularExpression
        )
        .replacingOccurrences(
            of: #"[\s\p{Z}\uFEFF]+"#,
            with: "_",
            options: .regularExpression
        )
        .lowercased()
}

public typealias CFUResultCallback = @convention(c) (
    UInt64,
    Int32,
    UnsafePointer<CChar>?,
    UnsafePointer<CChar>?,
    UnsafePointer<CChar>?
) -> Void

public typealias CFUActionOpenedCallback = @convention(c) (UnsafePointer<CChar>?) -> Void

private struct CFUBridgeError: Error {
    let code: String
    let message: String
}

private struct CFUConfiguration: Equatable {
    let sdkKey: String
    let allowAnonymousUsers: Bool
    let updateImmediately: Bool
    let autoShowInAppMessages: Bool
    let disableAutoPageTracking: Bool
    let pauseSdk: Bool
    let enableDebugMode: Bool

    static func parse(sdkKey: String, optionsJSON: String) throws -> CFUConfiguration {
        let trimmedKey = sdkKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            throw CFUBridgeError(code: "invalid_argument", message: "The SDK key cannot be empty.")
        }

        var values: [String: Any] = [:]
        if !optionsJSON.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            guard let data = optionsJSON.data(using: .utf8) else {
                throw CFUBridgeError(code: "invalid_argument", message: "Options must be valid UTF-8 JSON.")
            }

            let object: Any
            do {
                object = try JSONSerialization.jsonObject(with: data, options: [])
            } catch {
                throw CFUBridgeError(code: "invalid_argument", message: "Options are not valid JSON: \(error.localizedDescription)")
            }

            guard let dictionary = object as? [String: Any] else {
                throw CFUBridgeError(code: "invalid_argument", message: "Options JSON must contain an object.")
            }
            values = dictionary
        }

        let disableAutoPageTracking: Bool
        if let explicitValue = try boolean(values, key: "disable_auto_page_tracking") {
            disableAutoPageTracking = explicitValue
        } else if let autoTrackPages = try boolean(values, key: "auto_track_pages") {
            disableAutoPageTracking = !autoTrackPages
        } else {
            disableAutoPageTracking = true
        }

        return CFUConfiguration(
            sdkKey: trimmedKey,
            allowAnonymousUsers: try boolean(values, key: "allow_anonymous_users") ?? true,
            updateImmediately: try boolean(values, key: "update_immediately") ?? false,
            autoShowInAppMessages: try boolean(values, key: "auto_show_in_app_messages") ?? true,
            disableAutoPageTracking: disableAutoPageTracking,
            pauseSdk: try boolean(values, key: "pause_sdk") ?? false,
            enableDebugMode: try boolean(values, key: "enable_debug_mode") ?? true
        )
    }

    private static func boolean(_ values: [String: Any], key: String) throws -> Bool? {
        guard let value = values[key] else { return nil }
        guard let boolean = CFUBooleanValue(value) else {
            throw CFUBridgeError(code: "invalid_argument", message: "Option '\(key)' must be a boolean.")
        }
        return boolean
    }
}

/// Encodes JSONSerialization values through the `Encodable` existential accepted by IdentifyObject.
private struct CFUJSONEncodable: Encodable {
    let value: Any

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        if value is NSNull {
            try container.encodeNil()
        } else if let string = value as? String {
            try container.encode(string)
        } else if let number = value as? NSNumber {
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                try container.encode(number.boolValue)
            } else {
                let type = String(cString: number.objCType)
                if type == "f" || type == "d" {
                    try container.encode(number.doubleValue)
                } else {
                    try container.encode(number.int64Value)
                }
            }
        } else if let array = value as? [Any] {
            try container.encode(array.map { CFUJSONEncodable(value: $0) })
        } else if let dictionary = value as? [String: Any] {
            try container.encode(dictionary.mapValues { CFUJSONEncodable(value: $0) })
        } else {
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(codingPath: encoder.codingPath, debugDescription: "Unsupported metadata value.")
            )
        }
    }
}

private final class CFUCompletionGate {
    private let lock = NSLock()
    private var completed = false

    func claim() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if completed { return false }
        completed = true
        return true
    }
}

private final class CFUBridgeState {
    static let shared = CFUBridgeState()

    private static let fetchTimeout: TimeInterval = 60
    private static let maximumPendingActionOpens = 32
    private static let reservedTrackNames: Set<String> = [
        "identify", "page", "app", "search", "media", "action_response", "rate",
        "module_selection", "track", "item", "delivery", "checkout", "cart",
        "cancel_checkout", "item_report", "item_request", "module", "exam", "question",
        "level", "milestone", "promo", "survey", "reward", "payment", "patient",
        "encounter", "appointment", "diagnosis", "nudge_response"
    ]

    private let lock = NSLock()
    private var resultCallback: CFUResultCallback?
    private var actionOpenedCallback: CFUActionOpenedCallback?
    private var pendingActionOpens: [String] = []
    private var actionHookInstalled = false
    private var configuration: CFUConfiguration?

    private init() {}

    func registerCallbacks(result: CFUResultCallback?, actionOpened: CFUActionOpenedCallback?) {
        lock.lock()
        resultCallback = result
        actionOpenedCallback = actionOpened
        let pending = actionOpened == nil ? [] : pendingActionOpens
        if actionOpened != nil {
            pendingActionOpens.removeAll()
        }
        lock.unlock()

        installActionHook()

        guard let callback = actionOpened, !pending.isEmpty else { return }
        runOnMain {
            for json in pending {
                json.withCString { callback($0) }
            }
        }
    }

    func earlyBootstrap() {
        installActionHook()

        let info = Bundle.main.infoDictionary ?? [:]
        guard (info["CausalFoundryUnityAutoInitialize"] as? Bool) == true else { return }
        let sdkKey = info["CausalFoundryUnitySDKKey"] as? String ?? ""
        let optionsJSON = info["CausalFoundryUnityOptionsJSON"] as? String ?? "{}"
        initialize(requestID: 0, sdkKey: sdkKey, optionsJSON: optionsJSON)
    }

    func installNotificationDelegate() {
        runOnMain {
            CFNotificationController.shared.installAsDelegate()
        }
    }

    func initialize(requestID: UInt64, sdkKey: String, optionsJSON: String) {
        runOnMain {
            guard #available(iOS 13.0, *) else {
                self.finishFailure(requestID, code: "unsupported_platform", message: "Causal Foundry Core requires iOS 13 or newer.")
                return
            }

            let requested: CFUConfiguration
            do {
                requested = try CFUConfiguration.parse(sdkKey: sdkKey, optionsJSON: optionsJSON)
            } catch let error as CFUBridgeError {
                self.finishFailure(requestID, code: error.code, message: error.message)
                return
            } catch {
                self.finishFailure(requestID, code: "invalid_argument", message: error.localizedDescription)
                return
            }

            self.lock.lock()
            let existing = self.configuration
            self.lock.unlock()

            if let existing = existing {
                if existing == requested {
                    self.finishSuccess(requestID)
                } else {
                    self.finishFailure(
                        requestID,
                        code: "already_initialized",
                        message: "The native iOS SDK was already initialized with different settings."
                    )
                }
                return
            }

            self.installActionHook()
            Kenkai.shared.configure()

            var builder = CFLogBuilder()
                .setSdkKey(sdkKey: requested.sdkKey)
                .allowAnonymousUsers(allowed: requested.allowAnonymousUsers)
                .updateImmediately(updateImmediately: requested.updateImmediately)
                .setAutoShowInAppMessages(showInAppMessage: requested.autoShowInAppMessages)
                .setPauseSDK(pauseSDK: requested.pauseSdk)

            if requested.disableAutoPageTracking {
                builder = builder.disableAutoPageTrack()
            }
            if !requested.enableDebugMode {
                builder = builder.disableDebugMode()
            }

            builder.build()

            self.lock.lock()
            self.configuration = requested
            self.lock.unlock()
            self.finishSuccess(requestID)
        }
    }

    func identify(requestID: UInt64, userID: String, action: String, attributesJSON: String) {
        runOnMain {
            guard self.requireInitialized(requestID) else { return }

            let trimmedUserID = userID.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedUserID.isEmpty else {
                self.finishFailure(requestID, code: "invalid_argument", message: "The user ID cannot be empty.")
                return
            }

            let identifyAction: IdentifyAction
            switch action.lowercased() {
            case "register": identifyAction = .Register
            case "login": identifyAction = .Login
            case "logout": identifyAction = .Logout
            case "blocked": identifyAction = .Blocked
            case "unblocked": identifyAction = .Unblocked
            default:
                self.finishFailure(requestID, code: "invalid_argument", message: "Unsupported identity action '\(action)'.")
                return
            }

            let attributes: [String: Any]
            do {
                attributes = try self.parseObjectJSON(attributesJSON, argumentName: "Identify attributes")
            } catch let error as CFUBridgeError {
                self.finishFailure(requestID, code: error.code, message: error.message)
                return
            } catch {
                self.finishFailure(requestID, code: "invalid_argument", message: error.localizedDescription)
                return
            }

            let blockedReason = attributes["blocked_reason"] as? String
            if (identifyAction == .Blocked || identifyAction == .Unblocked) &&
                (blockedReason?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) {
                self.finishFailure(
                    requestID,
                    code: "invalid_argument",
                    message: "blocked_reason is required for blocked and unblocked identity actions."
                )
                return
            }

            let meta = attributes["meta"].map { CFUJSONEncodable(value: $0) }
            let object = IdentifyObject(
                userId: trimmedUserID,
                action: identifyAction,
                referralCode: attributes["referral_code"] as? String ?? "",
                blockedReason: blockedReason,
                blockedRemarks: attributes["blocked_remarks"] as? String,
                meta: meta
            )

            CFCoreEvent.shared.logIngest(
                eventType: .Identify,
                logObject: object,
                isUpdateImmediately: CFUBooleanValue(attributes["immediate"]),
                eventTime: (attributes["timestamp_ms"] as? NSNumber)?.int64Value
            )
            self.finishSuccess(requestID)
        }
    }

    func track(requestID: UInt64, eventName: String, propertiesJSON: String) {
        runOnMain {
            guard self.requireInitialized(requestID) else { return }

            let normalizedName = eventName
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: " ", with: "_")
                .lowercased()
            guard !normalizedName.isEmpty else {
                self.finishFailure(requestID, code: "invalid_argument", message: "The event name cannot be empty.")
                return
            }
            guard !CFUBridgeState.reservedTrackNames.contains(normalizedName) else {
                self.finishFailure(
                    requestID,
                    code: "invalid_argument",
                    message: "The event name '\(eventName)' is reserved by the native SDK."
                )
                return
            }

            let properties: [String: Any]
            do {
                properties = try self.parseObjectJSON(propertiesJSON, argumentName: "Track properties")
            } catch let error as CFUBridgeError {
                self.finishFailure(requestID, code: error.code, message: error.message)
                return
            } catch {
                self.finishFailure(requestID, code: "invalid_argument", message: error.localizedDescription)
                return
            }

            if let property = properties["property"], !(property is String) {
                self.finishFailure(requestID, code: "invalid_argument", message: "Track property must be a string.")
                return
            }
            if let meta = properties["meta"], !(meta is [String: Any]) {
                self.finishFailure(requestID, code: "invalid_argument", message: "Track meta must be a JSON object.")
                return
            }

            let object = TrackEventObject(
                name: normalizedName,
                property: properties["property"] as? String,
                meta: properties["meta"] as? [String: Any]
            )
            CFCoreEvent.shared.logIngest(
                eventType: .Track,
                logObject: object,
                isUpdateImmediately: CFUBooleanValue(properties["immediate"]),
                eventTime: (properties["timestamp_ms"] as? NSNumber)?.int64Value
            )
            self.finishSuccess(requestID)
        }
    }

    func logUserCatalog(requestID: UInt64, userID: String, catalogJSON: String) {
        runOnMain {
            guard self.requireInitialized(requestID) else { return }

            let trimmedUserID = userID.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedUserID.isEmpty else {
                self.finishFailure(requestID, code: "invalid_user_id", message: "The user ID cannot be empty.")
                return
            }

            do {
                let values = try self.parseObjectJSON(catalogJSON, argumentName: "User catalog")
                if let rawCountry = values["country"] {
                    guard let country = rawCountry as? String else {
                        throw CFUBridgeError(
                            code: "invalid_user_catalog",
                            message: "User catalog country must be a string."
                        )
                    }
                    if !country.isEmpty && CountryCode(rawValue: country) == nil {
                        throw CFUBridgeError(
                            code: "invalid_user_catalog",
                            message: "Unsupported user catalog country '\(country)'."
                        )
                    }
                }

                guard let data = catalogJSON.data(using: .utf8) else {
                    throw CFUBridgeError(
                        code: "invalid_user_catalog",
                        message: "User catalog must be valid UTF-8 JSON."
                    )
                }
                let catalog = try JSONDecoder().decode(UserCatalogModel.self, from: data)
                CFCoreEvent.shared.logCatalog(
                    coreCatalogType: .User,
                    subjectId: trimmedUserID,
                    catalogModel: catalog
                )
                self.finishSuccess(requestID)
            } catch let error as CFUBridgeError {
                self.finishFailure(requestID, code: error.code, message: error.message)
            } catch {
                self.finishFailure(
                    requestID,
                    code: "invalid_user_catalog",
                    message: "Could not decode the user catalog: \(error.localizedDescription)"
                )
            }
        }
    }

    func logOtherCatalog(requestID: UInt64, subjectID: String, catalogJSON: String) {
        runOnMain {
            guard self.requireInitialized(requestID) else { return }

            let trimmedSubjectID = subjectID.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedSubjectID.isEmpty else {
                self.finishFailure(
                    requestID,
                    code: "invalid_other_catalog",
                    message: "The other catalog subject ID cannot be empty."
                )
                return
            }

            do {
                let values = try self.parseObjectJSON(catalogJSON, argumentName: "Other catalog")
                guard let name = values["name"] as? String else {
                    throw CFUBridgeError(
                        code: "invalid_other_catalog",
                        message: "Other catalog name must be a string."
                    )
                }

                let normalizedName = CFUNormalizeCatalogName(name)
                guard !normalizedName.isEmpty else {
                    throw CFUBridgeError(
                        code: "invalid_other_catalog",
                        message: "Other catalog name cannot be empty."
                    )
                }
                guard !CatalogSubject.allCases.contains(where: { $0.rawValue == normalizedName }),
                      normalizedName != CoreCatalogType.Other.rawValue else {
                    throw CFUBridgeError(
                        code: "invalid_other_catalog",
                        message: "The catalog name '\(name)' is reserved and cannot be used."
                    )
                }
                guard let meta = values["meta"] as? [String: Any], !meta.isEmpty else {
                    throw CFUBridgeError(
                        code: "invalid_other_catalog",
                        message: "Other catalog meta must be a non-empty JSON object."
                    )
                }

                let catalog = OtherCatalogModel(name: name, meta: meta)
                CFCoreEvent.shared.logCatalog(
                    coreCatalogType: .Other,
                    subjectId: trimmedSubjectID,
                    catalogModel: catalog
                )
                self.finishSuccess(requestID)
            } catch let error as CFUBridgeError {
                self.finishFailure(
                    requestID,
                    code: "invalid_other_catalog",
                    message: error.message
                )
            } catch {
                self.finishFailure(
                    requestID,
                    code: "native_other_catalog_failed",
                    message: "Could not log the other catalog: \(error.localizedDescription)"
                )
            }
        }
    }

    func fetchActions(
        requestID: UInt64,
        actionType: String,
        renderMethod: String,
        deliveryMode: String,
        attributesJSON: String
    ) {
        runOnMain {
            guard self.requireInitialized(requestID) else { return }

            let nativeType: InvActionType
            switch actionType.lowercased() {
            case "message": nativeType = .Message
            case "ui-component", "custom": nativeType = .UIComponent
            default:
                self.finishFailure(requestID, code: "invalid_argument", message: "Unsupported action type '\(actionType)'.")
                return
            }

            let nativeRenderMethod: ActionRenderMethodType
            switch renderMethod.lowercased() {
            case "push_notification": nativeRenderMethod = .PushNotification
            case "in_app_message": nativeRenderMethod = .InAppMessage
            case "in_app_component": nativeRenderMethod = .InAppComponent
            default:
                self.finishFailure(requestID, code: "invalid_argument", message: "Unsupported render method '\(renderMethod)'.")
                return
            }

            let nativeDeliveryMode: ActionDeliveryMode
            switch deliveryMode.lowercased() {
            case "one-off": nativeDeliveryMode = .OneOff
            case "cached": nativeDeliveryMode = .Cached
            default:
                self.finishFailure(requestID, code: "invalid_argument", message: "Unsupported delivery mode '\(deliveryMode)'.")
                return
            }

            let attributes: [String: String]
            do {
                let raw = try self.parseObjectJSON(attributesJSON, argumentName: "Action attributes")
                attributes = try self.stringAttributes(raw)
            } catch let error as CFUBridgeError {
                self.finishFailure(requestID, code: error.code, message: error.message)
                return
            } catch {
                self.finishFailure(requestID, code: "invalid_argument", message: error.localizedDescription)
                return
            }

            let gate = CFUCompletionGate()
            DispatchQueue.main.asyncAfter(deadline: .now() + CFUBridgeState.fetchTimeout) {
                if gate.claim() {
                    self.finishFailure(
                        requestID,
                        code: "timeout",
                        message: "The native action fetch did not complete within 60 seconds."
                    )
                }
            }

            CFCoreEvent.shared.fetchActions(
                invActionType: nativeType,
                actionRenderMethodType: nativeRenderMethod,
                deliveryMode: nativeDeliveryMode,
                actionAttr: attributes.isEmpty ? nil : attributes
            ) { items in
                guard gate.claim() else { return }
                do {
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = [.sortedKeys]
                    let data = try encoder.encode(items)
                    guard let json = String(data: data, encoding: .utf8) else {
                        throw CFUBridgeError(code: "serialization_failure", message: "The action response is not valid UTF-8.")
                    }
                    self.finishSuccess(requestID, payload: json)
                } catch let error as CFUBridgeError {
                    self.finishFailure(requestID, code: error.code, message: error.message)
                } catch {
                    self.finishFailure(
                        requestID,
                        code: "serialization_failure",
                        message: "Could not encode the native action response: \(error.localizedDescription)"
                    )
                }
            }
        }
    }

    func showInAppMessage(requestID: UInt64, screen: String) {
        runOnMain {
            guard self.requireInitialized(requestID) else { return }
            guard let screenType = ActionScreenType(rawValue: screen.lowercased()) else {
                self.finishFailure(requestID, code: "invalid_argument", message: "Unsupported action screen '\(screen)'.")
                return
            }
            CFCoreEvent.shared.showInAppMessage(actionScreenType: screenType)
            self.finishSuccess(requestID)
        }
    }

    func requestNotificationPermission(requestID: UInt64) {
        runOnMain {
            CFNotificationController.shared.request { granted, error in
                if let error = error {
                    self.finishFailure(
                        requestID,
                        code: "notification_permission_error",
                        message: "Could not request notification permission: \(error.localizedDescription)"
                    )
                    return
                }

                self.finishSuccess(
                    requestID,
                    payload: granted ? "{\"status\":\"authorized\"}" : "{\"status\":\"denied\"}"
                )
            }
        }
    }

    func setPaused(requestID: UInt64, paused: Bool) {
        runOnMain {
            guard self.requireInitialized(requestID) else { return }
            CoreConstants.shared.setUnityRuntimePaused(paused)
            self.finishSuccess(requestID)
        }
    }

    private func installActionHook() {
        lock.lock()
        let shouldInstall = !actionHookInstalled
        if shouldInstall { actionHookInstalled = true }
        lock.unlock()
        guard shouldInstall else { return }

        runOnMain {
            ActionOnClickObject.actionOnClickInterface = { attributes in
                CFUBridgeState.shared.handleActionOpened(attributes)
            }
        }
    }

    private func handleActionOpened(_ attributes: [String: String]?) {
        let object = attributes ?? [:]
        let json: String
        do {
            let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
            json = String(data: data, encoding: .utf8) ?? "{}"
        } catch {
            json = "{}"
        }

        lock.lock()
        let callback = actionOpenedCallback
        if callback == nil {
            if pendingActionOpens.count == CFUBridgeState.maximumPendingActionOpens {
                pendingActionOpens.removeFirst()
            }
            pendingActionOpens.append(json)
        }
        lock.unlock()

        guard let callback = callback else { return }
        runOnMain {
            json.withCString { callback($0) }
        }
    }

    private func requireInitialized(_ requestID: UInt64) -> Bool {
        lock.lock()
        let initialized = configuration != nil
        lock.unlock()
        if !initialized {
            finishFailure(requestID, code: "not_initialized", message: "Initialize Causal Foundry before using this API.")
        }
        return initialized
    }

    private func parseObjectJSON(_ json: String, argumentName: String) throws -> [String: Any] {
        if json.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return [:]
        }
        guard let data = json.data(using: .utf8) else {
            throw CFUBridgeError(code: "invalid_argument", message: "\(argumentName) must be valid UTF-8 JSON.")
        }
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data, options: [])
        } catch {
            throw CFUBridgeError(code: "invalid_argument", message: "\(argumentName) are not valid JSON: \(error.localizedDescription)")
        }
        guard let dictionary = object as? [String: Any] else {
            throw CFUBridgeError(code: "invalid_argument", message: "\(argumentName) JSON must contain an object.")
        }
        return dictionary
    }

    private func stringAttributes(_ values: [String: Any]) throws -> [String: String] {
        var result: [String: String] = [:]
        for (key, value) in values {
            if value is NSNull {
                continue
            } else if let string = value as? String {
                result[key] = string
            } else if let number = value as? NSNumber {
                result[key] = CFGetTypeID(number) == CFBooleanGetTypeID()
                    ? (number.boolValue ? "true" : "false")
                    : number.stringValue
            } else if JSONSerialization.isValidJSONObject(value) {
                let data = try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
                guard let json = String(data: data, encoding: .utf8) else {
                    throw CFUBridgeError(code: "invalid_argument", message: "Action attribute '\(key)' is not valid UTF-8.")
                }
                result[key] = json
            } else {
                throw CFUBridgeError(code: "invalid_argument", message: "Action attribute '\(key)' cannot be represented as a string.")
            }
        }
        return result
    }

    private func finishSuccess(_ requestID: UInt64, payload: String? = nil) {
        finish(requestID, status: 0, payload: payload, code: nil, message: nil)
    }

    private func finishFailure(_ requestID: UInt64, code: String, message: String) {
        finish(requestID, status: 1, payload: nil, code: code, message: message)
    }

    private func finish(
        _ requestID: UInt64,
        status: Int32,
        payload: String?,
        code: String?,
        message: String?
    ) {
        guard requestID != 0 else { return }

        lock.lock()
        let callback = resultCallback
        lock.unlock()
        guard let callback = callback else { return }

        runOnMain {
            let payloadValue = payload ?? ""
            let codeValue = code ?? ""
            let messageValue = message ?? ""
            payloadValue.withCString { payloadPointer in
                codeValue.withCString { codePointer in
                    messageValue.withCString { messagePointer in
                        callback(
                            requestID,
                            status,
                            payload == nil ? nil : payloadPointer,
                            code == nil ? nil : codePointer,
                            message == nil ? nil : messagePointer
                        )
                    }
                }
            }
        }
    }

    private func runOnMain(_ block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async(execute: block)
        }
    }
}

@_cdecl("CFU_IsSupported")
public func CFU_IsSupported() -> Int32 {
    if #available(iOS 13.0, *) { return 1 }
    return 0
}

@_cdecl("CFU_RegisterCallbacks")
public func CFU_RegisterCallbacks(
    _ resultCallback: CFUResultCallback?,
    _ actionOpenedCallback: CFUActionOpenedCallback?
) {
    CFUBridgeState.shared.registerCallbacks(result: resultCallback, actionOpened: actionOpenedCallback)
}

@_cdecl("CFU_EarlyBootstrap")
public func CFU_EarlyBootstrap() {
    CFUBridgeState.shared.earlyBootstrap()
}

@_cdecl("CFU_InstallNotificationDelegate")
public func CFU_InstallNotificationDelegate() {
    CFUBridgeState.shared.installNotificationDelegate()
}

@_cdecl("CFU_Initialize")
public func CFU_Initialize(
    _ requestID: UInt64,
    _ sdkKey: UnsafePointer<CChar>?,
    _ optionsJSON: UnsafePointer<CChar>?
) {
    CFUBridgeState.shared.initialize(
        requestID: requestID,
        sdkKey: sdkKey.map { String(cString: $0) } ?? "",
        optionsJSON: optionsJSON.map { String(cString: $0) } ?? "{}"
    )
}

@_cdecl("CFU_Identify")
public func CFU_Identify(
    _ requestID: UInt64,
    _ userID: UnsafePointer<CChar>?,
    _ action: UnsafePointer<CChar>?,
    _ attributesJSON: UnsafePointer<CChar>?
) {
    CFUBridgeState.shared.identify(
        requestID: requestID,
        userID: userID.map { String(cString: $0) } ?? "",
        action: action.map { String(cString: $0) } ?? "",
        attributesJSON: attributesJSON.map { String(cString: $0) } ?? "{}"
    )
}

@_cdecl("CFU_Track")
public func CFU_Track(
    _ requestID: UInt64,
    _ eventName: UnsafePointer<CChar>?,
    _ propertiesJSON: UnsafePointer<CChar>?
) {
    CFUBridgeState.shared.track(
        requestID: requestID,
        eventName: eventName.map { String(cString: $0) } ?? "",
        propertiesJSON: propertiesJSON.map { String(cString: $0) } ?? "{}"
    )
}

@_cdecl("CFU_LogUserCatalog")
public func CFU_LogUserCatalog(
    _ requestID: UInt64,
    _ userID: UnsafePointer<CChar>?,
    _ catalogJSON: UnsafePointer<CChar>?
) {
    CFUBridgeState.shared.logUserCatalog(
        requestID: requestID,
        userID: userID.map { String(cString: $0) } ?? "",
        catalogJSON: catalogJSON.map { String(cString: $0) } ?? "{}"
    )
}

@_cdecl("CFU_LogOtherCatalog")
public func CFU_LogOtherCatalog(
    _ requestID: UInt64,
    _ subjectID: UnsafePointer<CChar>?,
    _ catalogJSON: UnsafePointer<CChar>?
) {
    CFUBridgeState.shared.logOtherCatalog(
        requestID: requestID,
        subjectID: subjectID.map { String(cString: $0) } ?? "",
        catalogJSON: catalogJSON.map { String(cString: $0) } ?? "{}"
    )
}

@_cdecl("CFU_FetchActions")
public func CFU_FetchActions(
    _ requestID: UInt64,
    _ actionType: UnsafePointer<CChar>?,
    _ renderMethod: UnsafePointer<CChar>?,
    _ deliveryMode: UnsafePointer<CChar>?,
    _ attributesJSON: UnsafePointer<CChar>?
) {
    CFUBridgeState.shared.fetchActions(
        requestID: requestID,
        actionType: actionType.map { String(cString: $0) } ?? "",
        renderMethod: renderMethod.map { String(cString: $0) } ?? "",
        deliveryMode: deliveryMode.map { String(cString: $0) } ?? "",
        attributesJSON: attributesJSON.map { String(cString: $0) } ?? "{}"
    )
}

@_cdecl("CFU_ShowInAppMessage")
public func CFU_ShowInAppMessage(
    _ requestID: UInt64,
    _ screen: UnsafePointer<CChar>?
) {
    CFUBridgeState.shared.showInAppMessage(
        requestID: requestID,
        screen: screen.map { String(cString: $0) } ?? ""
    )
}

@_cdecl("CFU_RequestNotificationPermission")
public func CFU_RequestNotificationPermission(_ requestID: UInt64) {
    CFUBridgeState.shared.requestNotificationPermission(requestID: requestID)
}

@_cdecl("CFU_SetPaused")
public func CFU_SetPaused(_ requestID: UInt64, _ paused: Int32) {
    CFUBridgeState.shared.setPaused(requestID: requestID, paused: paused != 0)
}
