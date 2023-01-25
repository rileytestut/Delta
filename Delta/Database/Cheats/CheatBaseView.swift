//
//  CheatBaseView.swift
//  Delta
//
//  Created by Riley Testut on 1/17/23.
//  Copyright © 2023 Riley Testut. All rights reserved.
//

import SwiftUI

@available(iOS 14, *)
extension CheatBaseView
{
    private class ViewModel: ObservableObject
    {
        @Published
        private(set) var database: CheatBase?
        
        @Published
        private(set) var allCheats: [CheatMetadata]?
        
        @Published
        private(set) var cheatsByCategory: [(CheatCategory, [CheatMetadata])]?
        
        @Published
        private(set) var error: Error?
        
        @Published
        var searchText: String = "" {
            didSet {
                self.searchCheats()
            }
        }
        
        @Published
        private(set) var filteredCheats: [CheatMetadata]?
        
        @MainActor
        func fetchCheats(for game: Game) async
        {
            guard self.allCheats == nil else { return }
            
            do
            {
                let database = try CheatBase()
                self.database = database
                
                let cheats = try await database.cheats(for: game) ?? []
                self.allCheats = cheats
                                
                let cheatsByCategory = Dictionary(grouping: cheats, by: { $0.category }).sorted { $0.key.id < $1.key.id }
                self.cheatsByCategory = cheatsByCategory
            }
            catch
            {
                self.error = error
            }
        }
        
        private func searchCheats()
        {
            if let cheats = self.allCheats, !self.searchText.isEmpty
            {
                let predicate = NSPredicate(forSearchingForText: self.searchText, inValuesForKeyPaths: [#keyPath(CheatMetadata.name), #keyPath(CheatMetadata.cheatDescription)])
                
                let filteredCheats = cheats.filter { predicate.evaluate(with: $0) }
                self.filteredCheats = filteredCheats
            }
            else
            {
                self.filteredCheats = nil
            }
        }
    }
}

@available(iOS 14, *)
struct CheatBaseView: View
{
    let game: Game?
    
    var cancellationHandler: (() -> Void)?
    var selectionHandler: ((CheatMetadata) -> Void)?
    
    @StateObject
    private var viewModel = ViewModel()
    
    @State
    private var activationHintCheat: CheatMetadata?
    
    var body: some View {
        NavigationView {
            ZStack {
                if let cheats = viewModel.allCheats, !cheats.isEmpty
                {
                    // Only show List if there is at least one cheat for this game.
                    cheatList()
                }
                
                // Place above List
                placeholderView()
            }
            .alert(item: $activationHintCheat) { cheat in
                Alert(title: Text("Activation Hint"),
                      message: Text(cheat.activationHint ?? ""),
                      dismissButton: .default(Text("OK")))
            }
            .navigationTitle(Text(game?.name ?? "CheatBase"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        cancellationHandler?()
                    }
                }
            }
        }
        .onAppear {
            Task {
                guard let game = self.game else { return }
                await viewModel.fetchCheats(for: game)
            }
        }
    }
    
    private func cheatList() -> some View
    {
        VStack {
            if #unavailable(iOS 15)
            {
                LegacySearchBar(text: $viewModel.searchText)
            }
            
            let listView = List {
                if let filteredCheats = viewModel.filteredCheats
                {
                    ForEach(filteredCheats) { cheat in
                        cell(for: cheat)
                    }
                }
                else if let cheats = viewModel.cheatsByCategory
                {
                    ForEach(cheats, id: \.0.id) { (category, cheats) in
                        Section {
                            DisclosureGroup {
                                ForEach(cheats) { cheat in
                                    cell(for: cheat)
                                }
                            } label: {
                                Text(category.name)
                            }
                        } footer: {
                            Text(category.categoryDescription)
                        }
                    }
                }
            }
            
            if #available(iOS 15, *)
            {
                listView.searchable(text: $viewModel.searchText)
            }
            else
            {
                listView
            }
        }
        .listStyle(.insetGrouped)
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .top)
    }

    
    private func cell(for cheat: CheatMetadata) -> some View
    {
        ZStack(alignment: .leading) {
            Button(action: { choose(cheat) }) {}
            
            HStack {
                // Name + Description
                VStack(alignment: .leading, spacing: 4) {
                    Text(cheat.name)
                    
                    if let description = cheat.cheatDescription
                    {
                        Text(description)
                            .font(.caption)
                    }
                }
                
                // Activation Hint
                if cheat.activationHint != nil
                {
                    Spacer()
                    
                    Button(action: { activationHintCheat = cheat }) {
                        Image(systemName: "info.circle")
                    }
                    .buttonStyle(.borderless)
                }
            }
            .multilineTextAlignment(.leading)
        }
    }

    private func placeholderView() -> some View
    {
        VStack(spacing: 8) {
            if let error = viewModel.error
            {
                Text("Unable to Load Cheats")
                    .font(.title)
                
                Text(error.localizedDescription)
                    .font(.callout)
            }
            else if let filteredCheats = viewModel.filteredCheats, filteredCheats.isEmpty
            {
                Text("Cheat Not Found")
                    .font(.title)
                
                Text("Please make sure the name is correct, or try searching for another cheat.")
                    .font(.callout)
            }
            else if let cheats = viewModel.allCheats, cheats.isEmpty
            {
                Text("No Cheats")
                    .font(.title)
                
                Text("There are no cheats for this game in Delta's CheatBase. Please try a different game.")
                    .font(.callout)
            }
            else if viewModel.allCheats == nil
            {
                ProgressView()
                    .progressViewStyle(.circular)
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .center)
        .foregroundColor(.gray)
        .padding()
    }
}

@available(iOS 14, *)
private extension CheatBaseView
{
    func choose(_ cheatMetadata: CheatMetadata)
    {
        self.selectionHandler?(cheatMetadata)
    }
}
