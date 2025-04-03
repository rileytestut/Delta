//
//  FeatureDetailView.swift
//  Delta
//
//  Created by Riley Testut on 4/10/23.
//  Copyright © 2023 Riley Testut. All rights reserved.
//

import SwiftUI

import DeltaFeatures

struct FeatureDetailView<Feature: AnyFeature>: View
{
    @ObservedObject
    var feature: Feature
    
    var body: some View {
        Form {
            if !PurchaseManager.shared.isExperimentalFeaturesAvailable
            {
                Section {
                } header: {
                    BecomePatronButton()
                }
            }
            
            Section {
                Toggle(isOn: $feature.isEnabled.animation()) {
                    Text(feature.name)
                        .bold()
                        .foregroundColor(PurchaseManager.shared.isExperimentalFeaturesAvailable ? .primary : .secondary)
                }
                .disabled(!PurchaseManager.shared.isExperimentalFeaturesAvailable)
            } footer: {
                if let description = feature.description, let detailedDescription = feature.detailedDescription
                {
                    Text(description) + Text("\n\n") + Text(detailedDescription)
                }
                else if let description = feature.description
                {
                    Text(description)
                }
                else if let detailedDescription = feature.detailedDescription
                {
                    Text(detailedDescription)
                }
            }
            
            if feature.isEnabled
            {
                ForEach(feature.allOptions, id: \.key) { option in
                    if let optionView = optionView(option)
                    {
                        Section {
                            optionView
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
    
    // Cannot open existential if return type uses concrete type T in non-covariant position (e.g. Box<T>).
    // So instead we erase return type to AnyView.
    private func optionView<T: AnyOption>(_ option: T) -> AnyView?
    {
        guard let view = OptionRow(option: option) else { return nil }
        return AnyView(view)
    }
}

private struct OptionRow<Option: AnyOption, DetailView: View>: View where DetailView == Option.DetailView
{
    let name: LocalizedStringKey
    let value: any LocalizedOptionValue
    let detailView: DetailView
    
    let option: Option
    
    @State
    private var displayInline: Bool = false
    
    init?(option: Option)
    {
        // Only show if option has a name, localizable value, and detailView.
        guard
            let name = option.name,
            let value = option.value as? any LocalizedOptionValue,
            let detailView = option.detailView()
        else { return nil }
        
        self.name = name
        self.value = value
        self.detailView = detailView
        
        self.option = option
    }
    
    var body: some View {
        VStack {
            let detailView = detailView
                .environment(\.managedObjectContext, DatabaseManager.shared.viewContext)
                .environment(\.featureOption, option)
            
            if displayInline
            {
                // Display entire view inline.
                detailView
            }
            else
            {
                NavigationLink(destination: wrap(detailView)) {
                    HStack {
                        Text(name)
                        Spacer()

                        value.localizedDescription
                            .foregroundColor(.secondary)
                    }
                }
                .overlay(
                    // Hack to ensure displayInline preference is in View hierarchy.
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
    
    func wrap(_ detailView: some View) -> AnyView
    {
        let wrappedDetailView: AnyView
        
        if self.detailView is any UIViewControllerRepresentable
        {
            wrappedDetailView = AnyView(detailView.ignoresSafeArea())
        }
        else
        {
            let form = Form {
                detailView
            }
            
            wrappedDetailView = AnyView(form)
        }
        
        return wrappedDetailView
    }
}
