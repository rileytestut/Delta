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
    fileprivate enum Section: Int
    {
        case portrait
        case landscape
    }
}

class SystemControllerSkinsViewController: UITableViewController
{
    var system: System!
    
    @IBOutlet fileprivate var portraitImageView: UIImageView!
    @IBOutlet fileprivate var landscapeImageView: UIImageView!
}

extension SystemControllerSkinsViewController
{
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.title = self.system.localizedShortName
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        self.updateControllerSkins()
        
        super.viewWillAppear(animated)
    }

    override func didReceiveMemoryWarning()
    {
        super.didReceiveMemoryWarning()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?)
    {
        guard let cell = sender as? UITableViewCell, let indexPath = self.tableView.indexPath(for: cell) else { return }
        
        let controllerSkinsViewController = segue.destination as! ControllerSkinsViewController
        controllerSkinsViewController.system = self.system
        
        var traits = DeltaCore.ControllerSkin.Traits.defaults(for: self.view)
        
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
        let section = Section(rawValue: indexPath.section)!
        
        let imageSize: CGSize?
        
        switch section
        {
        case .portrait: imageSize = self.portraitImageView.image?.size
        case .landscape: imageSize = self.landscapeImageView.image?.size
        }
        
        guard let unwrappedImageSize = imageSize else { return super.tableView(tableView, heightForRowAt: indexPath) }
        
        let scale = (self.view.bounds.width / unwrappedImageSize.width)
        
        let height = unwrappedImageSize.height * scale
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
        let portraitTraits = DeltaCore.ControllerSkin.Traits(deviceType: .iphone, displayMode: DeltaCore.ControllerSkin.DisplayMode.fullScreen, orientation: .portrait)
        let landscapeTraits = DeltaCore.ControllerSkin.Traits(deviceType: .iphone, displayMode: DeltaCore.ControllerSkin.DisplayMode.fullScreen, orientation: .landscape)
        
        let portraitControllerSkin = Settings.preferredControllerSkin(for: self.system, traits: portraitTraits)
        let landscapeControllerSkin = Settings.preferredControllerSkin(for: self.system, traits: landscapeTraits)
        
        self.portraitImageView.image = portraitControllerSkin?.image(for: portraitTraits, preferredSize: UIScreen.main.defaultControllerSkinSize)
        self.landscapeImageView.image = landscapeControllerSkin?.image(for: landscapeTraits, preferredSize: UIScreen.main.defaultControllerSkinSize)
    }
}
