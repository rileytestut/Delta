//
//  CheatsView.swift
//  Delta
//
//  Created by Natalie Pekker on 3/19/26.
//  Copyright © 2026 Riley Testut. All rights reserved.
//

import SwiftUI
import CoreData

@available(iOS 26, *)
extension CheatsView
{
    class HostingController: UIHostingController<AnyView>, EditCheatViewControllerDelegate
    {
        var game: Game
        
        var activateCheat: ((Cheat) -> Void)?
        var deactivateCheat: ((Cheat) -> Void)?
        
        required dynamic init?(coder aDecoder: NSCoder)
        {
            fatalError("init(coder:) has not been implemented")
        }
        
        init(game: Game)
        {
            self.game = game
            
            super.init(rootView: AnyView(EmptyView()))
            
            let cheatsView = CheatsView(hostingViewController: self)
                .environment(\.managedObjectContext, DatabaseManager.shared.viewContext)
            self.rootView = AnyView(cheatsView)
            self.view.backgroundColor = .clear
        }
        
        @IBAction private func unwindFromEditCheatViewController(_ segue: UIStoryboardSegue) { }
        
        func editCheatViewController(_ editCheatViewController: EditCheatViewController, activateCheat cheat: Cheat, previousCheat: Cheat?) {
            self.activateCheat?(cheat)
            
            if let previousCheat = previousCheat {
                self.deactivateCheat?(previousCheat)
            }
        }
        
        func editCheatViewController(_ editCheatViewController: EditCheatViewController, deactivateCheat cheat: Cheat) {
            self.deactivateCheat?(cheat)
        }
    }
}

@available(iOS 26, *)
extension CheatsView
{
    enum Sorting: String, CaseIterable
    {
        case name
        case dateAdded
        case modifiedDate
        
        var localizedName: String {
            switch self {
            case .name: return String(localized: "Name")
            case .dateAdded: return String(localized: "Date Added")
            case .modifiedDate: return String(localized: "Date Modified")
            }
        }
    }
}

@available(iOS 26, *)
struct CheatsView: View
{
    @FetchRequest
    private var cheats: FetchedResults<Cheat>
    
    fileprivate var hostingViewController: HostingController
    
    @SwiftUI.State
    private var sorting: Sorting = .name
    
    @SwiftUI.State
    private var prefersDescending: Bool = false
    
    init(hostingViewController: HostingController)
    {
        self.hostingViewController = hostingViewController
        _cheats = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \Cheat.name, ascending: true)],
            predicate: NSPredicate(format: "%K == %@", #keyPath(Cheat.game), hostingViewController.game)
        )
    }
    
    var body: some View {
        List(cheats, id: \.self) { cheat in
            CheatsButton(cheat: cheat, onEdit: { edit(cheat) }, onToggle: { toggle(cheat) })
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button {
                        edit(cheat)
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(.gray)
                    
                    Button(role: .destructive) {
                        delete(cheat)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                sortingMenu
            }
            
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
            
            ToolbarItem(placement: .topBarTrailing) {
                addCheatButton
            }
        }
        .navigationTitle("Cheats")
        .scrollContentBackground(.hidden)
        .onAppear(perform: loadSortPreferences)
        .onChange(of: sorting) {
            applySorting()
        }
        .onChange(of: prefersDescending) {
            applySorting()
        }
    }
    
    private var sortingMenu: some View {
        Menu {
            ForEach(Sorting.allCases, id: \.self) { option in
                Button {
                    toggleSort(for: option)
                } label: {
                    Label {
                        Text(option.localizedName)
                    } icon: {
                        if sorting == option {
                            Image(systemName: prefersDescending ? "chevron.down" : "chevron.up")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
        }
    }
    
    private var addCheatButton: some View {
        Button {
            add()
        } label: {
            Image(systemName: "plus")
        }
    }
}

@available(iOS 26, *)
private extension CheatsView
{
    func sortDescriptors(for sorting: Sorting, descending: Bool) -> [NSSortDescriptor]
    {
        let ascending = !descending
        
        switch sorting {
        case .name: return [NSSortDescriptor(keyPath: \Cheat.name, ascending: ascending)]
        case .dateAdded:
            return [
                NSSortDescriptor(keyPath: \Cheat.creationDate, ascending: ascending),
                NSSortDescriptor(keyPath: \Cheat.name, ascending: true)
            ]
        case .modifiedDate:
            return [
                NSSortDescriptor(keyPath: \Cheat.modifiedDate, ascending: ascending),
                NSSortDescriptor(keyPath: \Cheat.name, ascending: true)
            ]
        }
    }
    
    func loadSortPreferences()
    {
        if let savedSorting = Sorting(rawValue: Settings.cheatSorting) {
            sorting = savedSorting
        }
        
        prefersDescending = Settings.cheatSortDescending
        applySorting()
    }
    
    func applySorting()
    {
        cheats.nsSortDescriptors = sortDescriptors(for: sorting, descending: prefersDescending)
    }
    
    func toggleSort(for option: Sorting)
    {
        if sorting == option {
            prefersDescending.toggle()
        } else {
            sorting = option
            prefersDescending = false
        }
        
        Settings.cheatSorting = sorting.rawValue
        Settings.cheatSortDescending = prefersDescending
    }
    
    func toggle(_ cheat: Cheat)
    {
        let backgroundContext = DatabaseManager.shared.newBackgroundContext()
        backgroundContext.performAndWait() {
            let temporaryCheat = backgroundContext.object(with: cheat.objectID) as! Cheat
            temporaryCheat.isEnabled.toggle()
            
            if temporaryCheat.isEnabled {
                hostingViewController.activateCheat?(temporaryCheat)
            } else {
                hostingViewController.deactivateCheat?(temporaryCheat)
            }
            
            backgroundContext.saveWithErrorLogging()
        }
    }
    
    func delete(_ cheat: Cheat)
    {
        hostingViewController.deactivateCheat?(cheat)
        
        DatabaseManager.shared.performBackgroundTask { (context) in
            let temporaryCheat = context.object(with: cheat.objectID)
            context.delete(temporaryCheat)
            context.saveWithErrorLogging()
        }
    }
    
    func edit(_ cheat: Cheat)
    {
        let editCheatViewController = UIStoryboard(name: "PauseMenu", bundle: nil).instantiateViewController(withIdentifier: "editCheatViewController") as! EditCheatViewController
        editCheatViewController.delegate = hostingViewController
        editCheatViewController.cheat = cheat
        editCheatViewController.game = hostingViewController.game

        let navigationController = UINavigationController(rootViewController: editCheatViewController)
        hostingViewController.present(navigationController, animated: true, completion: nil)
    }
    
    func add()
    {
        let editCheatViewController = UIStoryboard(name: "PauseMenu", bundle: nil).instantiateViewController(withIdentifier: "editCheatViewController") as! EditCheatViewController
        editCheatViewController.delegate = hostingViewController
        editCheatViewController.game = hostingViewController.game

        let navigationController = UINavigationController(rootViewController: editCheatViewController)
        hostingViewController.present(navigationController, animated: true, completion: nil)
    }
}
