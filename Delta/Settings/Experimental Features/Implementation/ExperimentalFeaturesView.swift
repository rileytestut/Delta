//
//  ExperimentalFeaturesView.swift
//  Delta
//
//  Created by Riley Testut on 4/5/23.
//  Copyright © 2023 Riley Testut. All rights reserved.
//

import SwiftUI
import Combine

struct ExperimentalFeaturesView: View
{
    var body: some View {
        Form {
            Section(content: {}, footer: {
                Text("These features have been added by contributors to the open-source Delta project on GitHub and are currently being tested before becoming official features. \n\nExpect bugs when using these features.")
                    .font(.subheadline)
            })
            
            ForEach(ExperimentalFeatures.shared.allFeatures) { feature in
                ExperimentalFeatureSection(feature: feature)
            }
        }
        .listStyle(.insetGrouped)
    }
}

struct ExperimentalFeatureSection<T: AnyFeature>: View
{
    @ObservedObject
    var feature: T
    
    var body: some View {
        Section {
            Toggle(feature.name, isOn: $feature.isEnabled.animation())

            if feature.isEnabled
            {
                ForEach(feature.allOptions, id: \.key) { option in
                    // Only show if option has a name and detailView.
                    if let name = option.name, let detailView = option.detailView()
                    {
                        NavigationLink(destination: detailView) {
                            HStack {
                                Text(name)
                                Spacer()
                                
                                if let localizedValue = option.wrappedValue as? LocalizedOptionValue
                                {
                                    localizedValue.localizedDescription
                                        .foregroundColor(.secondary)
                                }
                                else if let stringConvertible = option.wrappedValue as? CustomStringConvertible
                                {
                                    Text(stringConvertible.description)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            
        } footer: {
            if let description = feature.description
            {
                Text(description)
            }
        }
    }
}

extension ExperimentalFeaturesView
{
    static func makeViewController() -> UIHostingController<some View>
    {
        let experimentalFeaturesView = ExperimentalFeaturesView()
        
        let hostingController = UIHostingController(rootView: experimentalFeaturesView)
        hostingController.title = NSLocalizedString("Experimental Features", comment: "")
        return hostingController
    }
}

struct ExperimentalFeaturesView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ExperimentalFeaturesView()
        }
    }
}
