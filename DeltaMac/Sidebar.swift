//
//  Sidebar.swift
//  DeltaMac
//
//  Created by Riley Testut on 7/24/20.
//  Copyright © 2020 Riley Testut. All rights reserved.
//

import SwiftUI
import UIKit

struct Sidebar: View
{
    @Binding var system: System?

    var body: some View {
        List(System.allCases.sorted()) { (system) in
            NavigationLink(destination: GameCollectionView(system: system)) {
                Label(system.localizedName, systemImage: "gamecontroller")
                    .padding(.vertical, 8)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .listStyle(SidebarListStyle())
        .navigationTitle(system?.localizedName ?? "")
    }
}

struct Sidebar_Previews: PreviewProvider {
    static var previews: some View {
        Sidebar(system: .constant(.nes))
            .previewLayout(.fixed(width: 320, height: 568))
    }
}
