//
//  ExperimentalFeaturesView.swift
//  Delta
//
//  Created by Riley Testut on 4/5/23.
//  Copyright © 2023 Riley Testut. All rights reserved.
//

import SwiftUI
import Combine

@propertyWrapper
class Feature<T>
{
    var wrappedValue: T
    
    var name: String
    var key: String
    var description: String?
    
    init(name: String, key: String, description: String? = nil) where T == Bool
    {
        self.name = name
        self.key = key
        self.description = description
        
        self.wrappedValue = false
    }
}

class DefaultFeature: ExperimentalFeature, ObservableObject
{
    static var settingsKey: String { "customTintColor" }

    var name: String { NSLocalizedString("Custom Tint Color", comment: "") }
    var description: String? { NSLocalizedString("Change the accent color of Delta.", comment: "") }
}

protocol AnyFeatureSetting<Value>: Identifiable
{
    associatedtype Value
    
    var name: String { get }
    var description: String? { get }
    var key: String { get }
    
    var detailView: () -> AnyView? { get }
    
    var parentFeature: (any ExperimentalFeature)? { get set }
    var wrappedValue: Value { get }
}

extension AnyFeatureSetting
{
    var id: String { key }
}

func makeType<RepresentingType: RawRepresentable, RawType>(_ type: RepresentingType.Type, from rawValue: RawType) -> RepresentingType?
{
    guard let rawValue = rawValue as? RepresentingType.RawValue else { return nil }
    
    let representingValue = RepresentingType.init(rawValue: rawValue)
    return representingValue
}

@propertyWrapper
class FeatureSetting<Value>: AnyFeatureSetting
{
    weak var parentFeature: (any ExperimentalFeature)?
    
    var wrappedValue: Value {
        get {
            let wrappedValue: Value?
            
            guard let rawValue = UserDefaults.standard.object(forKey: self.key) else {
                return self.initialValue
            }

            if let value = rawValue as? Value
            {
                wrappedValue = value
            }
            else if let rawRepresentableType = Value.self as? any RawRepresentable.Type
            {
                let rawRepresentable = makeType(rawRepresentableType, from: rawValue) as! Value
                wrappedValue = rawRepresentable
            }
            else if let codableType = Value.self as? any Codable.Type, let data = rawValue as? Data
            {
                let decodedValue = try? PropertyListDecoder().decode(codableType, from: data) as? Value
                wrappedValue = decodedValue
            }
            else
            {
                wrappedValue = nil
            }
            
            return wrappedValue ?? self.initialValue
        }
        set {
            Task { @MainActor in
                // Delay to avoid "Publishing changes from within view updates is not allowed" runtime warning.
                (self.parentFeature?.objectWillChange as? ObservableObjectPublisher)?.send()
            }
            
            switch newValue
            {
            case let rawRepresentable as any RawRepresentable:
                UserDefaults.standard.set(rawRepresentable.rawValue, forKey: self.key)
                
            case let secureCoding as any NSSecureCoding:
                UserDefaults.standard.set(secureCoding, forKey: self.key)
                
            case let codable as any Codable:
                do
                {
                    let data = try PropertyListEncoder().encode(codable)
                    UserDefaults.standard.set(data, forKey: self.key)
                }
                catch
                {
                    print("Failed to encode FeatureSetting value.", error)
                }
                
            default:
                // Try anyway.
                UserDefaults.standard.set(newValue, forKey: self.key)
            }
        }
    }
    
    private let initialValue: Value
    
    var projectedValue: FeatureSetting<Value> { self }
    
    var name: String
    var description: String?
    var key: String
    
    var detailView: () -> AnyView?
    
    private var valueBinding: Binding<Value> {
        Binding(get: {
            self.wrappedValue
        }, set: {
            self.wrappedValue = $0
        })
    }
    
    init(wrappedValue: Value, name: String, description: String? = nil, key: String)
    {
        self.initialValue = wrappedValue
        
        self.name = name
        self.description = description
        self.key = key
        
        self.detailView = { nil }
    }
    
