//
//  AirPlaySkins.swift
//  Delta
//
//  Created by Riley Testut on 4/20/23.
//  Copyright © 2023 Riley Testut. All rights reserved.
//

import SwiftUI

import DeltaFeatures
import DeltaCore

extension Feature where Options == AirPlaySkinsOptions
{
//    func preferredAirPlayControllerSkin(for game: Game, traits: DeltaCore.ControllerSkin.Traits) -> ControllerSkin?
//    {
//        guard let identifier = self[gameType] else { return nil }
//        
//        let predicate = NSPredicate(format: "%K == %@", #keyPath(ControllerSkin.identifier), identifier)
//        let controllerSkin = ControllerSkin.instancesWithPredicate(predicate, inManagedObjectContext: DatabaseManager.shared.viewContext, type: ControllerSkin.self).first
//        return controllerSkin
//    }
}

struct AirPlaySkinsOptions
{
    @Option(name: "Manage Skins", detailView: { _ in SkinManager() })
    private var skinManager: String = "" // Hack until I figure out how to support Void properties...
    
    @Option(name: LocalizedStringKey(System.nes.localizedName), description: "The controller skin used when AirPlaying NES games.", detailView: { SkinPicker(gameType: .nes, controllerSkinID: $0) })
    var nes: String?
    
    @Option(name: LocalizedStringKey(System.snes.localizedName), description: "The controller skin used when AirPlaying SNES games.", detailView: { SkinPicker(gameType: .snes, controllerSkinID: $0) })
    var snes: String?
    
    @Option(name: LocalizedStringKey(System.genesis.localizedName), description: "The controller skin used when AirPlaying Genesis games.", detailView: { SkinPicker(gameType: .genesis, controllerSkinID: $0) })
    var genesis: String?
    
    @Option(name: LocalizedStringKey(System.n64.localizedName), description: "The controller skin used when AirPlaying N64 games.", detailView: { SkinPicker(gameType: .n64, controllerSkinID: $0) })
    var n64: String?
    
    @Option(name: LocalizedStringKey(System.gbc.localizedName), description: "The controller skin used when AirPlaying GBC games.", detailView: { SkinPicker(gameType: .gbc, controllerSkinID: $0) })
    var gbc: String?
    
    @Option(name: LocalizedStringKey(System.gba.localizedName), description: "The controller skin used when AirPlaying GBA games.", detailView: { SkinPicker(gameType: .gba, controllerSkinID: $0) })
    var gba: String?
    
    @Option(name: LocalizedStringKey(System.ds.localizedName), description: "The controller skin used when AirPlaying DS games.", detailView: { SkinPicker(gameType: .ds, controllerSkinID: $0) })
    var ds: String?
    
    subscript(gameType: GameType) -> String? {
        guard let system = System(gameType: gameType) else { return nil }
        switch system
        {
        case .nes: return self.nes
        case .snes: return self.snes
        case .genesis: return self.genesis
        case .n64: return self.n64
        case .gbc: return self.gbc
        case .gba: return self.gba
        case .ds: return self.ds
        }
    }
}

fileprivate extension AirPlaySkinsOptions
{
    struct SkinPicker: View
    {
        let gameType: GameType
        
        @Binding
        var controllerSkinID: String?
        
        @FetchRequest
        private var controllerSkins: FetchedResults<ControllerSkin>
        
        @Environment(\.featureOption)
        private var option
        
        var body: some View {
            Picker(option.name ?? "", selection: $controllerSkinID) {
                ForEach(controllerSkins, id: \.identifier) { controllerSkin in
                    Text(controllerSkin.name)
                        .tag(Optional<String>(controllerSkin.identifier)) // Must be Optional<String> in order for selection to work.
                        // .tag(controllerSkin.identifier)
                }
                
                Text("None")
                    .tag(String?.none)
            }
            .pickerStyle(.menu)
            .displayInline()
        }
        
        init(gameType: GameType, controllerSkinID: Binding<String?>)
        {
            self.gameType = gameType
            self._controllerSkinID = controllerSkinID
            
            let configuration = ControllerSkinConfigurations.tvStandardLandscape
            
            let predicate = NSPredicate(format: "%K == %@ AND (%K & %d) != 0 AND %K == NO",
                                        #keyPath(ControllerSkin.gameType), self.gameType.rawValue,
                                        #keyPath(ControllerSkin.supportedConfigurations), configuration.rawValue,
                                        #keyPath(ControllerSkin.isStandard))
            
            self._controllerSkins = FetchRequest(entity: ControllerSkin.entity(), sortDescriptors: [NSSortDescriptor(keyPath: \ControllerSkin.name, ascending: true)], predicate: predicate)
        }
    }
    
    struct SkinManager: View
    {
        @FetchRequest(entity: ControllerSkin.entity(),
                      sortDescriptors: [NSSortDescriptor(keyPath: \ControllerSkin.name, ascending: true)],
                      predicate: {
            let configuration = ControllerSkinConfigurations.tvStandardLandscape
            return NSPredicate(format: "(%K & %d) != 0 AND %K == NO",
                               #keyPath(ControllerSkin.supportedConfigurations), configuration.rawValue,
                               #keyPath(ControllerSkin.isStandard))
        }())
        private var controllerSkins: FetchedResults<ControllerSkin>
        
        var body: some View {
            if controllerSkins.isEmpty
            {
                Text("No AirPlay Skins")
                    .foregroundColor(.gray)
            }
            else
            {
                List {
                    ForEach(controllerSkins, id: \.identifier) { controllerSkin in
                        HStack {
                            Text(controllerSkin.name)
                            
                            Spacer()
                            
                            if let system = System(gameType: controllerSkin.gameType)
                            {
                                Text(system.localizedShortName)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .onDelete(perform: deleteAirPlaySkins)
                }
            }
        }
        
        private func deleteAirPlaySkins(at indexes: IndexSet)
        {
            let objectIDs = indexes.map { controllerSkins[$0].objectID }
            
            DatabaseManager.shared.performBackgroundTask { context in
                let controllerSkins = objectIDs.compactMap { context.object(with: $0) as? ControllerSkin }
                for controllerSkin in controllerSkins
                {
                    context.delete(controllerSkin)
                }
                
                context.saveWithErrorLogging()
            }
        }
    }
}
