//
//  ControllerSkin.swift
//  Delta
//
//  Created by Riley Testut on 8/30/16.
//  Copyright (c) 2016 Riley Testut. All rights reserved.
//

import Foundation

import DeltaCore
import Harmony

extension ControllerSkinConfigurations
{
    init?(traits: DeltaCore.ControllerSkin.Traits)
    {
        switch (traits.device, traits.displayType, traits.orientation)
        {
        case (.iphone, .standard, .portrait): self = .iphoneStandardPortrait
        case (.iphone, .standard, .landscape): self = .iphoneStandardLandscape
        case (.iphone, .edgeToEdge, .portrait): self = .iphoneEdgeToEdgePortrait
        case (.iphone, .edgeToEdge, .landscape): self = .iphoneEdgeToEdgeLandscape
        case (.iphone, .splitView, _): return nil
            
        case (.ipad, .standard, .portrait): self = .ipadStandardPortrait
        case (.ipad, .standard, .landscape): self = .ipadStandardLandscape
        case (.ipad, .edgeToEdge, .portrait): self = .ipadEdgeToEdgePortrait
        case (.ipad, .edgeToEdge, .landscape): self = .ipadEdgeToEdgeLandscape
        case (.ipad, .splitView, .portrait): self = .ipadSplitViewPortrait
        case (.ipad, .splitView, .landscape): self = .ipadSplitViewLandscape
            
        case (.tv, .standard, .portrait): self = .tvStandardPortrait
        case (.tv, .standard, .landscape): self = .tvStandardLandscape
        case (.tv, .edgeToEdge, _): return nil
        case (.tv, .splitView, _): return nil
        }
    }
}

@objc(ControllerSkin)
public class ControllerSkin: _ControllerSkin
{
    public var fileURL: URL {
        let fileURL = self.isStandard ? self.controllerSkin!.fileURL : DatabaseManager.controllerSkinsDirectoryURL(for: self.gameType).appendingPathComponent(self.filename)
        return fileURL
    }
    
    public var isDebugModeEnabled: Bool {
        return self.controllerSkin?.isDebugModeEnabled ?? false
    }
    
    private lazy var controllerSkin: DeltaCore.ControllerSkin? = {
        let controllerSkin = self.isStandard ? DeltaCore.ControllerSkin.standardControllerSkin(for: self.gameType) : DeltaCore.ControllerSkin(fileURL: self.fileURL)
        return controllerSkin
    }()
    
    public override func awakeFromFetch()
    {
        super.awakeFromFetch()
        
        // Kinda hacky, but we initialize controllerSkin on fetch to ensure it is initialized on the correct thread
        // We could solve this by wrapping controllerSkin.getter in performAndWait block, but this can lead to a deadlock
        _ = self.controllerSkin
    }
}

extension ControllerSkin: ControllerSkinProtocol
{
    public func supports(_ traits: DeltaCore.ControllerSkin.Traits) -> Bool
    {
        return self.controllerSkin?.supports(traits) ?? false
    }
    
    public func image(for traits: DeltaCore.ControllerSkin.Traits, preferredSize: DeltaCore.ControllerSkin.Size) -> UIImage?
    {
        return self.controllerSkin?.image(for: traits, preferredSize: preferredSize)
    }
    
    public func thumbstick(for item: DeltaCore.ControllerSkin.Item, traits: DeltaCore.ControllerSkin.Traits, preferredSize: DeltaCore.ControllerSkin.Size) -> (UIImage, CGSize)?
    {
        return self.controllerSkin?.thumbstick(for: item, traits: traits, preferredSize: preferredSize)
    }
    
    public func items(for traits: DeltaCore.ControllerSkin.Traits) -> [DeltaCore.ControllerSkin.Item]?
    {
        return self.controllerSkin?.items(for: traits)
    }
    
    public func isTranslucent(for traits: DeltaCore.ControllerSkin.Traits) -> Bool?
    {
        return self.controllerSkin?.isTranslucent(for: traits)
    }
    
    public func screens(for traits: DeltaCore.ControllerSkin.Traits) -> [DeltaCore.ControllerSkin.Screen]?
    {
        return self.controllerSkin?.screens(for: traits)
    }
    
    public func aspectRatio(for traits: DeltaCore.ControllerSkin.Traits) -> CGSize?
    {
        return self.controllerSkin?.aspectRatio(for: traits)
    }
    
    public func contentSize(for traits: DeltaCore.ControllerSkin.Traits) -> CGSize?
    {
        return self.controllerSkin?.contentSize(for: traits)
    }
}

extension ControllerSkin: Syncable
{
    public static var syncablePrimaryKey: AnyKeyPath {
        return \ControllerSkin.identifier
    }
    
    public var syncableKeys: Set<AnyKeyPath> {
        return [\ControllerSkin.filename, \ControllerSkin.gameType, \ControllerSkin.name, \ControllerSkin.supportedConfigurations]
    }
    
    public var syncableFiles: Set<File> {
        return [File(identifier: "skin", fileURL: self.fileURL)]
    }
    
    public var isSyncingEnabled: Bool {
        return !self.isStandard
    }
    
    public var syncableLocalizedName: String? {
        return self.name
    }
}
