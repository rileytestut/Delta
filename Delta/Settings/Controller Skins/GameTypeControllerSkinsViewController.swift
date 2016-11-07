//
//  GameTypeControllerSkinsViewController.swift
//  Delta
//
//  Created by Riley Testut on 9/30/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import UIKit

import DeltaCore

extension GameTypeControllerSkinsViewController
{
    fileprivate enum Section: Int
    {
        case portrait
        case landscape
    }
}

class GameTypeControllerSkinsViewController: UITableViewController
{
    var gameType: GameType!
    
    @IBOutlet fileprivate var portraitImageView: UIImageView!
    @IBOutlet fileprivate var landscapeImageView: UIImageView!
}

extension GameTypeControllerSkinsViewController
{
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.title = self.gameType.localizedShortName
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
        controllerSkinsViewController.gameType = self.gameType
        
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

extension GameTypeControllerSkinsViewController
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

private extension GameTypeControllerSkinsViewController
{
    func updateControllerSkins()
    {
        let controllerSkin = DeltaCore.ControllerSkin.standardControllerSkin(for: self.gameType)
        
        let portraitTraits = DeltaCore.ControllerSkin.Traits(deviceType: .iphone, displayMode: DeltaCore.ControllerSkin.DisplayMode.fullScreen, orientation: .portrait)
        self.portraitImageView.image = controllerSkin?.image(for: portraitTraits, preferredSize: UIScreen.main.defaultControllerSkinSize)
        
        let landscapeTraits = DeltaCore.ControllerSkin.Traits(deviceType: .iphone, displayMode: DeltaCore.ControllerSkin.DisplayMode.fullScreen, orientation: .landscape)
        self.landscapeImageView.image = controllerSkin?.image(for: landscapeTraits, preferredSize: UIScreen.main.defaultControllerSkinSize)
    }
}
