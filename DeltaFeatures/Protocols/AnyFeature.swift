//
//  AnyFeature.swift
//  DeltaFeatures
//
//  Created by Riley Testut on 4/12/23.
//  Copyright © 2023 Riley Testut. All rights reserved.
//

import SwiftUI

@dynamicMemberLookup
public protocol AnyFeature<Options>: ObservableObject, Identifiable
{
    associatedtype Options = EmptyOptions
    
    var name: LocalizedStringKey { get }
    var description: LocalizedStringKey?  { get }
    
    var key: String  { get }
    var settingsKey: SettingsName { get }
    
    var isEnabled: Bool { get set }
    
    var allOptions: [any AnyOption] { get }
    
    subscript<T>(dynamicMember keyPath: KeyPath<Options, T>) -> T { get set }
}

extension AnyFeature
{
    public var id: String { self.key }
}

// Don't expose `key` setter via AnyFeature protocol.
internal protocol _AnyFeature: AnyFeature
{
    var key: String { get set }
}
