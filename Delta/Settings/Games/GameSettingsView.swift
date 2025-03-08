//
//  GameSettingsView.swift
//  Delta
//
//  Created by Riley Testut on 1/22/25.
//  Copyright © 2025 Riley Testut. All rights reserved.
//

import SwiftUI

import DeltaCore
import MelonDSDeltaCore

struct GameSettingsView: View
{
    @ObservedObject
    var game: Game
    
    private let context: NSManagedObjectContext
    
    @Environment(\.presentationMode)
    private var presentationMode
    
    @SwiftUI.State
    private var hasBIOSFiles: Bool = false
    
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
            
            let system = System(gameType: game.type)
            
            if system == .n64
            {
                Section {
                    let binding = Binding {
                        let isUsingOpenGLES2 = game.settings[.openGLES2] as? Bool ?? false
                        return !isUsingOpenGLES2
                    } set: { isUsingOpenGLES3 in
                        game.settings[.openGLES2] = !isUsingOpenGLES3
                    }

                    Toggle("OpenGL ES 3.0", isOn: binding)
                        .toggleStyle(SwitchToggleStyle(tint: Color("Purple")))
                } header: {
                    Text("Graphics")
                } footer: {
                    Text("Use OpenGL ES 3.0 to render this game. You may need to disable this for certain games.")
                }
            }
            
            if system == .ds
            {
                Section {
                    if self.hasBIOSFiles
                    {
                        GamePickerView(game: game)
                            .environment(\.managedObjectContext, self.context)
                    }
                    else
                    {
                        // BIOS is required for GBA slot emulation.
                        
                        NavigationLink {
                            MelonDSCoreSettingsView()
                                .ignoresSafeArea()
                        } label: {
                            Text("Import BIOS Files")
                                .foregroundColor(Color("Purple"))
                        }
                    }
                } header: {
                    Text("Dual Slot")
                } footer: {
                    Text("Emulate inserting a GBA game into the Nintendo DS dual slot.")
                }
            }
        }
        .accentColor(Color("Purple"))
        .navigationTitle(game.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
        .onAppear {
            guard self.game.type == .ds else { return }
            
            if FileManager.default.fileExists(atPath: MelonDSEmulatorBridge.shared.bios7URL.path) &&
                FileManager.default.fileExists(atPath: MelonDSEmulatorBridge.shared.bios9URL.path) &&
                FileManager.default.fileExists(atPath: MelonDSEmulatorBridge.shared.firmwareURL.path)
            {
                self.hasBIOSFiles = true
            }
            else
            {
                self.hasBIOSFiles = false
            }
        }
        .onDisappear {
            // Save any pending changes to disk.
            self.context.saveWithErrorLogging()
        }
    }
}

// Separate type so we can provide temporary NSManagedObjectContext in environment.
private struct GamePickerView: View
{
    @ObservedObject
    var game: Game
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Game.name, ascending: true)],
        predicate: NSPredicate(format: "%K == %@", #keyPath(Game.type), GameType.gba.rawValue)
    )
    private var gbaGames: FetchedResults<Game>
    
    var body: some View {
        let title: LocalizedStringKey = (game.secondaryGame != nil) ? "GBA Game" : "Insert GBA Game"
        let picker = Picker(title, selection: $game.secondaryGame) {
            Text("None").tag(Optional<Game>.none)
            
            ForEach(gbaGames, id: \.objectID) { game in
                Text(game.name).tag(game)
            }
        }
        
        if #available(iOS 16, *)
        {
            picker.pickerStyle(.navigationLink)
        }
        else
        {
            picker
        }
    }
}
