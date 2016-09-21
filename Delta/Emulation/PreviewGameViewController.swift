//
//  PreviewGameViewController.swift
//  Delta
//
//  Created by Riley Testut on 8/11/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import UIKit

import DeltaCore

private var kvoContext = 0

class PreviewGameViewController: DeltaCore.GameViewController
{
    // If non-nil, will override the default preview action items returned in previewActionItems()
    var overridePreviewActionItems: [UIPreviewActionItem]?
    
    // Save state to be loaded upon preview
    var previewSaveState: SaveStateProtocol?
    
    // Initial image to be shown while loading
    var previewImage: UIImage? {
        didSet {
            self.updatePreviewImage()
        }
    }
    
    fileprivate var emulatorCoreQueue = DispatchQueue(label: "com.rileytestut.Delta.PreviewGameViewController.emulatorCoreQueue", qos: .userInitiated)
    
    override var game: GameProtocol? {
        willSet {
            self.emulatorCore?.removeObserver(self, forKeyPath: #keyPath(EmulatorCore.state), context: &kvoContext)
        }
        didSet {
            guard let emulatorCore = self.emulatorCore else {
                self.preferredContentSize = CGSize.zero
                return
            }
            
            emulatorCore.addObserver(self, forKeyPath: #keyPath(EmulatorCore.state), options: [.old], context: &kvoContext)
            
            self.preferredContentSize = emulatorCore.preferredRenderingSize
        }
    }
    
    override var previewActionItems: [UIPreviewActionItem] {
        guard let previewActionItems = self.overridePreviewActionItems else { return [] }
        return previewActionItems
    }
    
    deinit
    {
        self.emulatorCore?.removeObserver(self, forKeyPath: #keyPath(EmulatorCore.state), context: &kvoContext)
    }
}

//MARK: - UIViewController -
/// UIViewController
extension PreviewGameViewController
{
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.controllerView.isHidden = true
        
        // Temporarily prevent emulatorCore from updating gameView to prevent flicker of black, or other visual glitches
        self.emulatorCore?.remove(self.gameView)
    }

    override func viewDidAppear(_ animated: Bool)
    {
        super.viewDidAppear(animated)
        
        self.emulatorCoreQueue.async {
            self.emulatorCore?.resume()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool)
    {
        super.viewWillDisappear(animated)
        
        // Pause in viewWillDisappear and not viewDidDisappear like DeltaCore.GameViewController so the audio cuts off earlier if being dismissed
        self.emulatorCore?.pause()
    }
    
    override func viewDidLayoutSubviews()
    {
        super.viewDidLayoutSubviews()
        
        // Need to update in viewDidLayoutSubviews() to ensure bounds of gameView are not CGRect.zero
        self.updatePreviewImage()
    }

    override func didReceiveMemoryWarning()
    {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?)
    {
        guard context == &kvoContext else { return super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context) }
        
        guard
            let rawValue = change?[.oldKey] as? Int,
            let previousState = EmulatorCore.State(rawValue: rawValue),
            let state = self.emulatorCore?.state
        else { return }
        
        if previousState == .stopped, state == .running
        {
            self.emulatorCoreQueue.sync {
                if self.isAppearing
                {
                    // Pause to prevent it from starting before visible (in case user peeked slowly)
                    self.emulatorCore?.pause()
                }
                
                self.preparePreview()
            }
        }
    }
}

//MARK: - Private -
private extension PreviewGameViewController
{
    func updatePreviewImage()
    {        
        if let previewImage = self.previewImage
        {
            self.gameView?.inputImage = CIImage(image: previewImage)
        }
        else
        {
            self.gameView?.inputImage = nil
        }
    }
    
    func preparePreview()
    {
        var previewSaveState = self.previewSaveState
        
        if let saveState = self.previewSaveState as? SaveState
        {
            saveState.managedObjectContext?.performAndWait {
                previewSaveState = DeltaCore.SaveState(fileURL: saveState.fileURL, gameType: saveState.gameType)
            }
        }
        
        if let saveState = previewSaveState
        {
            do
            {
                try self.emulatorCore?.load(saveState)
            }
            catch EmulatorCore.SaveStateError.doesNotExist
            {
                print("Save State does not exist.")
            }
            catch
            {
                print(error)
            }
        }
        
        self.emulatorCore?.updateCheats()
        
        // Re-enable emulatorCore to update gameView again
        self.emulatorCore?.add(self.gameView)
    }
}
