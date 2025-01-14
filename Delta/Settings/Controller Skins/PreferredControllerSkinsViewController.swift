//
//  PreferredControllerSkinsViewController.swift
//  Delta
//
//  Created by Riley Testut on 9/30/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import UIKit

// Access UIWindowScene.isStageManagerEnabled
@_spi(Internal) import DeltaCore

extension PreferredControllerSkinsViewController
{
    private enum Section: Int
    {
        case portrait
        case landscape
    }
    
    private enum Variant
    {
        case standard
        case controller
        case splitView
        case airPlay
        
        static var supportedVariants: [Variant] {
            var supportedVariants: [Variant] = [.standard, .controller]
            
            if UIDevice.current.userInterfaceIdiom == .pad
            {
                supportedVariants.append(.splitView)
            }
            
            if ExperimentalFeatures.shared.airPlaySkins.isEnabled
            {
                supportedVariants.append(.airPlay)
            }
            
            return supportedVariants
        }
        
        func localizedName(for scene: UIWindowScene) -> String
        {
            switch self
            {
            case .standard:
                switch UIDevice.current.userInterfaceIdiom
                {
                case .pad: return NSLocalizedString("Full Screen", comment: "")
                default: return NSLocalizedString("Standard", comment: "")
                }
                
            case .controller: return NSLocalizedString("Controller", comment: "")
                
            case .splitView:
                if #available(iOS 16, *), scene.isStageManagerEnabled
                {
                    return NSLocalizedString("Stage Manager", comment: "")
                }
                else
                {
                    return NSLocalizedString("Split View", comment: "")
                }
                
            case .airPlay: return NSLocalizedString("AirPlay", comment: "")
            }
        }
    }
}

class PreferredControllerSkinsViewController: UITableViewController
{
    var system: System!
    
    var game: Game? {
        didSet {
            guard let game = self.game, let system = System(gameType: game.type) else { return }
            self.system = system
        }
    }
    
    private var variant: Variant = .standard
    
    @IBOutlet private var portraitImageView: UIImageView!
    @IBOutlet private var landscapeImageView: UIImageView!
    @IBOutlet private var variantSegmentedControl: UISegmentedControl!
    
    private var _previousBoundsSize: CGSize?
    private var portraitControllerSkin: ControllerSkin?
    private var landscapeControllerSkin: ControllerSkin?
    private var portraitTraits: DeltaCore.ControllerSkin.Traits?
    private var landscapeTraits: DeltaCore.ControllerSkin.Traits?
    
    private var loadingTask: Task<Void, Never>?
}

extension PreferredControllerSkinsViewController
{
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.title = self.game?.name ?? self.system.localizedShortName
        
        if self.navigationController?.viewControllers.first != self
        {
            // Hide Done button since we are not root view controller.
            self.navigationItem.rightBarButtonItem = nil
        }
        
        self.variantSegmentedControl.removeAllSegments()
    }
    
    override func viewIsAppearing(_ animated: Bool)
    {
        super.viewIsAppearing(animated)
        
        if let scene = self.view.window?.windowScene, Variant.supportedVariants.count > 1, self.variantSegmentedControl.numberOfSegments == 0
        {
            // Only update segmented control on initial appearance when it has no segments.
            
            for (index, variant) in zip(0..., Variant.supportedVariants)
            {
                self.variantSegmentedControl.insertSegment(withTitle: variant.localizedName(for: scene), at: index, animated: false)
            }
            
            self.variantSegmentedControl.selectedSegmentIndex = 0
        }
    }
    
    override func viewDidDisappear(_ animated: Bool)
    {
        super.viewDidDisappear(animated)
        
        self._previousBoundsSize = nil
    }

    override func didReceiveMemoryWarning()
    {
        super.didReceiveMemoryWarning()
    }
    
    override func viewDidLayoutSubviews()
    {
        super.viewDidLayoutSubviews()
        
        if self.view.bounds.size != self._previousBoundsSize
        {
            self.update()
        }
    }
    
    override func didMove(toParent parent: UIViewController?)
    {
        super.didMove(toParent: parent)
        
        if let parent, !(parent is UINavigationController)
        {
            // When embedded in SwiftUI NavigationStack, we're nested inside extra parent view controller.
            // So we update our parent's navigationItem which is then picked up by NavigationStack.
            
            if let titleView = self.navigationItem.titleView
            {
                parent.navigationItem.titleView = titleView
            }
            
            if let items = self.navigationItem.rightBarButtonItems, !items.isEmpty
            {
                parent.navigationItem.rightBarButtonItems = items
            }
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?)
    {
        guard let cell = sender as? UITableViewCell, let indexPath = self.tableView.indexPath(for: cell), let window = self.view.window else { return }
        
        let controllerSkinsViewController = segue.destination as! ControllerSkinsViewController
        controllerSkinsViewController.delegate = self
        controllerSkinsViewController.system = self.system
        
        let traits: DeltaCore.ControllerSkin.Traits
        
        let section = Section(rawValue: indexPath.section)!
        switch section
        {
        case .portrait: traits = self.makeTraits(orientation: .portrait, in: window)
        case .landscape: traits = self.makeTraits(orientation: .landscape, in: window)
        }
        
        controllerSkinsViewController.traits = traits
        
        let isResetButtonVisible: Bool
        
        if let game = self.game
        {
            switch section
            {
            case .portrait: isResetButtonVisible = (game.preferredPortraitSkin != nil)
            case .landscape: isResetButtonVisible = (game.preferredLandscapeSkin != nil)
            }
        }
        else
        {
            switch section
            {
            case .portrait: isResetButtonVisible = !(self.portraitControllerSkin?.isStandard ?? false)
            case .landscape: isResetButtonVisible = !(self.portraitControllerSkin?.isStandard ?? false)
            }
        }
        
        controllerSkinsViewController.isResetButtonVisible = isResetButtonVisible
    }
}

