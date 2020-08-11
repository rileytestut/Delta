//
//  GameView.swift
//  DeltaMac
//
//  Created by Riley Testut on 7/8/20.
//  Copyright © 2020 Riley Testut. All rights reserved.
//

import SwiftUI
import DeltaCore
import Combine

private struct _GameView: UIViewControllerRepresentable
{
    typealias UIViewControllerType = GameViewController
    
    var game: Game?
    var emulatorBridge: EmulatorBridging?
    var linkRole: LinkRole
    
    @State var connectedControllers: [GameController] = ExternalGameControllerManager.shared.connectedControllers
    
    class Coordinator: NSObject
    {
        @Binding var gameControllers: [GameController]
        
        private var cancelBag = Set<AnyCancellable>()
        
        init(gameControllers: Binding<[GameController]>)
        {
            _gameControllers = gameControllers
            
            super.init()
                        
            NotificationCenter.default.publisher(for: .externalGameControllerDidConnect)
                .combineLatest(NotificationCenter.default.publisher(for: .externalGameControllerDidDisconnect))
                .map { _ in ExternalGameControllerManager.shared.connectedControllers }
                .assign(to: \.gameControllers, on: self)
                .store(in: &cancelBag)
        }
    }
    
    func makeCoordinator() -> Coordinator
    {
        return Coordinator(gameControllers: $connectedControllers)
    }
    
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
        if gameViewController.game?.fileURL != self.game?.sharedFileURL
        {
            guard let sharedGameURL = self.game?.sharedFileURL else { return }
            
            struct MyGame: GameProtocol
            {
                var fileURL: URL
                
                var type: GameType
            }
            
            if let game = self.game
            {
                gameViewController.game = MyGame(fileURL: sharedGameURL, type: game.type)
            }
            else
            {
                gameViewController.game = nil
            }
        }
        
        if let emulatorCore = gameViewController.emulatorCore
        {
            emulatorCore.linkRole = self.linkRole
            
            for controller in ExternalGameControllerManager.shared.connectedControllers
            {
                controller.addReceiver(gameViewController)
                controller.addReceiver(emulatorCore)
            }
        }
        
        if let emulatorBridge = self.emulatorBridge
        {
//            gameViewController.emulatorCore?.emulatorBridge = emulatorBridge
            
            if gameViewController.emulatorCore?.state != .running
            {
                gameViewController.emulatorCore?.start()
            }
        }
        
        gameViewController.view.setNeedsLayout()
    }
}

struct GameView: View
{
    var game: Game?
    var emulatorBridge: EmulatorBridging?
    var linkRole: LinkRole = .none
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea([.all], edges: .all)
            
            _GameView(game: game, emulatorBridge: emulatorBridge, linkRole: linkRole)
                .ignoresSafeArea([.all], edges: .all)
        }
    }
}

struct GameView_Previews: PreviewProvider {
    static var previews: some View {
        GameView()
    }
}
