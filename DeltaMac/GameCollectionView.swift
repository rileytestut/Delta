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

import MelonDSDeltaCore

extension UTType
{
    static let deltaGame = UTType(exportedAs: "com.rileytestut.delta.game")
//    static let deltaGameGBA = UTType(exportedAs: "com.rileytestut.delta.game.gba", conformingTo: .deltaGame)
    static let deltaGameGBC = UTType(exportedAs: "com.rileytestut.delta.game.gbc", conformingTo: .deltaGame)
    
    static let deltaGameGBA = UTType(filenameExtension: "gba")!
    
    static let deltaGameSaveFile = UTType(exportedAs: "com.rileytestut.delta.game.save")
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

extension NSError: Identifiable
{
}

enum BIOS: Int
{
    case bios7
    case bios9
    case firmware
    
    var fileURL: URL? {
        guard let sharedDirectory = DatabaseManager.sharedDirectory else { return nil }
        
        switch self
        {
        case .bios7: return sharedDirectory.appendingPathComponent(MelonDSEmulatorBridge.shared.bios7URL.lastPathComponent)
        case .bios9: return sharedDirectory.appendingPathComponent(MelonDSEmulatorBridge.shared.bios9URL.lastPathComponent)
        case .firmware: return sharedDirectory.appendingPathComponent(MelonDSEmulatorBridge.shared.firmwareURL.lastPathComponent)
        }
    }
}

struct StartGameOption: RawRepresentable, Hashable
{
    let rawValue: String
    
    static let linkRole = StartGameOption(rawValue: "linkRole")
}

struct InternalView: View
{
    enum SortingOption: CaseIterable
    {
        case ascending
        case descending
    }
    
    let system: System
    
    var games: FetchedResults<Game> { fetchRequest.wrappedValue }
    private let fetchRequest: FetchRequest<Game>
    
    @EnvironmentObject
    var databaseManager: DatabaseManager
    
    @Environment(\.importFiles)
    var importFiles
    
    @Environment(\.exportFiles)
    var exportFiles
    
    @State
    var sortingOption: SortingOption = .ascending
    
    @State
    var deletingGame: Game? = nil
    
    @State
    var error: NSError?
    
