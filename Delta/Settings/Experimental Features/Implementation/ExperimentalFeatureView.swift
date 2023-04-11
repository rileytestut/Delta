//
//  ExperimentalFeatureView.swift
//  Delta
//
//  Created by Riley Testut on 4/10/23.
//  Copyright © 2023 Riley Testut. All rights reserved.
//

import SwiftUI

func double<T: AnyOption>(_ number: T) {
    print(number)
}

//func test()
//{
//    let feature = ExperimentalFeatures.shared.variableFastForward
//    ForEach(feature.allOptions, id: \.key) { option -> AnyView in
//        let opt = option as! any AnyOption
//        AnyView(optionView(opt))
//    }
//}

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
    
    private func optionView(_ option: any AnyOption) -> AnyView
    {
        @ViewBuilder
        func unwrap<T: AnyOption>(_ option: T) -> some View
        {
            // Only show if option has a name and detailView.
            if let name = option.name, let detailView = option.detailView(), let value = option.wrappedValue as? any LocalizedOptionValue
            {
                if option.values != nil
                {
                    // Display picker inline.
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
                }
            }
        }
        
        return AnyView(unwrap(option))
    }
}

struct ExperimentalFeatureView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ExperimentalFeatureView(feature: ExperimentalFeatures.shared.variableFastForward)
        }
    }
}
