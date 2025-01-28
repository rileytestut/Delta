//
//  GameSettingsView.swift
//  Delta
//
//  Created by Riley Testut on 1/22/25.
//  Copyright © 2025 Riley Testut. All rights reserved.
//

import SwiftUI

import DeltaCore

struct GameSettingsView: View
{
    @ObservedObject
    var game: Game
    
    private let context: NSManagedObjectContext
    
    @Environment(\.presentationMode)
    private var presentationMode
    
    init(game: Game)
    {
        // Create temporary context that will be saved when view is dismissed.
        self.context = DatabaseManager.shared.newBackgroundSavingViewContext()
        
        let game = self.context.object(with: game.objectID) as! Game
        self.game = game
    }
    
    var body: some View {
        List {
            Section {
                NavigationLink("Change Controller Skin") {
                    PreferredControllerSkinsView(game: game)
                        .ignoresSafeArea()
                }
            } header: {
                Text("Display")
            } footer: {
                Text("Choose a controller skin that should always be used for this game.")
            }
        }
        .accentColor(Color("Purple"))
        .environment(\.managedObjectContext, self.context)
        .navigationTitle(game.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
        .onDisappear {
            // Save any pending changes to disk.
            self.context.saveWithErrorLogging()
        }
    }
}
