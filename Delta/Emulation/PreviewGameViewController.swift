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
    
    var isLivePreview: Bool = true
    
    private var emulatorCoreQueue = DispatchQueue(label: "com.rileytestut.Delta.PreviewGameViewController.emulatorCoreQueue", qos: .userInitiated)
    private var copiedSaveFiles = [(originalURL: URL, copyURL: URL)]()
    
    private lazy var temporaryDirectoryURL: URL = {
        let directoryURL = FileManager.default.temporaryDirectory.appendingPathComponent("preview-" + UUID().uuidString)
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
        return directoryURL
    }()
    
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
            
            let size = CGSize(width: emulatorCore.preferredRenderingSize.width * 2.0, height: emulatorCore.preferredRenderingSize.height * 2.0)
            self.preferredContentSize = size
        }
    }
    
    override var previewActionItems: [UIPreviewActionItem] {
        guard let previewActionItems = self.overridePreviewActionItems else { return [] }
        return previewActionItems
    }
    
    public required init()
    {
        super.init()
        
        self.delegate = self
    }
    
    public required init?(coder aDecoder: NSCoder)
    {
        super.init(coder: aDecoder)
        
        self.delegate = self
    }
    
    deinit
    {
        
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
        self.controllerView.controllerSkin = nil // Skip loading controller skin from disk, which may be slow.
        
        // Temporarily prevent emulatorCore from updating gameView to prevent flicker of black, or other visual glitches
        self.emulatorCore?.remove(self.gameView)
        
        self.emulatorCore?.audioManager.respectsSilentMode = Settings.respectSilentMode
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        
        self.copySaveFiles()
    }

    override func viewDidAppear(_ animated: Bool)
    {
        super.viewDidAppear(animated)
        
        self.emulatorCoreQueue.async {
            self.startEmulation()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool)
    {
        super.viewWillDisappear(animated)
        
        // Pause in viewWillDisappear and not viewDidDisappear like DeltaCore.GameViewController so the audio cuts off earlier if being dismissed
        self.emulatorCore?.pause()
    }
    
    override func viewDidDisappear(_ animated: Bool)
    {
        super.viewDidDisappear(animated)
        
        func reset()
        {
            // Assign game to nil to ensure we deallocate emulatorCore + audio/video managers.
            // Otherwise, we may crash when opening N64 games in new window due to race condition.
            // Also dispatch to main queue because we update self.preferredContentSize.
            DispatchQueue.main.async {
                self.game = nil
            }
        }
        
        // Already stopped = we've already restored save files and removed directory.
        if self.emulatorCore?.state != .stopped
        {
            // Pre-emptively restore save files in case something goes wrong while stopping emulation.
            // This also ensures if the core is never stopped (for some reason), saves are still restored.
            self.restoreSaveFiles(removeCopyDirectory: false)
            
            self.emulatorCoreQueue.async {
                // Explicitly stop emulatorCore _before_ we remove ourselves as observer
                // so we can wait until stopped before restoring save files (again).
                self.emulatorCore?.stop()
                reset()
            }
        }
        else
        {
            reset()
        }
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
        
        switch state
        {
        case .running where previousState == .stopped:
            self.emulatorCoreQueue.async {
                // Pause to prevent it from starting before visible (in case user peeked slowly)
                self.emulatorCore?.pause()
                self.preparePreview()
            }
            
        case .stopped:
            // Emulation has stopped, so we can safely restore save files,
            // and also remove the directory they were copied to.
            self.restoreSaveFiles(removeCopyDirectory: true)
            
        default: break
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
        
        self.emulatorCore?.resume()
    }
    
    func copySaveFiles()
    {
        guard let game = self.game as? Game, let gameSave = game.gameSave else { return }
        
        self.copiedSaveFiles.removeAll()
        
        let fileURLs = gameSave.syncableFiles.lazy.map { $0.fileURL }
        for fileURL in fileURLs
        {
            do
            {
                let destinationURL = self.temporaryDirectoryURL.appendingPathComponent(fileURL.lastPathComponent)
                try FileManager.default.copyItem(at: fileURL, to: destinationURL, shouldReplace: true)
                
                self.copiedSaveFiles.append((fileURL, destinationURL))
                print("Copied save file:", fileURL.lastPathComponent)
            }
            catch
            {
                print("Failed to back up save file \(fileURL.lastPathComponent).", error)
            }
        }
    }
    
    func restoreSaveFiles(removeCopyDirectory: Bool)
    {
        for (originalURL, copyURL) in self.copiedSaveFiles
        {
            do
            {
                try FileManager.default.copyItem(at: copyURL, to: originalURL, shouldReplace: true)
                print("Restored save file:", originalURL.lastPathComponent)
            }
            catch
            {
                print("Failed to restore copied save file \(copyURL.lastPathComponent).", error)
            }
        }
        
        if removeCopyDirectory
        {
            do
            {
                try FileManager.default.removeItem(at: self.temporaryDirectoryURL)
            }
            catch
            {
                print("Failed to remove preview temporary directory.", error)
            }
        }
    }
}

extension PreviewGameViewController: GameViewControllerDelegate
{
    func gameViewControllerShouldResumeEmulation(_ gameViewController: DeltaCore.GameViewController) -> Bool
    {
        return self.isLivePreview
    }
}
