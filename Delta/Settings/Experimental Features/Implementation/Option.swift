//
//  Option.swift
//  Delta
//
//  Created by Riley Testut on 4/7/23.
//  Copyright © 2023 Riley Testut. All rights reserved.
//

import SwiftUI
import Combine

protocol AnyOption<Value>: AnyObject, Identifiable
{
    associatedtype Value
    
    var name: LocalizedStringKey { get }
    var key: String { get }
    var description: LocalizedStringKey? { get }
    
    var detailView: () -> AnyView? { get }
    
    // TODO: Remove below
    var wrappedValue: Value { get }
}

extension AnyOption
{
    var id: String { key }
}

// Don't expose `feature` property via AnyOption protocol.
protocol _AnyOption: AnyOption
{
    var key: String { get set }
    var feature: AnyFeature? { get set }
}

@propertyWrapper
class Option<Value>: _AnyOption
{
    let name: LocalizedStringKey
    let description: LocalizedStringKey?
    
    private(set) var detailView: () -> AnyView? = { nil }
    
    //TODO: Make fileprivate
    internal(set) var key: String = ""
    internal weak var feature: AnyFeature?
    
    private let initialValue: Value
    
    // Must be property in order for UI to update automatically.
    private var valueBinding: Binding<Value> {
        Binding(get: {
            self.wrappedValue
        }, set: {
            self.wrappedValue = $0
        })
    }
    
    // No SwiftUI view.
    init(wrappedValue: Value, name: LocalizedStringKey, description: LocalizedStringKey? = nil)
    {
        self.initialValue = wrappedValue
        
        self.name = name
        self.description = description
    }
    
    // Custom SwiftUI view.
    init(wrappedValue: Value, name: LocalizedStringKey, description: LocalizedStringKey? = nil, @ViewBuilder detailView: @escaping (Binding<Value>) -> some View)
    {
        self.initialValue = wrappedValue
        
        self.name = name
        self.description = description
        
        self.detailView = {
            let view = detailView(self.valueBinding)
            return AnyView(
                Form {
                    view
                }
            )
        }
    }
    
    /// @propertyWrapper
    var projectedValue: Option<Value> { self }
    
    var wrappedValue: Value {
        get {
            do {
                let wrappedValue = try UserDefaults.standard.optionValue(forKey: self.key, type: Value.self)
                return wrappedValue ?? self.initialValue
            }
            catch {
                print("[ALTLog] Failed to read option value for key \(self.key).", error)
                return self.initialValue
            }
        }
        set {
            Task { @MainActor in
                // Delay to avoid "Publishing changes from within view updates is not allowed" runtime warning.
                self.feature?.objectWillChange.send()
            }
            
            do {
                try UserDefaults.standard.setOptionValue(newValue, forKey: self.key)
            }
            catch {
                print("[ALTLog] Failed to set option value for key \(self.key).", error)
            }
        }
    }
}
