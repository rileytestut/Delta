//
//  DeltaMacApp.swift
//  DeltaMac
//
//  Created by Riley Testut on 7/24/20.
//  Copyright © 2020 Riley Testut. All rights reserved.
//

import SwiftUI

@main
struct DeltaMacApp: App
{
    @UIApplicationDelegateAdaptor(AppDelegate.self)
    var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .edgesIgnoringSafeArea(/*@START_MENU_TOKEN@*/.all/*@END_MENU_TOKEN@*/)
                .background(Color.orange)
        }
//        .windowStyle(HiddenTitleBarWindowStyle())
//        .windowToolbarStyle(ExpandedWindowToolbarStyle())
    }
}
