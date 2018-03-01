//
//  UIColorExtensions.swift
//  SoapVideo
//
//  Created by Carl Chen on 30/01/2018.
//  Copyright © 2018 SoapVideo. All rights reserved.
//

import UIKit

extension UIColor: NamespaceWrappable { }
extension NamespaceWrapper where T: UIColor {
    public static func color(hex: String) -> UIColor {
        let defaultColor = UIColor.clear

        let lowercasedText = hex
            .lowercased()
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

        var hexColorText: Substring
        switch lowercasedText {
        case let text where text.hasPrefix("0x"):
            hexColorText = text.soap[2...]
        case let text where text.hasPrefix("#"):
            hexColorText = text.soap[1...]
        default:
            hexColorText = lowercasedText[...]
        }

        guard hexColorText.soap.match(regex: "[0-9a-f]{6}") else {
            return defaultColor
        }

        var r: UInt32 = 0
        var g: UInt32 = 0
        var b: UInt32 = 0

        guard Scanner(string: String(hexColorText.soap[0..<2])).scanHexInt32(&r)
            , Scanner(string: String(hexColorText.soap[2..<4])).scanHexInt32(&g)
            , Scanner(string: String(hexColorText.soap[4..<6])).scanHexInt32(&b)
            else {
                return defaultColor
        }

        return UIColor(red: CGFloat(r) / 255.0
            , green: CGFloat(g) / 255.0
            , blue: CGFloat(b) / 255.0
            , alpha: 1.0)
    }
}
