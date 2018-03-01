//
//  Namespace.swift
//
//
//  Created by Carl on 22/3/2017.
//  Copyright © 2017 nswebfrog. All rights reserved.
//


public protocol NamespaceWrappable {
    associatedtype SoapWrapperType
    var soap: SoapWrapperType { get }
    static var soap: SoapWrapperType.Type { get }
}

public extension NamespaceWrappable {
    var soap: NamespaceWrapper<Self> {
        return NamespaceWrapper(value: self)
    }

    static var soap: NamespaceWrapper<Self>.Type {
        return NamespaceWrapper.self
    }
}

public struct NamespaceWrapper<T> {
    public let wrappedValue: T
    public init(value: T) {
        self.wrappedValue = value
    }
}
