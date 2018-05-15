//
//  ControllerSkin.swift
//  Delta
//
//  Created by Riley Testut on 8/30/16.
//  Copyright (c) 2016 Riley Testut. All rights reserved.
//

import Foundation

import DeltaCore

extension ControllerSkinConfigurations
{
    init(traits: DeltaCore.ControllerSkin.Traits)
    {
        switch traits.deviceType
        {
        case .iphone:
            
            switch traits.orientation
            {
            case .portrait: self = .fullScreenPortrait
            case .landscape: self = .fullScreenLandscape
            }
            
        case .ipad:
            
            switch traits.displayMode
            {
            case .fullScreen:
                
                switch traits.orientation
                {
                case .portrait: self = .fullScreenPortrait
                case .landscape: self = .fullScreenLandscape
                }
                
            case .splitView:
                
                switch traits.orientation
                {
                case .portrait: self = .splitViewPortrait
                case .landscape: self = .splitViewLandscape
                }
            }
            
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
    
    public func inputs(for traits: DeltaCore.ControllerSkin.Traits, at point: CGPoint) -> [Input]?
    {
        return self.controllerSkin?.inputs(for: traits, at: point)
    }
    
    public func items(for traits: DeltaCore.ControllerSkin.Traits) -> [DeltaCore.ControllerSkin.Item]?
    {
        return self.controllerSkin?.items(for: traits)
    }
    
    public func isTranslucent(for traits: DeltaCore.ControllerSkin.Traits) -> Bool?
    {
        return self.controllerSkin?.isTranslucent(for: traits)
    }
    
    public func gameScreenFrame(for traits: DeltaCore.ControllerSkin.Traits) -> CGRect?
    {
        return self.controllerSkin?.gameScreenFrame(for: traits)
    }
    
    public func aspectRatio(for traits: DeltaCore.ControllerSkin.Traits) -> CGSize?
    {
        return self.controllerSkin?.aspectRatio(for: traits)
    }
}
