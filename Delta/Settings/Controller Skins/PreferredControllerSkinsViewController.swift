//
//  PreferredControllerSkinsViewController.swift
//  Delta
//
//  Created by Riley Testut on 9/30/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import UIKit

import DeltaCore

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
        case airPlay
        case splitView
        
        static var supportedVariants: [Variant] {
            switch UIDevice.current.userInterfaceIdiom
            {
            case .pad: return [.standard, .airPlay, .splitView]
            default: return [.standard, .airPlay]
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
    
    private var _previousBoundsSize: CGSize?
    private var portraitControllerSkin: ControllerSkin?
    private var landscapeControllerSkin: ControllerSkin?
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
        self.updateControllerSkins()
        
        self.tableView.reloadData()
    }
    
    func updateControllerSkins()
    {
        guard let window = self.view.window else { return }
        
        self._previousBoundsSize = self.view.bounds.size
                
        let portraitTraits = self.makeTraits(orientation: .portrait, in: window)
        let landscapeTraits = self.makeTraits(orientation: .landscape, in: window)
        
        var portraitControllerSkin: ControllerSkin?
        var landscapeControllerSkin: ControllerSkin?
        
        if let game = self.game
        {
            portraitControllerSkin = Settings.preferredControllerSkin(for: game, traits: portraitTraits)
            landscapeControllerSkin = Settings.preferredControllerSkin(for: game, traits: landscapeTraits)
        }
        
        if portraitControllerSkin == nil
        {
            portraitControllerSkin = Settings.preferredControllerSkin(for: self.system, traits: portraitTraits)
        }
        
        if landscapeControllerSkin == nil
        {
            landscapeControllerSkin = Settings.preferredControllerSkin(for: self.system, traits: landscapeTraits)
        }
        
        if portraitControllerSkin != self.portraitControllerSkin
        {
            self.portraitImageView.image = nil
            self.portraitImageView.isIndicatingActivity = true
            
            self.portraitControllerSkin = portraitControllerSkin
        }
        
        if landscapeControllerSkin != self.landscapeControllerSkin
        {
            self.landscapeImageView.image = nil
            self.landscapeImageView.isIndicatingActivity = true
            
            self.landscapeControllerSkin = landscapeControllerSkin
        }
        
        DatabaseManager.shared.performBackgroundTask { (context) in
            
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
            
            DispatchQueue.main.async {
                self.portraitImageView.isIndicatingActivity = false
                self.portraitImageView.image = portraitImage
                
                self.landscapeImageView.isIndicatingActivity = false
                self.landscapeImageView.image = landscapeImage
            }
        }
    }
    
    func makeTraits(orientation: DeltaCore.ControllerSkin.Orientation, in window: UIWindow) -> DeltaCore.ControllerSkin.Traits
    {
        var traits = DeltaCore.ControllerSkin.Traits.defaults(for: window)
        traits.orientation = orientation
        
        switch self.variant
        {
        case .standard: 
            traits.displayType = .standard //TODO: Use edgeToEdge for iphone when appropriate
            
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
        if let game = self.game
        {
            Settings.setPreferredControllerSkin(controllerSkin, for: game, traits: controllerSkinsViewController.traits)
        }
        else
        {
            Settings.setPreferredControllerSkin(controllerSkin, for: self.system, traits: controllerSkinsViewController.traits)
        }
        
        _ = self.navigationController?.popViewController(animated: true)
    }
    
    func controllerSkinsViewControllerDidResetControllerSkin(_ controllerSkinsViewController: ControllerSkinsViewController)
    {
        if let game = self.game
        {
            Settings.setPreferredControllerSkin(nil, for: game, traits: controllerSkinsViewController.traits)
        }
        else
        {
            Settings.setPreferredControllerSkin(nil, for: self.system, traits: controllerSkinsViewController.traits)
        }
        
        _ = self.navigationController?.popViewController(animated: true)
    }
}
