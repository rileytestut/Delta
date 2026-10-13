//
//  FriendZonePatronsView.swift
//  Delta
//
//  Created by Riley Testut on 10/1/26.
//  Copyright © 2026 Riley Testut. All rights reserved.
//

import SwiftUI
import CoreData

struct FriendZonePatronsView: View
{
    private let columns = [GridItem(.flexible()), GridItem(.flexible())]
    
    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(key: #keyPath(ManagedPatron.name), ascending: true, selector: #selector(NSString.localizedStandardCompare(_:))
        )]
    )
    private var patrons: FetchedResults<ManagedPatron>
    
    var body: some View {
        let result = FriendZoneManager.shared.updatePatronsResult
        
        // Lay out names in 2-column grid
        LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
            
            Section {
                ForEach(patrons, id: \.objectID) { patron in
                    if let name = patron.name
                    {
                        Text(name)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                // Headers can fill full width
                switch result
                {
                case .success, nil:
                    Text("Special thanks to…")
                        .bold()
                        .foregroundStyle(.secondary)
                        .font(.callout)
                    
                case .failure(let error):
                    VStack {
                        Text("Unable to Load Friend Zone Patrons")
                            .bold()
                            .foregroundStyle(.secondary)
                        
                        Text(error.localizedDescription)
                            .foregroundStyle(.secondary)
                    }
                }
            } footer: {
                // Footers can fill full width
                if result == nil
                {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            
        }
        .task {
            // User explicitly navigated to this screen, so allow fetching friend zone patrons.
            UserDefaults.standard.shouldFetchFriendZonePatrons = true
            
            if #available(iOS 17.5, *)
            {
                FriendZoneManager.shared.updatePatronsIfNeeded()
            }
        }
    }
}

#Preview {
    FriendZonePatronsView()
}
