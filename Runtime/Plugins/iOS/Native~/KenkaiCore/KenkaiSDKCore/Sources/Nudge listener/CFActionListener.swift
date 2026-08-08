//
//  CFActionListener.swift
//
//
//  Created by kenkai on 29.11.23.
//

import UIKit

class CFActionListener {
    static let shared = CFActionListener()

    private var actionTimer: Timer?
    private var actionTask: URLSessionDataTask?
    private var lifecycleObservers: [NSObjectProtocol] = []

    let timeInterval: TimeInterval = 20 * 3600

    func endListening() {
        endTimer()
        lifecycleObservers.forEach(NotificationCenter.default.removeObserver)
        lifecycleObservers.removeAll()
    }

    func beginListening() {
        endListening()
        guard !CoreConstants.shared.pauseSDK else { return }
        startTimer()
        fetchAndDisplayActionTask()
        let resignObserver = NotificationCenter.default.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            self?.endTimer()
        }
        let foregroundObserver = NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [weak self] _ in
            guard !CoreConstants.shared.pauseSDK else { return }
            self?.startTimer()
            self?.fetchAndDisplayActionTask()
        }
        lifecycleObservers = [resignObserver, foregroundObserver]
    }
    
    @available(iOS 13.0, *)
    private func fetchActionsfromBackend(invActionType: InvActionType,
                                         actionRenderMethodType: ActionRenderMethodType,
                                         deliveryMode: ActionDeliveryMode,
                                         actionAttr: [String: String]?) async throws -> ActionAPIResponse {
      var userId = CoreConstants.shared.userId
      
      if(userId == nil || userId?.isEmpty == true){
        userId = MMKVHelper.shared.fetchUserBackupID()
      }
      
      if(userId ==  nil || userId?.isEmpty == true){
          userId = CoreConstants.shared.internalInfoObject?.device_id
      }
      guard let userID = userId, !userID.isEmpty else {
        return ActionAPIResponse(data: [])
      }
        
        let nudgeRequestData = ActionRequestObject(userId: userID, actionType: invActionType.rawValue, renderMethod: actionRenderMethodType.rawValue,
                                                   deliveryMode: deliveryMode.rawValue,
                                                   attr: actionAttr)
      
      let dictionary = nudgeRequestData.dictionary ?? [:]
    
      return try await withCheckedThrowingContinuation { continuation in
        
        let url = URL(string: APIConstants.fetchAction)!
        BackgroundRequestController.shared.request(url: url, httpMethod: .post, params: dictionary) { result in
          switch result {
          case .success(let data):
            do {
              let decoder = JSONDecoder.new
              let objects = try decoder.decode(ActionAPIResponse.self, from: data ?? Data())
              continuation.resume(with: .success(objects))
            } catch {
              print("error: \(error)")
              continuation.resume(with: .failure(error))
            }
          case .failure(let error):
            continuation.resume(with: .failure(error))
          }
        }
      }
    }

    private func startTimer() {
        actionTimer?.invalidate()
        actionTimer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: true) { [weak self] _ in
            guard !CoreConstants.shared.pauseSDK else {
                self?.endTimer()
                return
            }
            self?.fetchAndDisplayActionTask()
        }
    }

    private func endTimer() {
        actionTimer?.invalidate()
        actionTimer = nil
    }

    @available(iOS 13.0, *)
    func fetchAndDisplayPushNotificationActions() async throws {
//        let pushNotificationActionObjects = try! ActionAPIResponse.debugObjects().data
        let pushNotificationActionObjects = try await fetchActionsfromBackend(invActionType: InvActionType.Message, actionRenderMethodType: ActionRenderMethodType.PushNotification,
                                                                              deliveryMode: ActionDeliveryMode.OneOff, actionAttr: nil).data
        guard !CoreConstants.shared.pauseSDK else { return }
        
        
        // Filter out expired or errored nudges
        let validNonExpiredNudges = pushNotificationActionObjects?.filter { nudge in
          !(nudge.payload?.isExpired ?? false) && (nudge.error?.isEmpty ?? true)
        } ?? []

        // Filter out nudges with errors
        let erroredNudges = pushNotificationActionObjects?.filter { nudge in
            !(nudge.error?.isEmpty ?? true)
        } ?? []
        
        // Find the expired objects by subtracting non-expired ones from all fetched objects
        let expiredObjects = pushNotificationActionObjects?.filter { nudge in
          !(validNonExpiredNudges.contains(where: { $0.payload == nudge.payload })) &&
            !(erroredNudges.contains(where: { $0.payload == nudge.payload }))
        } ?? []
        
        // Call a function for each expired object
        expiredObjects.forEach { expiredNudge in
            CFNotificationController.shared.track(payload: expiredNudge.payload, response: ActionRepsonse.Expired)
        }
        
        for object in validNonExpiredNudges {
          if(object.payload != nil) {
            CFNotificationController.shared.triggerActionNotification(object: object.payload!)
          }
        }
    }
    
    
    @available(iOS 13.0, *)
    func fetchAndDisplayInAppMessagesAction(actionScreenType: ActionScreenType) async throws {
//        let inAppMessageActionObjects = try! ActionAPIResponse.debugObjects().data
        let attr: [String: String]? = !actionScreenType.rawValue.isEmpty ? ["render_page": actionScreenType.rawValue] : nil
        let inAppMessageActionObjects = try await fetchActionsfromBackend(invActionType: InvActionType.Message, actionRenderMethodType: ActionRenderMethodType.InAppMessage,
                                                                              deliveryMode: ActionDeliveryMode.OneOff, actionAttr: attr).data
        guard !CoreConstants.shared.pauseSDK else { return }
        
        // Filter out expired or errored nudges
        let validNonExpiredNudges = inAppMessageActionObjects?.filter { nudge in
          !(nudge.payload?.isExpired ?? false) && (nudge.error?.isEmpty ?? true)
        } ?? []

        // Filter out nudges with errors
        let erroredNudges = inAppMessageActionObjects?.filter { nudge in
            !(nudge.error?.isEmpty ?? true)
        } ?? []
        
        // Find the expired objects by subtracting non-expired ones from all fetched objects
        let expiredObjects = inAppMessageActionObjects?.filter { nudge in
          !(validNonExpiredNudges.contains(where: { $0.payload == nudge.payload })) &&
            !(erroredNudges.contains(where: { $0.payload == nudge.payload }))
        } ?? []
        
        // Call a function for each expired object
        expiredObjects.forEach { expiredNudge in
            CFNotificationController.shared.track(payload: expiredNudge.payload, response: ActionRepsonse.Expired)
        }
        
        if (CoreConstants.shared.isAppOpen) {
            let nudgesToShow = validNonExpiredNudges

            Task { @MainActor in
                guard let window = UIApplication.shared.windows.first,
                      let rootViewController = window.rootViewController else {
                    nudgesToShow.forEach { action in
                        CFNotificationController.shared.track(
                            payload: action.payload,
                            response: .Error,
                            details: "unable to show actions, UI controller not found"
                        )
                    }
                    return
                }

                CFActionPresenter.presentWithData(
                    in: rootViewController,
                    objects: nudgesToShow
                )
            }
        }else{
            var storedActions = MMKVHelper.shared.readActions()
            if(!storedActions.isEmpty){
                storedActions.append(contentsOf: validNonExpiredNudges)
                MMKVHelper.shared.writeActions(objects: storedActions)
                return
            }
            MMKVHelper.shared.writeActions(objects: validNonExpiredNudges)
        }
    }
    
    
    @available(iOS 13.0, *)
    func fetchActionsCF(
        invActionType: InvActionType,
        actionRenderMethodType: ActionRenderMethodType,
        deliveryMode: ActionDeliveryMode,
        actionAttr: [String: String]?,
        onResult: (([NudgeResponseItem]) -> Void)
    ) async throws {
        
        let fetchedActionObjects = try await fetchActionsfromBackend(invActionType: invActionType, actionRenderMethodType: actionRenderMethodType,
                                                                     deliveryMode: deliveryMode, actionAttr: actionAttr).data
        
        // Filter out expired or errored nudges
        let validNonExpiredNudges = fetchedActionObjects?.filter { nudge in
          !(nudge.payload?.isExpired ?? false) && (nudge.error?.isEmpty ?? true)
        } ?? []

        // Filter out nudges with errors
        let erroredNudges = fetchedActionObjects?.filter { nudge in
            !(nudge.error?.isEmpty ?? true)
        } ?? []
        
        // Find the expired objects by subtracting non-expired ones from all fetched objects
        let expiredObjects = fetchedActionObjects?.filter { nudge in
          !(validNonExpiredNudges.contains(where: { $0.payload == nudge.payload })) &&
            !(erroredNudges.contains(where: { $0.payload == nudge.payload }))
        } ?? []
        
        // Call a function for each expired object
        expiredObjects.forEach { expiredNudge in
            CFNotificationController.shared.track(payload: expiredNudge.payload, response: ActionRepsonse.Expired)
        }
        
        onResult(validNonExpiredNudges)
        
    }
    
    private func fetchAndDisplayActionTask() {
        guard !CoreConstants.shared.pauseSDK else { return }
        if #available(iOS 13.0, *) {
            Task {
                guard !CoreConstants.shared.pauseSDK else { return }
                try await fetchAndDisplayPushNotificationActions()
                guard !CoreConstants.shared.pauseSDK else { return }
                if(CoreConstants.shared.isAppOpen && CoreConstants.shared.autoShowInAppMessage){
                    try await fetchAndDisplayInAppMessagesAction(actionScreenType: ActionScreenType.None)
                }
            }
        }
    }
    
    
    public func showInAppMessages(actionScreenType: ActionScreenType) {
        if #available(iOS 13.0, *) {
            Task {
                if(CoreConstants.shared.isAppOpen && !CoreConstants.shared.autoShowInAppMessage){
                    try await fetchAndDisplayInAppMessagesAction(actionScreenType: actionScreenType)
                }
            }
        }
    }
    
    public func fetchActions(
        invActionType: InvActionType,
        actionRenderMethodType: ActionRenderMethodType,
        deliveryMode: ActionDeliveryMode,
        actionAttr: [String: String]?,
        onResult: @escaping ([NudgeResponseItem]) -> Void
    ) {
        if #available(iOS 13.0, *) {
            Task {
                try await fetchActionsCF(
                    invActionType: invActionType,
                    actionRenderMethodType: actionRenderMethodType,
                    deliveryMode: deliveryMode,
                    actionAttr: actionAttr,
                    onResult: onResult
                )
            }
        }
    }
}

#if DEBUG
extension ActionAPIResponse {
    
    static func debugObjects() throws -> ActionAPIResponse {
        let json = """
        {"data":[{"user_id":"sdkTestUserId","payload":{"type":"message","render_method":"push_notification","delivery_mode":"one-off","content":{"body":"Some text here for the body","title":"Hello World"},"attr":{"cta_type":"redirect", "cta_id":"123", "cta_id_ss":"123ss"},"tags":null,"internal":{"inv_id":62,"action_id":33,"ref_time":"2025-10-23T14:27:00Z","expired_at":"2025-11-25T14:27:00Z","followup_of_ref":"0001-01-01T00:00:00Z","template_vals":{}}},"error":null,"queued_at":"2025-10-23T14:27:29.277756Z"}]}
        """
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder.new
        let objects = try decoder.decode(ActionAPIResponse.self, from: data)
        return objects
    }
}
#endif
