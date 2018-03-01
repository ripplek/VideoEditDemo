//
//  UIViewChain.swift
//  SoapVideo
//
//  Created by Carl Chen on 30/01/2018.
//  Copyright © 2018 SoapVideo. All rights reserved.
//

import Foundation

import UIKit
import SnapKit

extension UIView: NamespaceWrappable { }
extension NamespaceWrapper where T: UIView {
    public func adhere(toSuperView: UIView) -> T {
        toSuperView.addSubview(wrappedValue)
        return wrappedValue
    }

    @discardableResult
    public func layout(snapKitMaker: (ConstraintMaker) -> Void) -> T {
        wrappedValue.snp.makeConstraints { (make) in
            snapKitMaker(make)
        }
        return wrappedValue
    }

    @discardableResult
    public func config(_ config: (T) -> Void) -> T {
        config(wrappedValue)
        return wrappedValue
    }
}
