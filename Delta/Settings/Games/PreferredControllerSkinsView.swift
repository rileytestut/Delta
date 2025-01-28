//
//  PreferredControllerSkinsView.swift
//  Delta
//
//  Created by Riley Testut on 1/27/25.
//  Copyright © 2025 Riley Testut. All rights reserved.
//

import SwiftUI

struct PreferredControllerSkinsView: UIViewControllerRepresentable
{
    let game: Game
    
    func makeUIViewController(context: Context) -> PreferredControllerSkinsViewController
    {
        let storyboard = UIStoryboard(name: "Settings", bundle: nil)
        
        let viewController = storyboard.instantiateViewController(withIdentifier: "preferredControllerSkins") as! PreferredControllerSkinsViewController
        viewController.game = self.game
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: PreferredControllerSkinsViewController, context: Context)
    {
    }
}
