//
//  GameView.swift
//  DeltaMac
//
//  Created by Riley Testut on 7/8/20.
//  Copyright © 2020 Riley Testut. All rights reserved.
//

import SwiftUI
import DeltaCore

struct GameView: UIViewControllerRepresentable
{
    typealias UIViewControllerType = GameViewController
    
    var game: Game?
    var emulatorBridge: EmulatorBridging?
    
    func makeUIViewController(context: Context) -> GameViewController
    {
        let gameViewController = GameViewController()
        gameViewController.loadViewIfNeeded()
        gameViewController.controllerView.isHidden = true
        
        updateUIViewController(gameViewController, context: context)
                        
        return gameViewController
    }
    
    func updateUIViewController(_ gameViewController: GameViewController, context: Context)
    {
        guard gameViewController.game?.fileURL != self.game?.fileURL else { return }
        
        gameViewController.game = self.game
        
        if let emulatorBridge = self.emulatorBridge
        {
//            gameViewController.emulatorCore?.emulatorBridge = emulatorBridge
            
            if gameViewController.emulatorCore?.state != .running
            {
                gameViewController.emulatorCore?.start()
            }
        }
        
        if let keyboardController = ExternalGameControllerManager.shared.connectedControllers.compactMap({ $0 as? KeyboardGameController }).first,
           let emulatorCore = gameViewController.emulatorCore
        {
            keyboardController.addReceiver(gameViewController)
            keyboardController.addReceiver(emulatorCore)
        }
    }
}

struct GameView_Previews: PreviewProvider {
    static var previews: some View {
        GameView()
    }
}
