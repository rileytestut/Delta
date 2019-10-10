//
//  SystemControllerSkinsViewController.swift
//  Delta
//
//  Created by Riley Testut on 9/30/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import UIKit

import DeltaCore

extension SystemControllerSkinsViewController
{
    private enum Section: Int
    {
        case portrait
        case landscape
    }
}

class SystemControllerSkinsViewController: UITableViewController
{
    var system: System!
    
    @IBOutlet private var portraitImageView: UIImageView!
    @IBOutlet private var landscapeImageView: UIImageView!
    
    private var _previousBoundsSize: CGSize?
    private var portraitControllerSkin: ControllerSkin?
    private var landscapeControllerSkin: ControllerSkin?
}

extension SystemControllerSkinsViewController
{
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.title = self.system.localizedShortName
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
            self.updateControllerSkins()
            self.tableView.reloadData()
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?)
    {
        guard let cell = sender as? UITableViewCell, let indexPath = self.tableView.indexPath(for: cell), let window = self.view.window else { return }
        
        let controllerSkinsViewController = segue.destination as! ControllerSkinsViewController
        controllerSkinsViewController.system = self.system
        
        var traits = DeltaCore.ControllerSkin.Traits.defaults(for: window)
        
        let section = Section(rawValue: indexPath.section)!
        switch section
        {
        case .portrait: traits.orientation = .portrait
        case .landscape: traits.orientation = .landscape
        }
        
        controllerSkinsViewController.traits = traits
    }
}

extension SystemControllerSkinsViewController
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

private extension SystemControllerSkinsViewController
{
    func updateControllerSkins()
    {
        guard let window = self.view.window else { return }
        
        self._previousBoundsSize = self.view.bounds.size
                
        let portraitTraits = self.makeTraits(orientation: .portrait, in: window)
        let landscapeTraits = self.makeTraits(orientation: .landscape, in: window)
        
        let portraitControllerSkin = Settings.preferredControllerSkin(for: self.system, traits: portraitTraits)
        if portraitControllerSkin != self.portraitControllerSkin
        {
            self.portraitImageView.image = nil
            self.portraitImageView.isIndicatingActivity = true
            
            self.portraitControllerSkin = portraitControllerSkin
        }
        
        let landscapeControllerSkin = Settings.preferredControllerSkin(for: self.system, traits: landscapeTraits)
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
        return traits
    }
}
