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
        if ExperimentalFeatures.shared.skinDebugging.isEnabled && ExperimentalFeatures.shared.skinDebugging.showHitTargets
        {
            return true
        }
        
        // Fall back to skin if showHitTargets is not explicitly enabled.
        return self.controllerSkin?.isDebugModeEnabled ?? false
    }
    
    // Transient, not persisted to Core Data.
    public var isReversingScreens: Bool = false
    
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
        guard var items = self.controllerSkin?.items(for: traits) else { return nil }
        
        if ExperimentalFeatures.shared.skinDebugging.isEnabled && ExperimentalFeatures.shared.skinDebugging.ignoreExtendedEdges
        {
            items = items.map { item in
                var item = item
                item.extendedFrame = item.frame
                return item
            }
        }
        
        if ExperimentalFeatures.shared.reverseScreens.isEnabled, self.isReversingScreens, let screens = self.controllerSkin?.screens(for: traits), let reversedScreens = self.screens(for: traits)
        {
            //TODO: Handle touch screen inputs that only partially cover touch screen.
            
            items = items.map { item in
                var item = item
                guard item.kind == .touchScreen else { return item }
                
                // Find the original screen this input is paired with.
                let touchScreen = screens.first(where: { screen in
                    guard screen.placement == item.placement else { return false }
                    guard let outputFrame = screen.outputFrame else { return false }
                    return outputFrame == item.frame || outputFrame.intersects(item.frame) // Compare exact match in case outputFrame is empty rectangle.
                })
                
                // Find original screen in reversedScreens and use its new adjusted values.
                if let touchScreen, let movedTouchScreen = reversedScreens.first(where: { $0.id == touchScreen.id })
                {
                    if let outputFrame = movedTouchScreen.outputFrame
                    {
                        // Set properties to match other screen.
                        item.frame = outputFrame
                        item.extendedFrame = outputFrame
                        item.placement = movedTouchScreen.placement
                    }
                    else
                    {
                        // Assume this is using app placement.
                        item.frame = CGRect(x: 0, y: 0, width: 1.0, height: 1.0)
                        item.extendedFrame = item.frame
                        item.placement = .app
                    }
                }
                
                return item
            }
        }
        
        return items
    }
    
    public func isTranslucent(for traits: DeltaCore.ControllerSkin.Traits) -> Bool?
    {
        return self.controllerSkin?.isTranslucent(for: traits)
    }
    
    public func screens(for traits: DeltaCore.ControllerSkin.Traits) -> [DeltaCore.ControllerSkin.Screen]?
    {
        guard var screens = self.controllerSkin?.screens(for: traits) else { return nil }
        
        if ExperimentalFeatures.shared.reverseScreens.isEnabled, self.isReversingScreens
        {
            // Reverse order of ids and inputFrames, but leave other properties in same order.
            // This effectively switches out inputFrames without changing the actual screen placements.
            
            let reversedInputFramesAndIDs = Array(screens.lazy.map { ($0.inputFrame, $0.id) }.reversed())
            screens = zip(0..., screens).map { (index, screen) in
                let (inputFrame, id) = reversedInputFramesAndIDs[index]
                
                var screen = screen
                screen.inputFrame = inputFrame
                screen.id = id
                return screen
            }
        }
        
        return screens
    }
    
    public func aspectRatio(for traits: DeltaCore.ControllerSkin.Traits) -> CGSize?
    {
        return self.controllerSkin?.aspectRatio(for: traits)
    }
    
    public func contentSize(for traits: DeltaCore.ControllerSkin.Traits) -> CGSize?
    {
        if let contentSize = self.controllerSkin?.contentSize(for: traits)
        {
            return contentSize
        }
        
        if ExperimentalFeatures.shared.reverseScreens.isEnabled, self.isReversingScreens, let screen = self.screens(for: traits)?.first(where: { $0.placement == .app }), screen.outputFrame == nil
        {
            // Dynamic screen, so return inputFrame as contentSize to ensure touch screen matches frame.
            return screen.inputFrame?.size
        }
        
        return nil
    }
    
    public func menuInsets(for traits: DeltaCore.ControllerSkin.Traits) -> UIEdgeInsets?
    {
        return self.controllerSkin?.menuInsets(for: traits)
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
    
    public func resolveConflict(_ record: AnyRecord) -> ConflictResolution
    {
        return .newest
    }
}
