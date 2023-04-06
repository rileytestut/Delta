//
//  ExperimentalFeaturePropertyWrapper.swift
//  Delta
//
//  Created by Riley Testut on 4/6/23.
//  Copyright © 2023 Riley Testut. All rights reserved.
//

import Foundation

#if false

//protocol ExperimentalFeatureProtocol: Identifiable
//{
//    associatedtype Value
//
//    var wrappedValue: Value { get }
//
//    var name: String { get }
//    var description: String? { get }
//    var settingsKey: String { get }
//}
//
//extension ExperimentalFeatureProtocol
//{
//    var id: String { settingsKey }
//}

class AnyExperimentalFeature: ObservableObject, Identifiable
{
    var name: String
    var description: String?
    var settingsKey: String
    
    var id: String { settingsKey }
    
    var settingsName: String?
    var settingsView: AnyView?
    
    @Published
    var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(self.isEnabled, forKey: settingsKey)
            NotificationCenter.default.post(name: .settingsDidChange, object: nil, userInfo: [Settings.NotificationUserInfoKey.name: settingsKey])
        }
    }
    
    fileprivate var isEnabledBinding: Binding<Bool> {
        Binding {
            self.isEnabled
        } set: { newValue in
            self.isEnabled = newValue
        }
    }
    
    init(name: String, description: String? = nil, settingsKey: String, settingsName: String? = nil, settingsView: some View = EmptyView())
    {
        self.name = name
        self.description = description
        self.settingsKey = settingsKey
        self.settingsName = settingsName
        self.settingsView = (settingsView is EmptyView) ? nil : AnyView(settingsView)
        
        self.isEnabled = UserDefaults.standard.bool(forKey: settingsKey)
    }
    
    func underlyingValue() -> Any
    {
        fatalError()
    }
}

@propertyWrapper
class ExperimentalFeature<T>: AnyExperimentalFeature
{
    public var wrappedValue: T {
        get { fatalError("only works on instance properties of classes") }
        set { fatalError("only works on instance properties of classes") }
    }
    
    private var value: T {
        get { UserDefaults.standard.object(forKey: self.settingsKey) as? T ?? self.defaultValue }
        set { UserDefaults.standard.set(newValue, forKey: self.settingsKey) }
    }
    
    public static subscript<OuterSelf: ExperimentalFeatures>(
        _enclosingInstance instance: OuterSelf,
        wrapped wrappedKeyPath: ReferenceWritableKeyPath<OuterSelf, T>,
        storage propertyWrapperKeyPath: ReferenceWritableKeyPath<OuterSelf, ExperimentalFeature<T>>
    ) -> T {
        get {
            instance[keyPath: propertyWrapperKeyPath].value
        }
        set {
//            instance.objectWillChange.send()
            instance[keyPath: propertyWrapperKeyPath].value = newValue
            
            let feature = instance[keyPath: propertyWrapperKeyPath]
            feature.value = newValue
        }
    }
    
    private let defaultValue: T
    
    var projectedValue: ExperimentalFeature<T> { self }
    
    init(wrappedValue: T, name: String, description: String? = nil, settingsKey: String, settingsName: String?, settingsView: some View = EmptyView())
    {
        self.defaultValue = wrappedValue
        
        super.init(name: name, description: description, settingsKey: settingsKey, settingsName: settingsName, settingsView: settingsView)
    }
    
    init(wrappedValue: T, name: String, description: String? = nil, settingsKey: String) where T == Bool
    {
        self.defaultValue = wrappedValue
        
        super.init(name: name, description: description, settingsKey: settingsKey)
    }
    
    override func underlyingValue() -> Any
    {
        return self.wrappedValue
    }
}

struct Setting
{
    var name: String
    var description: String?
    var key: String
}

class ExperimentalFeatures//: ObservableObject
{
    static let shared = ExperimentalFeatures()
    
    @ExperimentalFeature(name: NSLocalizedString("Variable Fast Forward", comment: ""),
                         description: NSLocalizedString("Change your preferred Fast Forward speed.", comment: ""),
                         settingsKey: "variableFastForward",
                         settingsName: NSLocalizedString("Fast Forward Speed", comment: ""),
                         settingsView: VariableFastForwardView())
    var variableFastForward: FastForwardSpeed = .x2
    
    private init()
    {
    }
}

extension ExperimentalFeaturesView
{
    private class ViewModel: ObservableObject
    {
        @Published
        var experimentalFeatures: [AnyExperimentalFeature]
        
        init()
        {
            let experimentalFeatures = Mirror(reflecting: ExperimentalFeatures.shared).children.compactMap { (child) -> AnyExperimentalFeature? in
                guard let experimentalFeature = child.value as? AnyExperimentalFeature else { return nil }
                return experimentalFeature
            }
                        
            self.experimentalFeatures = experimentalFeatures
        }
    }
}

#endif
