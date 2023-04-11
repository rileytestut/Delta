//
//  Option.swift
//  Delta
//
//  Created by Riley Testut on 4/7/23.
//  Copyright © 2023 Riley Testut. All rights reserved.
//

import SwiftUI
import Combine

private extension Array
{
    func appendingNil() -> [Element] where Element: OptionalProtocol, Element.Wrapped: LocalizedOptionValue
    {
        var values = self
        values.append(Element.none)
        return values
    }
}

protocol AnyOption<Value>: AnyObject, Identifiable
{
    associatedtype Value: OptionValue
    associatedtype DetailView: View
    
    var name: LocalizedStringKey? { get }
    var key: String { get }
    var description: LocalizedStringKey? { get }
    
    var values: [Value]? { get }
    var detailView: () -> DetailView? { get }
    
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
class Option<Value: OptionValue, DetailView: View>: _AnyOption
{
    // Nil name == hidden option.
    let name: LocalizedStringKey?
    let description: LocalizedStringKey?
    
    let values: [Value]?
    private(set) var detailView: () -> DetailView? = { nil }
    
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
    
    // No options or custom SwiftUI view.
    init(wrappedValue: Value, name: LocalizedStringKey? = nil, description: LocalizedStringKey? = nil) where DetailView == EmptyView
    {
        self.initialValue = wrappedValue
        
        self.name = name
        self.description = description
        self.values = nil
    }
    
    // Pre-set options with default picker UI.
    init(wrappedValue: Value, name: LocalizedStringKey, description: LocalizedStringKey? = nil, values: some Collection<Value>) where Value: LocalizedOptionValue, DetailView == OptionPickerView<Value>
    {
        self.initialValue = wrappedValue

        self.name = name
        self.description = description
        
        let values = Array(values)
        self.values = values
        
        self.detailView = { [weak self] () -> DetailView? in
            guard let self else { return nil }
            return OptionPickerView(name: name, options: values, selectedValue: self.valueBinding)
        }
    }
    
    // (Optionals) Pre-set options with default picker UI (no default value)
    init(name: LocalizedStringKey, description: LocalizedStringKey? = nil, values: some Collection<Value>) where Value: LocalizedOptionValue & OptionalProtocol, Value.Wrapped: LocalizedOptionValue, DetailView == OptionPickerView<Value>
    {
        self.initialValue = Value.none

        self.name = name
        self.description = description
        
        let values = Array(values)
        self.values = values
        
        self.detailView = { [weak self] () -> DetailView? in
            guard let self else { return nil }
            return OptionPickerView(name: name, options: values.appendingNil(), selectedValue: self.valueBinding)
        }
    }
    
    // (Optionals) Pre-set options with default picker UI.
    init(wrappedValue: Value, name: LocalizedStringKey, description: LocalizedStringKey? = nil, values: some Collection<Value>) where Value: LocalizedOptionValue & OptionalProtocol, Value.Wrapped: LocalizedOptionValue, DetailView == OptionPickerView<Value>
    {
        self.initialValue = wrappedValue

        self.name = name
        self.description = description
        
        let values = Array(values)
        self.values = values
        
        self.detailView = { [weak self] () -> DetailView? in
            guard let self else { return nil }
            return OptionPickerView(name: name, options: values.appendingNil(), selectedValue: self.valueBinding)
        }
    }
    
    // Custom SwiftUI view.
    init(wrappedValue: Value, name: LocalizedStringKey, description: LocalizedStringKey? = nil, @ViewBuilder detailView: @escaping (Binding<Value>) -> DetailView) where Value: LocalizedOptionValue
    {
        self.initialValue = wrappedValue
        
        self.name = name
        self.description = description
        self.values = nil
        
        self.detailView = { [weak self] in
            guard let self else { return nil }
            
            let view = detailView(self.valueBinding)
            return view
        }
    }
    
    /// @propertyWrapper
    var projectedValue: Option<Value, DetailView> { self }
    
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
