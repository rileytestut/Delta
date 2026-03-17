//
//  PauseView.swift
//  Delta
//
//  Created by Riley Testut on 3/2/26.
//  Copyright © 2026 Riley Testut. All rights reserved.
//

import SwiftUI

@available(iOS 26, *)
struct PauseViewOld: View
{
    let bottomInset = 300
    
    var items: [MenuItem] = []
    
    // Two flexible columns
    private let columns = [
        GridItem(.fixed(145)),
        GridItem(.fixed(145)),
    ]
    
    @Environment(\.horizontalSizeClass) private var hSize
    @Environment(\.verticalSizeClass) private var vSize
    
    private var isLandscape: Bool {
        false
//        hSize == .regular && vSize == .compact
    }
    
    private let rows = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    // Content size needs to be (scroll view height) + 2x (screen.height/3 - (screen.height - scrollView.bounds.maxY))
    
    var pauseMenu: some View {
        LazyVGrid(columns: columns, spacing: 15) {
            ForEach(items, id: \.self) { item in
                MenuItemButton(item: item)
//                    .frame(maxWidth: .infinity)
            }
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView(.horizontal) {
                ContainerRelativeGrid(pageWidth: geometry.size.width, itemWidth: 145) {
                    let saveStateItem = MenuItem(text: NSLocalizedString("Save State", comment: ""), image: #imageLiteral(resourceName: "SaveSaveState"), action: { _ in })
                    
                    let loadStateItem = MenuItem(text: NSLocalizedString("Load State", comment: ""), image: #imageLiteral(resourceName: "LoadSaveState"), action: { _ in })
                    
                    let cheatCodesItem = MenuItem(text: NSLocalizedString("Cheat Codes", comment: ""), image: #imageLiteral(resourceName: "CheatCodes"), action: { _ in })
                    
                    let fastForwardItem = MenuItem(text: NSLocalizedString("Fast Forward", comment: ""), image: #imageLiteral(resourceName: "FastForward"), action: { _ in })
                    let sustainButtonsItem = MenuItem(text: NSLocalizedString("Hold Buttons", comment: ""), image: #imageLiteral(resourceName: "SustainButtons"), action: { _ in })
                    let screenshotItem = MenuItem(text: NSLocalizedString("Screenshot", comment: ""), image: #imageLiteral(resourceName: "Screenshot"), action: { _ in })
                    
                    let optionA = MenuItem(text: NSLocalizedString("Option A", comment: ""), image: #imageLiteral(resourceName: "Screenshot"), action: { _ in })
                    let optionB = MenuItem(text: NSLocalizedString("Option B", comment: ""), image: #imageLiteral(resourceName: "Screenshot"), action: { _ in })
                    let optionC = MenuItem(text: NSLocalizedString("Option C", comment: ""), image: #imageLiteral(resourceName: "Screenshot"), action: { _ in })
                    let optionD = MenuItem(text: NSLocalizedString("Option D", comment: ""), image: #imageLiteral(resourceName: "Screenshot"), action: { _ in })
                    let optionE = MenuItem(text: NSLocalizedString("Option E", comment: ""), image: #imageLiteral(resourceName: "Screenshot"), action: { _ in })
                    let optionF = MenuItem(text: NSLocalizedString("Option F", comment: ""), image: #imageLiteral(resourceName: "Screenshot"), action: { _ in })
                    let optionG = MenuItem(text: NSLocalizedString("Option G", comment: ""), image: #imageLiteral(resourceName: "Screenshot"), action: { _ in })
                    let optionH = MenuItem(text: NSLocalizedString("Option H", comment: ""), image: #imageLiteral(resourceName: "Screenshot"), action: { _ in })
                    
                    let menuItems = [saveStateItem, loadStateItem, cheatCodesItem, fastForwardItem, sustainButtonsItem, screenshotItem, optionA, optionB, optionC, optionD, optionE, optionF, optionG, optionH]
                    ForEach(menuItems, id: \.text) { item in
                        MenuItemButton(item: item)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
//                            .background(Color.yellow)
                    }
                }
                .frame(height: geometry.size.height) //FIXME: Fix this hard coding
//                .frame(height: geometry.size.height)
    //            .containerRelativeFrame([.vertical, .horizontal]) { (length, axis) in length * 1 }
//                .background(Color.red)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea(edges: .top)
    //        .containerRelativeFrame(.horizontal) { (length, axis) in length * 1 }
//            .background(Color.purple)
        }
    }
    
    var bodyOld: some View {
        GeometryReader { geo in
            let pageWidth = geo.size.width

            TabView {
                LazyVGrid(
                    columns: columns,
                    spacing: 16
                ) {
                    ForEach(items, id: \.self) { item in
                        MenuItemButton(item: item)
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(width: pageWidth)
                .frame(height: geo.size.height)
                .background(Color.blue)
//                .padding()
                
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
    }
    
    var body0: some View {
        GeometryReader { geometry in
            HStack(alignment: .center) {
                TabView {
                    HStack {
                        LazyVGrid(columns: columns, spacing: 15) {
                            ForEach(items, id: \.self) { item in
                                MenuItemButton(item: item)
                            }
                        }
                        .frame(height: geometry.size.height)
    //                    .frame(width: 145 * 2)
                        .background(Color.blue)
                        .scrollTargetLayout()          // iOS 17+ paging
                    }
                    .frame(width: geometry.size.width)
//                    .background(Color.red)
                }
                .scrollTargetBehavior(.paging)    // horizontal snapping
                .frame(width: geometry.size.width)
                .frame(height: geometry.size.height)
//                .background(Color.yellow)
            }
            .frame(width: geometry.size.width)
        }
        .background(Color.purple)
    }
    
    var body3: some View {
        ScrollView(.horizontal) {
            GlassEffectContainer {
                LazyVGrid(columns: columns, alignment: .center, spacing: 15) {
                    ForEach(items, id: \.self) { item in
                        Button("Hello") {}
                            .frame(maxWidth: .infinity) // make button fill the column
                            .background(Color.yellow)
                            .frame(height: 100)         // give it some height
                            .background(Color.red)
                            .cornerRadius(12)
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.2)) // optional, just to see the grid
            }
            .padding(.horizontal, 20)
            .glassEffectTransition(.materialize)
        }
        .scrollTargetBehavior(.paging)
    }
    
    var body2: some View {
        ScrollView(.horizontal) {
//            Color.clear
//                    .frame(height: 200) // 👈 invisible scroll area
            
            HStack {
                if isLandscape
                {
                    LazyHGrid(rows: rows, spacing: 16) {
                        ForEach(items, id: \.text) { item in
                            MenuItemButton(item: item)
                        }
                    }
                }
                else
                {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(items, id: \.text) { item in
                            MenuItemButton(item: item)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)  // centers the grid inside HStack
            .background(Color.blue)
            .padding(.horizontal, 20)
            .glassEffectTransition(.materialize)
            
            
            
            
            .scrollTargetLayout()
//            .padding()
            
//            Color.clear
//                    .frame(height: 200) // 👈 invisible scroll area
        }
        .scrollTargetBehavior(.paging)
        .scrollIndicators(.hidden)
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                Button("Main Menu", systemImage: "house.fill", role: .close, action: {})
                    .glassEffect()
//                Button(role: .cancel, action: {})
                
                Spacer()
                
                Button("Resume", systemImage: "play.fill", role: .confirm, action: {})
                    .glassEffect()
                    .tint(Color(uiColor: .deltaPurple))
            }
        }
        .tint(.white)
//        .safeAreaInset(edge: .top) {
//            Color.clear
//                .frame(height: 400)
//        }
//        .safeAreaInset(edge: .bottom) {
//            Color.clear
//                .frame(height: 400)
//        }
    }
}

//@available(iOS 26, *)
//struct MenuItemButton: View
//{
//    @State
//    var item: MenuItem
//    
//    var body: some View {
//        Button {
//            item.action(item)
//        } label: {
//            VStack(spacing: 10) {
//                if let image = item.image
//                {
//                    Image(uiImage: image)
//                        .frame(width: 44, height: 44)
//                }
//                
//                Text(item.text)
//                    .font(.headline)
//            }
//            .foregroundStyle(.white)
//        }
//        .buttonStyle(.plain)
//        .frame(width: 145, height: 115)
//        .glassEffect(.clear.interactive(), in: .rect(cornerRadius: 32.0))
//    }
//}

@available(iOS 26, *)
#Preview {
    let saveStateItem = MenuItem(text: NSLocalizedString("Save State", comment: ""), image: #imageLiteral(resourceName: "SaveSaveState"), action: { _ in })
    
    let loadStateItem = MenuItem(text: NSLocalizedString("Load State", comment: ""), image: #imageLiteral(resourceName: "LoadSaveState"), action: { _ in })
    
    let cheatCodesItem = MenuItem(text: NSLocalizedString("Cheat Codes", comment: ""), image: #imageLiteral(resourceName: "CheatCodes"), action: { _ in })
    
    let fastForwardItem = MenuItem(text: NSLocalizedString("Fast Forward", comment: ""), image: #imageLiteral(resourceName: "FastForward"), action: { _ in })
    let sustainButtonsItem = MenuItem(text: NSLocalizedString("Hold Buttons", comment: ""), image: #imageLiteral(resourceName: "SustainButtons"), action: { _ in })
    let screenshotItem = MenuItem(text: NSLocalizedString("Screenshot", comment: ""), image: #imageLiteral(resourceName: "Screenshot"), action: { _ in })
    
    NavigationView {
        PauseView(items: [saveStateItem, loadStateItem, cheatCodesItem, fastForwardItem, sustainButtonsItem, screenshotItem])
//            .frame(maxWidth: .infinity, maxHeight: .infinity)
//            .frame(height: 300)
    }
}