    init(system: System)
    {
        self.system = system
        self.fetchRequest = FetchRequest(sortDescriptors: [NSSortDescriptor(key: #keyPath(Game.name), ascending: true)],
                                         predicate: NSPredicate(format: "%K == %@", #keyPath(Game.type), system.gameType.rawValue))
    }
    
    var body: some View {
        ZStack {
            Color.clear
            .alert(item: $error) { (error) -> Alert in
                Alert(title: Text(error.localizedDescription), message: error.localizedFailureReason.map { Text($0) }, dismissButton: .cancel(Text("OK")))
            }
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 125), spacing: 25)]) {
                ForEach(self.games) { (game) in
                    Button(action: { start(game) }) {
                        GameCell(game: game)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .contextMenu {
                        
                        if game.type == .gba
                        {
                            Button(action: { start(game, options: [.linkRole: LinkRole.server]) }) {
                                Label("Start Link - Server", systemImage: "link.icloud")
                            }
                            
                            Button(action: { start(game, options: [.linkRole: LinkRole.client]) }) {
                                Label("Start Link - Client", systemImage: "link")
                            }
                            
                            Divider()
                        }
                        
                        Button(action: { importSave(for: game) }) {
                            Label("Import Save File", systemImage: "square.and.arrow.down")
                        }
                        
                        Button(action: { error = EmulatorProcess.ProcessError.crashed as NSError }) {
                            Label("Export Save File", systemImage: "square.and.arrow.up")
                        }
                        
                        Divider()
                        
                        if game.type == .ds
                        {
                            let isBios7Installed = BIOS.bios7.fileURL.map { FileManager.default.fileExists(atPath: $0.path) } ?? false
                            let isBios9Installed = BIOS.bios9.fileURL.map { FileManager.default.fileExists(atPath: $0.path) } ?? false
                            let isFirmwareInstalled = BIOS.firmware.fileURL.map { FileManager.default.fileExists(atPath: $0.path) } ?? false
                            
                            Menu {
                                Button(action: { importBIOS(.bios7) }) {
                                    Label("bios7.bin", systemImage: isBios7Installed ? "checkmark" : "")
                                }
                                
                                Button(action: { importBIOS(.bios9) }) {
                                    Label("bios9.bin", systemImage: isBios9Installed ? "checkmark" : "")
                                }
                                
                                Button(action: { importBIOS(.firmware) }) {
                                    Label("firmware.bin", systemImage: isFirmwareInstalled ? "checkmark" : "")
                                }
                            } label: {
                                Label("Import BIOS", systemImage: "pc")
                            }
                            
                            Divider()
                        }
                                            
                        Button(action: { deletingGame = game }) {
                            Label("Delete Game", systemImage: "trash")
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .onDrag {
                        let itemProvider = NSItemProvider()
                        itemProvider.registerObject(game.startGameActivity, visibility: .all)
                        return itemProvider
                    }
                    .alert(item: $deletingGame) { (game) -> Alert in
                        Alert(title: Text("Are you sure you want to delete \(game.name)?"),
                              primaryButton: .cancel(),
                              secondaryButton: .destructive(Text("Delete")) {
                            delete(game)
                        })
                    }
                }
                
            }
            .padding()
        }
    }

    private func start(_ game: Game, options: [StartGameOption: Any] = [:])
    {
        guard let sharedGameURL = game.sharedFileURL else { return }
        
        do
        {
            try FileManager.default.copyItem(at: game.fileURL, to: sharedGameURL, shouldReplace: true)
                        
            let rawOptions = options.compactMap { (option, value) -> (String, Any)? in
                switch (option, value)
                {
                case (.linkRole, let value as LinkRole): return (option.rawValue, value.rawValue)
                default: return nil
                }
            }.reduce(into: [:]) { $0[$1.0] = $1.1 }
            
            let activity = game.startGameActivity
            activity.addUserInfoEntries(from: rawOptions)
            UIApplication.shared.requestSceneSessionActivation(nil, userActivity: activity, options: nil) { (error) in
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
    
    private func rename(_ game: Game)
    {
        databaseManager.performBackgroundTask { (context) in
            let temporaryGame = context.object(with: game.objectID) as! Game
            context.delete(temporaryGame)
            context.saveWithErrorLogging()
        }
    }
    
    private func importSave(for game: Game)
    {
        let type = UTType(filenameExtension: "sav")!
        
        importFiles(singleOfType: [.deltaGameSaveFile, type]) { (result) in
            guard let result = result else { return }
            
            do {
                let fileURL = try result.get()
                guard fileURL.startAccessingSecurityScopedResource() else { return }
                defer { fileURL.stopAccessingSecurityScopedResource() }
                
                guard let sharedGameSaveURL = game.sharedGameSaveURL else { return }
                try FileManager.default.copyItem(at: fileURL, to: sharedGameSaveURL, shouldReplace: true)
            }
            catch { self.error = error as NSError }
        }
    }
    
    private func exportSave(for game: Game)
    {
        guard let sharedGameSaveURL = game.sharedGameSaveURL else { return }
        
        do
        {
            let fileWrapper = try FileWrapper(url: sharedGameSaveURL, options: [.immediate])
            fileWrapper.filename = game.name.sanitized(with: CharacterSet.alphanumerics.union(.init(charactersIn: " "))) + ".sav"
            
            exportFiles(fileWrapper, contentType: .deltaGameSaveFile) { (result) in
                switch result
                {
                case nil: break
                case .failure(let error): self.error = error as NSError
                case .success(let fileURL): print("Exporting game save to file URL:", fileURL)
                }
            }
        }
        catch
        {
            self.error = error as NSError
        }
    }
    
    private func importBIOS(_ bios: BIOS)
    {
        let binUTI = UTType(filenameExtension: "bin")!
        let firmwareUTI = UTType(filenameExtension: "firmware")!
        let romUTI = UTType(filenameExtension: "rom")!
        
        importFiles(singleOfType: [binUTI, firmwareUTI, romUTI]) { (result) in
            guard let result = result, let biosFileURL = bios.fileURL else { return }

            do
            {
                let fileURL = try result.get()
                
                guard fileURL.startAccessingSecurityScopedResource() else { return }
                defer { fileURL.stopAccessingSecurityScopedResource() }
                
                try FileManager.default.copyItem(at: fileURL, to: biosFileURL, shouldReplace: true)
            }
            catch
            {
                print("Failed to import BIOS:", error)
                self.error = error as NSError
            }
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
