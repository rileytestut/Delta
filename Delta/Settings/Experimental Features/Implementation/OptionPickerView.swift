//
//  OptionPickerView.swift
//  Delta
//
//  Created by Riley Testut on 4/10/23.
//  Copyright © 2023 Riley Testut. All rights reserved.
//

import SwiftUI

protocol OptionValue
{
}

extension String: OptionValue {}
extension Double: OptionValue {}
extension Optional: OptionValue where Wrapped: OptionValue {}
extension Dictionary: OptionValue where Key: OptionValue, Value: OptionValue {}

protocol LocalizedOptionValue: OptionValue, Hashable
{
    associatedtype ID: Hashable
    
    var identifier: ID { get }
    var localizedDescription: Text { get }
}

extension LocalizedOptionValue
{
    var identifier: Self {
        return self
    }
}

extension LocalizedOptionValue where Self: CustomStringConvertible
{
    var localizedDescription: Text {
        return Text(String(describing: self))
    }
}

extension LocalizedOptionValue where Self: Identifiable
{
    var identifier: ID {
        return self.id
    }
}

extension Optional: LocalizedOptionValue where Wrapped: LocalizedOptionValue
{
    var localizedDescription: Text {
        switch self
        {
        case .none: return Text("None")
        case .some(let value): return value.localizedDescription
        }
    }
}

struct OptionPickerView<Value: LocalizedOptionValue>: View
{
    var name: LocalizedStringKey
    var options: [Value]
    
    @Binding
    var selectedValue: Value

    var body: some View {
        Picker(name, selection: $selectedValue) {
            ForEach(options, id: \.identifier) { value in
                value.localizedDescription
            }
        }
        .pickerStyle(.menu)
    }
}

struct OptionPickerView_Previews: PreviewProvider {
    static var previews: some View {
        let values = TintColor.allCases
        
        return Form {
            OptionPickerView(name: "Tint Color", options: values, selectedValue: .constant(values[0]))
        }
    }
}