extension PreferredControllerSkinsViewController
{
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat
    {
        guard let window = self.view.window else { return 44.0 }
        
        let section = Section(rawValue: indexPath.section)!
        
        let aspectRatio: CGSize?
        
        switch section
        {
        case .portrait: aspectRatio = self.portraitControllerSkin?.aspectRatio(for: self.makeTraits(orientation: .portrait, in: window))
        case .landscape: aspectRatio = self.landscapeControllerSkin?.aspectRatio(for: self.makeTraits(orientation: .landscape, in: window))
        }
        
        guard let unwrappedAspectRatio = aspectRatio else { return super.tableView(tableView, heightForRowAt: indexPath) }
        
        let scale = (self.view.bounds.width / unwrappedAspectRatio.width)
        
        let height = min(unwrappedAspectRatio.height * scale, self.view.bounds.height - self.view.safeAreaInsets.top - self.view.safeAreaInsets.bottom - 30)
        return height
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        guard let cell = tableView.cellForRow(at: indexPath) else { return }
        
        self.performSegue(withIdentifier: "showControllerSkins", sender: cell)
    }
}

private extension PreferredControllerSkinsViewController
{
    func update()
    {
        self.tableView.reloadData()
        
        self.updateControllerSkins()
    }
    
    func updateControllerSkins()
    {
        guard let window = self.view.window else { return }
        
        self.loadingTask?.cancel()
        
        self._previousBoundsSize = self.view.bounds.size
                
        let portraitTraits = self.makeTraits(orientation: .portrait, in: window)
        let landscapeTraits = self.makeTraits(orientation: .landscape, in: window)
        
        var portraitControllerSkin: ControllerSkin?
        var landscapeControllerSkin: ControllerSkin?
        
        let isExternalControllerSkin = (self.variant == .controller)
        
        if let game = self.game
        {
            portraitControllerSkin = Settings.preferredControllerSkin(for: game, traits: portraitTraits, forExternalController: isExternalControllerSkin)
            landscapeControllerSkin = Settings.preferredControllerSkin(for: game, traits: landscapeTraits, forExternalController: isExternalControllerSkin)
        }
        
        if portraitControllerSkin == nil
        {
            portraitControllerSkin = Settings.preferredControllerSkin(for: self.system, traits: portraitTraits, forExternalController: isExternalControllerSkin)
        }
        
        if landscapeControllerSkin == nil
        {
            landscapeControllerSkin = Settings.preferredControllerSkin(for: self.system, traits: landscapeTraits, forExternalController: isExternalControllerSkin)
        }
        
        if portraitControllerSkin != self.portraitControllerSkin || portraitTraits != self.portraitTraits
        {
            self.portraitImageView.image = nil
            self.portraitImageView.isIndicatingActivity = true
        }
        
        if landscapeControllerSkin != self.landscapeControllerSkin || landscapeTraits != self.landscapeTraits
        {
            self.landscapeImageView.image = nil
            self.landscapeImageView.isIndicatingActivity = true
        }
        
        self.portraitControllerSkin = portraitControllerSkin
        self.landscapeControllerSkin = landscapeControllerSkin
        
        self.portraitTraits = portraitTraits
        self.landscapeTraits = landscapeTraits
        
        self.loadingTask = Task<Void, Never> {
            let (portraitImage, landscapeImage) = await withCheckedContinuation { continuation in
                DatabaseManager.shared.performBackgroundTask { context in
                    let portraitImage: UIImage?
                    let landscapeImage: UIImage?
                    
                    if let portraitControllerSkin = self.portraitControllerSkin
                    {
                        let skin = context.object(with: portraitControllerSkin.objectID) as! ControllerSkin
                        portraitImage = skin.image(for: portraitTraits, preferredSize: UIScreen.main.defaultControllerSkinSize)
                    }
                    else
                    {
                        portraitImage = nil
                    }
                    
                    if let landscapeControllerSkin = self.landscapeControllerSkin
                    {
                        let skin = context.object(with: landscapeControllerSkin.objectID) as! ControllerSkin
                        landscapeImage = skin.image(for: landscapeTraits, preferredSize: UIScreen.main.defaultControllerSkinSize)
                    }
                    else
                    {
                        landscapeImage = nil
                    }
                    
                    continuation.resume(returning: (portraitImage, landscapeImage))
                }
            }
            
            guard !Task.isCancelled else { return }
            
            self.portraitImageView.isIndicatingActivity = false
            self.portraitImageView.image = portraitImage
            
            self.landscapeImageView.isIndicatingActivity = false
            self.landscapeImageView.image = landscapeImage
        }
    }
    
