//
//  CoverView.swift
//  Delta
//
//  Created by Riley Testut on 10/10/26.
//  Copyright © 2026 Riley Testut. All rights reserved.
//

import UIKit

import DeltaCore
import MelonDSDeltaCore

protocol CoverViewDelegate: AnyObject
{
    func coverViewWillShowCover(_ coverView: CoverView)
    func coverViewDidHideCover(_ coverView: CoverView)
}

extension CoverViewDelegate
{
    func coverViewWillShowCover(_ coverView: CoverView) {}
    func coverViewDidHideCover(_ coverView: CoverView) {}
}

class CoverView: UIView
{
    let controllerSkin: any ControllerSkinProtocol
    
    // Keep the selected skin separate from the standard skin used as a cover fallback.
    // Third-party skins may have no .cover representation.
    var decorativeSkin: (any ControllerSkinProtocol)? {
        didSet { self.updateImage() }
    }

    weak var delegate: CoverViewDelegate?
    
    private(set) var isCoverHidden: Bool = false
    
    private let imageView: UIImageView
    
    init(controllerSkin: some ControllerSkinProtocol, decorativeSkin: (any ControllerSkinProtocol)? = nil)
    {
        self.controllerSkin = controllerSkin
        self.decorativeSkin = decorativeSkin
        
        self.imageView = UIImageView(frame: .zero)
        self.imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        super.init(frame: .zero)
        
        self.addSubview(self.imageView)
        NotificationCenter.default.addObserver(self, selector: #selector(CoverView.lidSettingsDidChange(_:)), name: Settings.didChangeNotification, object: nil)
        
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(CoverView.handleTapGesture(_:)))
        self.addGestureRecognizer(tapGestureRecognizer)
        
        NotificationCenter.default.addObserver(self, selector: #selector(CoverView.batteryStateDidChange(_:)), name: UIDevice.batteryStateDidChangeNotification, object: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews()
    {
        super.layoutSubviews()
        
        let coverFrame: CGRect = if self.isCoverHidden {
            CGRect(x: 0, y: -self.bounds.height, width: self.bounds.width, height: self.bounds.height)
        } else {
            CGRect(x: 0, y: 0, width: self.bounds.width, height: self.bounds.height)
        }
        
        self.imageView.frame = coverFrame
    }
    
    override func didMoveToWindow()
    {
        super.didMoveToWindow()
        
        if self.window == nil
        {
            // Disable battery monitoring
            UIDevice.current.isBatteryMonitoringEnabled = false
        }
        else
        {
            // Enable battery monitoring
            UIDevice.current.isBatteryMonitoringEnabled = true
        }
        
        self.updateImage()
    }
}

extension CoverView
{
    func showCover(animated: Bool = true)
    {
        guard self.isCoverHidden else { return }
        self.isCoverHidden = false
        
        self.setNeedsLayout()
        
        self.delegate?.coverViewWillShowCover(self)
                
        if animated
        {
            let animator = UIViewPropertyAnimator(springTimingParameters: UISpringTimingParameters())
            animator.addAnimations {
                self.layoutIfNeeded()
            }
            animator.startAnimation()
        }
        else
        {
            self.layoutIfNeeded()
        }
    }
    
    func hideCover(animated: Bool = true)
    {
        guard !self.isCoverHidden else { return }
        self.isCoverHidden = true
        
        self.setNeedsLayout()
        
        if animated
        {
            let animator = UIViewPropertyAnimator(springTimingParameters: UISpringTimingParameters())
            animator.addAnimations {
                self.layoutIfNeeded()
            }
            animator.addCompletion { _ in
                self.delegate?.coverViewDidHideCover(self)
            }
            
            animator.startAnimation()
        }
        else
        {
            self.layoutIfNeeded()
            self.delegate?.coverViewDidHideCover(self)
        }
    }
}

private extension CoverView
{
    func updateImage()
    {
        guard let window else { return }
        
        let isCharging: Bool
        
        switch UIDevice.current.batteryState
        {
        case .charging, .full: isCharging = true
        case .unknown, .unplugged: isCharging = false
        @unknown default: isCharging = false
        }
        
        if LidCoverStore.isEnabled, let skin = self.decorativeSkin, skin.gameType == .ds
        {
            if let image = LidCoverStore.image(for: skin.identifier)
            {
                self.imageView.backgroundColor = .black
                self.imageView.clipsToBounds = true
                self.imageView.contentMode = .scaleAspectFill
                self.imageView.image = image
                return
            }

            self.imageView.backgroundColor = .clear
            self.imageView.clipsToBounds = false
            self.imageView.contentMode = .scaleToFill
            self.imageView.image = LidCoverStore.skinImage(for: skin, isCharging: isCharging)
            return
        }

        self.imageView.backgroundColor = .clear
        self.imageView.clipsToBounds = false
        self.imageView.contentMode = .scaleToFill
        var traits = DeltaCore.ControllerSkin.Traits.defaults(for: window)
        traits.displayType = .cover
        traits.orientation = .landscape
        
        if isCharging, let image = self.controllerSkin.pressedImage(for: traits, preferredSize: .large)
        {
            self.imageView.image = image
        }
        else
        {
            let image = self.controllerSkin.image(for: traits, preferredSize: .large)
            self.imageView.image = image
        }
    }
}

private extension CoverView
{
    @objc func handleTapGesture(_ gestureRecognizer: UITapGestureRecognizer)
    {
        if self.isCoverHidden
        {
            self.showCover()
        }
        else
        {
            self.hideCover()
        }
    }
    
    @objc func lidSettingsDidChange(_ notification: Notification)
    {
        guard let name = notification.userInfo?[Settings.NotificationUserInfoKey.name] as? Settings.Name,
              name == ExperimentalFeatures.shared.decorativeLidCovers.settingsKey || name == ExperimentalFeatures.shared.decorativeLidCovers.$selections.settingsKey else { return }
        self.updateImage()
    }

    @objc func batteryStateDidChange(_ notification: Notification)
    {
        self.updateImage()
    }
}

#Preview {
    Delta.register(MelonDS.core)
    
    let controllerSkin = DeltaCore.ControllerSkin.standardControllerSkin(for: .ds)!
    return CoverView(controllerSkin: controllerSkin)
}
