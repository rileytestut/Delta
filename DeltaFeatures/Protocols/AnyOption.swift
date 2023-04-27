//
//  AnyOption.swift
//  DeltaFeatures
//
//  Created by Riley Testut on 4/12/23.
//  Copyright © 2023 Riley Testut. All rights reserved.
//

import SwiftUI

public protocol AnyOption<Value>: AnyObject, Identifiable
{
    associatedtype Value: OptionValue
    associatedtype DetailView: View
    
    var name: LocalizedStringKey? { get }
    var description: LocalizedStringKey? { get }
    
    var key: String { get }
    var settingsKey: SettingsName { get }
    
    var values: (() -> [Value])? { get }
    var detailView: () -> DetailView? { get }
    
    var value: Value { get set }
}

extension AnyOption
{
    public var id: String { self.key }
}

// Don't expose `feature` or `key` setters via AnyOption protocol.
internal protocol _AnyOption: AnyOption
{
    var key: String { get set }
    var feature: (any AnyFeature)? { get set }
    
    var wrappedValue: Value { get set }
}

extension _AnyOption
{
    public var value: Value {
        get { self.wrappedValue }
        set { self.wrappedValue = newValue }
    }
}
