//
//  ActionUtils.swift
//
//
//  Created by kenkai on 30.11.23.
//

import Foundation
import UIKit


extension String {
    func htmlAttributedString() -> NSMutableAttributedString {

            guard let data = self.data(using: String.Encoding.utf8, allowLossyConversion: false)
                else { return NSMutableAttributedString() }

            guard let formattedString = try? NSMutableAttributedString(data: data,
                                                            options: [.documentType: NSAttributedString.DocumentType.html,
                                                                      .characterEncoding: String.Encoding.utf8.rawValue],
                                                            documentAttributes: nil )

                else { return NSMutableAttributedString() }

            return formattedString
    }

}

extension NSMutableAttributedString {

    func with(font: UIFont) -> NSMutableAttributedString {
        enumerateAttribute(NSAttributedString.Key.font, in: NSMakeRange(0, length), options: .longestEffectiveRangeNotRequired, using: { (value, range, stop) in
            if let originalFont = value as? UIFont, let newFont = applyTraitsFromFont(originalFont, to: font) {
                addAttribute(NSAttributedString.Key.font, value: newFont, range: range)
            }
        })

        return self
    }

    func applyTraitsFromFont(_ originalFont: UIFont, to newFont: UIFont) -> UIFont? {
        let originalTrait = originalFont.fontDescriptor.symbolicTraits

        if originalTrait.contains(.traitBold) {
            var traits = newFont.fontDescriptor.symbolicTraits
            traits.insert(.traitBold)

            if let fontDescriptor = newFont.fontDescriptor.withSymbolicTraits(traits) {
                return UIFont.init(descriptor: fontDescriptor, size: 0)
            }
        }
        
        if originalTrait.contains(.traitItalic) {
            var traits = newFont.fontDescriptor.symbolicTraits
            traits.insert(.traitItalic)

            if let fontDescriptor = newFont.fontDescriptor.withSymbolicTraits(traits) {
                return UIFont.init(descriptor: fontDescriptor, size: 0)
            }
        }

        return newFont
    }
}