    func makeTraits(orientation: DeltaCore.ControllerSkin.Orientation, in window: UIWindow) -> DeltaCore.ControllerSkin.Traits
    {
        var traits = DeltaCore.ControllerSkin.Traits.defaults(for: window)
        traits.orientation = orientation
        
        switch self.variant
        {
        case .standard where UIDevice.current.userInterfaceIdiom == .pad:
            traits.displayType = .standard
            
        case .standard:
            // Use defaults for iPhone
            break
            
        case .controller:
            // Use defaults for `controller`
            
            if traits.displayType == .splitView
            {
                // ..unless displayType is splitView, because we don't currently
                // support external controller skins when in split view.
                traits.displayType = .edgeToEdge
            }
            
            break
            
        case .airPlay:
            traits.displayType = .standard
            traits.device = .tv
            
        case .splitView:
            traits.displayType = .splitView
        }
        
        return traits
    }
}

private extension PreferredControllerSkinsViewController
{
    @IBAction func changeCurrentVariant(_ sender: UISegmentedControl)
    {
        let variant = Variant.supportedVariants[sender.selectedSegmentIndex]
        self.variant = variant
        
        self.update()
    }
}

extension PreferredControllerSkinsViewController: ControllerSkinsViewControllerDelegate
{
    func controllerSkinsViewController(_ controllerSkinsViewController: ControllerSkinsViewController, didChooseControllerSkin controllerSkin: ControllerSkin)
    {
        let isExternalControllerSkin = (self.variant == .controller)
        
        if let game = self.game
        {
            Settings.setPreferredControllerSkin(controllerSkin, for: game, traits: controllerSkinsViewController.traits, forExternalController: isExternalControllerSkin)
        }
        else
        {
            Settings.setPreferredControllerSkin(controllerSkin, for: self.system, traits: controllerSkinsViewController.traits, forExternalController: isExternalControllerSkin)
        }
        
        _ = self.navigationController?.popViewController(animated: true)
    }
    
    func controllerSkinsViewControllerDidResetControllerSkin(_ controllerSkinsViewController: ControllerSkinsViewController)
    {
        let isExternalControllerSkin = (self.variant == .controller)
        
        if let game = self.game
        {
            Settings.setPreferredControllerSkin(nil, for: game, traits: controllerSkinsViewController.traits, forExternalController: isExternalControllerSkin)
        }
        else
        {
            Settings.setPreferredControllerSkin(nil, for: self.system, traits: controllerSkinsViewController.traits, forExternalController: isExternalControllerSkin)
        }
        
        _ = self.navigationController?.popViewController(animated: true)
    }
}
