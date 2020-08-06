//
//  GameCollectionView.swift
//  DeltaMac
//
//  Created by Riley Testut on 7/24/20.
//  Copyright © 2020 Riley Testut. All rights reserved.
//

import SwiftUI
import DeltaCore
import UniformTypeIdentifiers

extension UTType
{
    static let deltaGame = UTType(exportedAs: "com.rileytestut.delta.game")
//    static let deltaGameGBA = UTType(exportedAs: "com.rileytestut.delta.game.gba", conformingTo: .deltaGame)
    static let deltaGameGBC = UTType(exportedAs: "com.rileytestut.delta.game.gbc", conformingTo: .deltaGame)
    
    static let deltaGameGBA = UTType(filenameExtension: "gba")!
}

struct GameCell: View
{
    let game: Game
    
    var body: some View {
        VStack(alignment: .leading) {
            AsyncImage(url: game.artworkURL, placeholder: ZStack {
                Color.gray.opacity(0.2)
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            })
            .aspectRatio(CGSize(width: 1, height: 1), contentMode: /*@START_MENU_TOKEN@*/.fill/*@END_MENU_TOKEN@*/)
            .clipShape(shape)
            
            Text(self.game.name + "\n")
                .font(.body)
                .lineLimit(2)
        }
    }
    
    var shape: some Shape {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
    }
}

extension NSUserActivity
{
    static let startGameActivityType = "com.rileytestut.Delta.StartGame"
}

extension Game
{
    var startGameActivity: NSUserActivity {
        let startGameActivity = NSUserActivity(activityType: NSUserActivity.startGameActivityType)
        startGameActivity.title = String(format: NSLocalizedString("Play %@", comment: ""), self.name)
        startGameActivity.userInfo = ["identifier": self.identifier]
        startGameActivity.isEligibleForPrediction = true
        return startGameActivity
    }
}

struct InternalView: View
{
    let system: System
    
    var games: FetchedResults<Game> { fetchRequest.wrappedValue }
    private let fetchRequest: FetchRequest<Game>
    
    @EnvironmentObject
    var databaseManager: DatabaseManager
    
    @State
    private var isDeleting: Bool = false
    
    init(system: System)
    {
        self.system = system
        self.fetchRequest = FetchRequest(sortDescriptors: [NSSortDescriptor(key: #keyPath(Game.name), ascending: true)],
                                         predicate: NSPredicate(format: "%K == %@", #keyPath(Game.type), system.gameType.rawValue))
    }
    
    var body: some View {
        Toggle("Delete Mode", isOn: $isDeleting)
        
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 125), spacing: 25)]) {
            ForEach(self.games) { (game) in
                Button(action: { !isDeleting ? start(game) : delete(game) }) {
                    GameCell(game: game)
                }
                .buttonStyle(PlainButtonStyle())
                .onDrag {
                    let itemProvider = NSItemProvider()
                    itemProvider.registerObject(game.startGameActivity, visibility: .all)
                    return itemProvider
                }
            }
        }
        .padding()
    }

    private func start(_ game: Game)
    {
        guard let sharedGameURL = game.sharedFileURL else { return }
        
        do
        {
            try FileManager.default.copyItem(at: game.fileURL, to: sharedGameURL, shouldReplace: true)
            
            UIApplication.shared.requestSceneSessionActivation(nil, userActivity: game.startGameActivity, options: nil) { (error) in
                print("Failed to open new window:", error)
            }
        }
        catch
        {
            print("Error copying game for emulation:", error)
        }
    }
    
    private func delete(_ game: Game)
    {        
        databaseManager.performBackgroundTask { (context) in
            let temporaryGame = context.object(with: game.objectID) as! Game
            context.delete(temporaryGame)
            context.saveWithErrorLogging()
        }
    }
}

struct GameCollectionView: View
{
    let system: System?
    let games: [Game]
    
    @State
    var activeGame: Game?
    
    @Environment(\.importFiles)
    var importFiles
    
    @StateObject
    var databaseManager: DatabaseManager = DatabaseManager.shared
    
    @State
    var isDeleting: Bool = false
    
    init(system: System?)
    {
        self.system = system
        self.games = system?.placeholderGames ?? []
    }
    
    var body: some View {
        Group {
            if !DatabaseManager.shared.isStarted
            {
                Text("Loading...")
            }
            else
            {
                if let system = system
                {
                    ScrollView {
                        InternalView(system: system)
                    }
                }
                else
                {
                    ZStack {
                        Text("No System Selected")
                            .font(.title)
                    }
                }
            }
        }
        .navigationTitle(self.system?.localizedName ?? "")
        .toolbar(items: {
            ToolbarItem {
                Button(action: importGame) {
                    Text("Import")
                }
            }
        })
        .navigationBarHidden(UIDevice.current.userInterfaceIdiom == .mac ? true : false)
        .environmentObject(databaseManager)
        .environment(\.managedObjectContext, databaseManager.viewContext)
    }
    
    private func importGame()
    {
        importFiles(multipleOfType: [.deltaGame, .deltaGameGBA]) { (result) in
            guard let result = result else { return }
            
            do
            {
                let fileURLs = try result.get()
                databaseManager.importGames(at: Set(fileURLs)) { (games, errors) in
                    print("Imported games: \(games). Errors: \(errors)")
                }
            }
            catch
            {
                print("Failed to import game:", error)
            }
        }
    }
    
    private func startProcess()
    {
//        self.remoteProcess.connect()
    }
}

struct GameCollectionView_Previews: PreviewProvider {
    static var previews: some View {
        DatabaseManager.shared.start { (error) in
            print("Started database:", error)
        }
        
        return GameCollectionView(system: .gba)
            .previewLayout(.fixed(width: 960, height: 640))
    }
}
