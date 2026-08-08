//
//  CFViewController.swift
//
//
//  Created by kenkai on 30.11.23.
//

import UIKit

open class CFViewController: UIViewController {
    private var className: String {
        NSStringFromClass(classForCoder).components(separatedBy: ".").last!
    }

    private var path: String {
        return "\(Bundle.main.bundleIdentifier ?? "")/\(className)"
    }

    private var renderBeginTime: CFAbsoluteTime!
    private var renderEndTime: CFAbsoluteTime!
    private var durationBeginTime: CFAbsoluteTime!

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override open func viewDidLoad() {
        super.viewDidLoad()
        renderBeginTime = CFAbsoluteTimeGetCurrent()
    }

    override open func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        durationBeginTime = CFAbsoluteTimeGetCurrent()
        if renderEndTime == nil {
            // only set once. user can return to preview view in stack
            renderEndTime = CFAbsoluteTimeGetCurrent()
        }
        
        if(CoreConstants.shared.allowAutoPageTrack){
            let pageObject = PageObject(path: path, title: className, renderTime: Int(renderEndTime - renderBeginTime))
            CFCoreEvent.shared.logIngest(eventType: .Page, logObject: pageObject)
        }
        
    }

    override open func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
}
