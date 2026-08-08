//
//  File.swift
//
//
//  Created by MOIZ HASSAN KHAN on 28/8/24.
//

import Foundation

public class CFCoreEvent {
    public static let shared = CFCoreEvent()
    
    private init() {}
    
    
    public func logIngest<T: Codable>(eventType: CoreEventType,
                                          logObject: T?,
                                          isUpdateImmediately: Bool? = CoreConstants.shared.updateImmediately,
                                          eventTime: Int64? = 0) {
        
        CFCoreSetupInterfaceImpl.shared.trackSDKEvent(eventName: eventType,
                                                      logObject: logObject,
                                                      isUpdateImmediately: isUpdateImmediately,
                                                      eventTime: eventTime)
    }
    
    public func logCatalog<T: Codable>(coreCatalogType: CoreCatalogType, subjectId: String, catalogModel: T) {
        CFCoreSetupInterfaceImpl.shared.trackCatalogEvent(coreCatalogType: coreCatalogType, subjectId: subjectId, catalogModel: catalogModel)
    }
    
    public func showInAppMessage(actionScreenType: ActionScreenType) {
        CFActionListener.shared.showInAppMessages(actionScreenType: actionScreenType)
    }
    
    public func fetchActions(
        invActionType: InvActionType,
        actionRenderMethodType: ActionRenderMethodType,
        deliveryMode: ActionDeliveryMode,
        actionAttr: [String: String]?,
        onResult: @escaping ([NudgeResponseItem]) -> Void
    ) {
        CFActionListener.shared.fetchActions(
            invActionType: invActionType,
            actionRenderMethodType: actionRenderMethodType,
            deliveryMode: deliveryMode,
            actionAttr: actionAttr,
            onResult: onResult
        )
    }
    
    
}

