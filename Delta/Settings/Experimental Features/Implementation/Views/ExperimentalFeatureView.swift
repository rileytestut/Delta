//
//  ExperimentalFeatureView.swift
//  Delta
//
//  Created by Riley Testut on 4/10/23.
//  Copyright © 2023 Riley Testut. All rights reserved.
//

import SwiftUI

import DeltaFeatures

struct ExperimentalFeatureView<Feature: AnyFeature>: View
{
    @ObservedObject
    var feature: Feature
    
    var body: some View {
        Form {
            Section {
                Toggle(isOn: $feature.isEnabled.animation()) {
                    Text(feature.name)
                        .bold()
                }
            } footer: {
                if let description = feature.description
                {
                    Text(description)
                }
            }
            
            if feature.isEnabled
            {
                ForEach(feature.allOptions, id: \.key) { option in
                    
                    // Only show options with non-nil names.
                    if option.name != nil
                    {
                        Section {
                            optionView(option)
                        } footer: {
                            if let description = option.description
                            {
                                Text(description)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func optionView(_ option: any AnyOption) -> some View
    {
        func unwrap<T: AnyOption>(_ option: T) -> some View
        {
            OptionRow(option: option)
        }
        
        // Must use concrete AnyView type to return `some View`.
        return AnyView(unwrap(option))
    }
}

struct OptionRow<Option: AnyOption, DetailView: View>: View where DetailView == Option.DetailView
{
    var name: LocalizedStringKey
    var value: any LocalizedOptionValue
    var detailView: DetailView
    
    @State
    private var displayInline: Bool = false
    
    init?(option: Option)
    {
        // Only show if option has a name, localizable value, and detailView.
        guard
            let name = option.name,
            let value = option.wrappedValue as? any LocalizedOptionValue,
            let detailView = option.detailView()
        else { return nil }
        
        self.name = name
        self.value = value
        self.detailView = detailView
    }
    
    var body: some View {
        VStack {
            if displayInline
            {
                // Display entire view inline.
                detailView
            }
            else
            {
                let wrappedDetailView = Form {
                    detailView
                }

                NavigationLink(destination: wrappedDetailView) {
                    HStack {
                        Text(name)
                        Spacer()

                        value.localizedDescription
                            .foregroundColor(.secondary)
                    }
                }
                .overlay(
                    detailView
                        .hidden()
                        .frame(width: 0, height: 0)
                )
            }
        }
        .onPreferenceChange(DisplayInlineKey.self) { displayInline in
            self.displayInline = displayInline
        }
    }
}

struct ExperimentalFeatureView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ExperimentalFeatureView(feature: ExperimentalFeatures.shared.variableFastForward)
        }
    }
}
