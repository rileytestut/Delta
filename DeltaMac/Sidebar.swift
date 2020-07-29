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
        List(System.allCases.sorted(), id: \.self, selection: $system) { (system) in
            Text(system.localizedName)
//            Label(system.localizedName, systemImage: "gamecontroller")
//                .padding(.vertical, 8)
//                .tag(system)
//                .environment(\.editMode, .constant(EditMode.inactive))
//            NavigationLink(destination: GameCollectionView(system: system)) {
//
//            }
//            .buttonStyle(PlainButtonStyle())
        }
//        .environment(\.editMode, .constant(EditMode.active))
        .listStyle(SidebarListStyle())
        .navigationTitle(system?.localizedName ?? "")
        .navigationBarHidden(true)
    }
}

struct Sidebar_Previews: PreviewProvider {
    static var previews: some View {
        Sidebar(system: .constant(.nes))
            .previewLayout(.fixed(width: 320, height: 568))
    }
}
