//
//  EmulationViewController.swift
//  Delta
//
//  Created by Riley Testut on 10/11/15.
//  Copyright © 2015 Riley Testut. All rights reserved.
//

import UIKit

import DeltaCore
import SNESDeltaCore

class EmulationViewController: UIViewController
{
    //MARK: - Properties -
    /** Properties **/
    var game: Game! {
        didSet
        {
            self.emulatorCore = SNESEmulatorCore(game: game)
        }
    }
    private(set) var emulatorCore: EmulatorCore!
    
    //MARK: - Private Properties
    @IBOutlet private var gameView: GameView!
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.emulatorCore.addGameView(self.gameView)
    }
    
    override func viewDidAppear(animated: Bool)
    {
        super.viewDidAppear(animated)
        
        self.emulatorCore.startEmulation()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