    init(wrappedValue: Value, name: String, description: String? = nil, key: String, @ViewBuilder detailView: @escaping (Binding<Value>) -> some View)
    {
        self.initialValue = wrappedValue
        
        self.name = name
        self.description = description
        self.key = key
        
        self.detailView = { nil }
        
        self.detailView = {
            let view = detailView(self.valueBinding)
            return AnyView(
                Form {
                    view
                }
            )
        }
    }
}

//typealias AnyExperimentalFeature = (any ExperimentalFeature)

protocol ExperimentalFeature: Identifiable, ObservableObject
{
    static var settingsKey: String { get }

    var name: String { get }
    var description: String? { get }
}

extension ExperimentalFeature
{
    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Self.settingsKey) }
        set {
            (self.objectWillChange as? ObservableObjectPublisher)?.send()
            UserDefaults.standard.set(newValue, forKey: Self.settingsKey)
        }
    }

    var id: String {
        return Self.settingsKey
    }
    
    var settings: [any AnyFeatureSetting] {
        let experimentalFeatures = Mirror(reflecting: self).children.compactMap { [weak self] (child) -> (any AnyFeatureSetting)? in
            guard var setting = child.value as? (any AnyFeatureSetting) else { return nil }
            setting.parentFeature = self
            return setting
        }
        return experimentalFeatures
    }
}


struct ExperimentalFeatures
{
    static let shared = ExperimentalFeatures()
    
    let variableFastForward = VariableFastForward()
    
    let customTintColor = CustomTintColor()
    
//    let allFeatures: [any ExperimentalFeature] = [
//        VariableFastForward()
//    ]
    
    private init()
    {
    }
}

extension ExperimentalFeatures
{
    var allFeatures: [any ExperimentalFeature] {
        let features = Mirror(reflecting: self).children.compactMap { (child) -> (any ExperimentalFeature)? in
            let feature = child.value as? any ExperimentalFeature
            return feature
        }
        return features
    }
}

extension ExperimentalFeaturesView
{
    private class ViewModel: ObservableObject
    {
        @Published
        var experimentalFeatures: [any ExperimentalFeature] = ExperimentalFeatures.shared.allFeatures
        
        init()
        {
        }
    }
}

extension UIImage: ObservableObject {}

struct ExperimentalFeaturesView: View
{
    @StateObject
    private var viewModel = ViewModel()
    
//    @ObservedObject
//    private var experimentalFeatures: ExperimentalFeatures = .shared
    
    var body: some View {
        Form {
            Section(content: {}, footer: {
                Text("These features have been added by contributors to the open-source Delta project on GitHub and are currently being tested before becoming official features. \n\nExpect bugs when using these features.")
                    .font(.subheadline)
            })
            
            ForEach(viewModel.experimentalFeatures, id: \.id) { feature in
                
               section(for: feature)
                
            }
        }
        .listStyle(.insetGrouped)
//        .environmentObject(viewModel)
    }
    
    func section(for feature: any ExperimentalFeature) -> some View
    {
        let view = makeView(for: feature)
        
        return AnyView(view)
    }
    
    func makeView(for feature: some ExperimentalFeature) -> some View
    {
        return ExperimentalFeatureSection(feature: feature)
    }
}

struct ExperimentalFeatureSection<T: ExperimentalFeature>: View
{
    @ObservedObject
    var feature: T
    
    var body: some View {
        Section {
            Toggle(feature.name, isOn: $feature.isEnabled.animation())
            
            if feature.isEnabled//, let settingsName = feature.settingsName, let settingsView = feature.settingsView
            {
                ForEach(feature.settings, id: \.key) { setting in
                    if let detailView = setting.detailView()
                    {
                        NavigationLink(destination: detailView) {
                            HStack {
                                Text(setting.name)
                                Spacer()
                                
                                if let stringConvertible = setting.wrappedValue as? CustomStringConvertible
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

//
//struct FeatureCell: View
//{
//
//}

struct ExperimentalFeaturesView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ExperimentalFeaturesView()
        }
    }
}
