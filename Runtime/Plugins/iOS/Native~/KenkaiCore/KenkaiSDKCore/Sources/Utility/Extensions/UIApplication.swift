//
//  UIApplication.swift
//
//
//  Created by khushbu on 25/09/23.
//

import Foundation
import UIKit

extension UIApplication {
    var icon: UIImage? {
        guard let iconsDictionary = Bundle.main.infoDictionary?["CFBundleIcons"] as? NSDictionary,
              let primaryIconsDictionary = iconsDictionary["CFBundlePrimaryIcon"] as? NSDictionary,
              let iconFiles = primaryIconsDictionary["CFBundleIconFiles"] as? NSArray,
              // First will be smallest for the device class, last will be the largest for device class
              let lastIcon = iconFiles.lastObject as? String,
              let icon = UIImage(named: lastIcon)
        else {
            return nil
        }

        return icon
    }

    func appVersion() -> String {
    
        if let appVersionNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
            return  appVersionNumber
        } else {
            return "0.0" // Default or fallback version if the version number is not found
        }
    }

    func build() -> Int {
        
        if let buildVersionString = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String,
           let buildVersionInt = Int(buildVersionString) {
            return buildVersionInt
        } else {
            return 0 // Fallback if the build version isn't found or can't be converted
        }
    }

    func versionBuild() -> String {
        if let appVersionNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
            return  "\(appVersionNumber) (\(build()))"
        } else {
            return "0.0" // Default or fallback version if the version number is not found
        }
    }

    func bundleIdentifier() -> String {
        return Bundle.main.bundleIdentifier ?? "0.0"
    }

    func targetVersion() -> Int {
        // you have to set Manually
        return 17
    }

    func minimumVersion() -> Int {
        if let appVersionNumber = Bundle.main.object(forInfoDictionaryKey: "MinimumOSVersion") {
            guard let majorVersion = (appVersionNumber as! String).split(separator: ".").first else {
                return 0
            }
            return Int(majorVersion)!

        } else {
            return 0
        }
    }
}
