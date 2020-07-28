//
//  ContentView.swift
//  DeltaMac
//
//  Created by Riley Testut on 7/24/20.
//  Copyright © 2020 Riley Testut. All rights reserved.
//

import SwiftUI
import UIKit

struct ContentView: View
{
    @State var system: System? = nil
    
    var body: some View {
        HStack {
//            Color.red
//                .edgesIgnoringSafeArea(/*@START_MENU_TOKEN@*/.all/*@END_MENU_TOKEN@*/)
            
            
//            NavigationView {
//                Color.orange
//                Color.yellow
//            }
//            RootView(primary:
////                        Color.orange,
//                        Sidebar(system: $system)
//                        .background(Color.purple)
//                        .edgesIgnoringSafeArea(/*@START_MENU_TOKEN@*/.all/*@END_MENU_TOKEN@*/),
//                     secondary: ZStack {
//                        Color.yellow
//                            .edgesIgnoringSafeArea(.all)
//                     })
//                .navigationTitle("Hello")
        }
        
        
        NavigationView {
            Sidebar(system: $system)
            GameCollectionView(system: system)
        }
//
//        .navigationViewStyle(DoubleColumnNavigationViewStyle())
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(system: .nes)
            .previewLayout(.fixed(width: 960, height: 640))
    }
}
