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

private class GameViewContext: ObservableObject
{
    @Published
    var emulatorCore: EmulatorCore?
    
    var windowScene: UIWindowScene?
}

private struct _GameView: UIViewControllerRepresentable
{
    typealias UIViewControllerType = GameViewController
    
    var game: Game?
    var linkRole: LinkRole
    
    @EnvironmentObject
    var gameViewContext: GameViewContext
    
    @State
    var connectedControllers: [GameController] = ExternalGameControllerManager.shared.connectedControllers
    
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
                var name: String
                var fileURL: URL
                
                var type: GameType
            }
            
            if let game = self.game
            {
                gameViewController.game = MyGame(name: game.name, fileURL: sharedGameURL, type: game.type)
            }
            else
            {
                gameViewController.game = nil
            }
            
            self.gameViewContext.emulatorCore = gameViewController.emulatorCore
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
        
//        if let emulatorBridge = self.emulatorBridge
//        {
////            gameViewController.emulatorCore?.emulatorBridge = emulatorBridge
//
//            if gameViewController.emulatorCore?.state != .running
//            {
//                gameViewController.emulatorCore?.start()
//            }
//        }
        
        gameViewController.view.setNeedsLayout()
        gameViewContext.windowScene = gameViewController.view.window?.windowScene
    }
}

class GameViewModel: ObservableObject
{
    @Published
    var emulatorCore: EmulatorCore?
}

struct GameView: View
{
    var game: Game?
    var linkRole: LinkRole = .none
    
    @StateObject
    private var context = GameViewContext()
    
    @State
    private var presentedError: NSError?

    var body: some View {
        if let emulatorCore = context.emulatorCore
        {
            _body
                .environmentObject(emulatorCore)
                .onReceive(emulatorCore.$error) { (error) in
                    self.presentedError = error as NSError?
                }
        }
        else
        {
            _body
        }
    }
    
    private var _body: some View {
        ZStack {
            ZStack {
                Color.black
                    .ignoresSafeArea([.all], edges: .all)
                
                _GameView(game: game, linkRole: linkRole)
                    .ignoresSafeArea([.all], edges: [.bottom])
            }
            .alert(item: $presentedError) { (error) -> Alert in
                Alert(title: Text(error.localizedDescription),
                      message: error.localizedRecoverySuggestion.map { Text($0) },
                      primaryButton: .destructive(Text("Quit"), action: quit),
                      secondaryButton: .default(Text("Restart"), action: restart))
                        
            }
        }
        .environmentObject(self.context)
    }
        
    func quit()
    {
        if let session = self.context.windowScene?.session
        {
            let options = UIWindowSceneDestructionRequestOptions()
            options.windowDismissalAnimation = .standard
            UIApplication.shared.requestSceneSessionDestruction(session, options: options) { (error) in
                print("Error quitting game:", error)
            }
        }
    }
    
    func restart()
    {
        DispatchQueue.global().async {
            context.emulatorCore?.stop()
            context.emulatorCore?.start()
        }        
    }
}

struct GameView_Previews: PreviewProvider {
    static var previews: some View {
        GameView()
    }
}
