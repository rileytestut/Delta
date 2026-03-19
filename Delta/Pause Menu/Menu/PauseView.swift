//
//  PauseView.swift
//  Delta
//
//  Created by Riley Testut on 3/9/26.
//  Copyright © 2026 Riley Testut. All rights reserved.
//

import SwiftUI

@available(iOS 26, *)
extension PauseView
{
    @Observable
    class HostingController: UIHostingController<AnyView> // PauseView.environment(self)
    {
        fileprivate private(set) var isHidden: Bool = true
        fileprivate private(set) var isAnimated: Bool = true
        
        var resumeHandler: () -> Void = {}
        var stopHandler: () -> Void = {}
        
        required dynamic init?(coder aDecoder: NSCoder)
        {
            fatalError("init(coder:) has not been implemented")
        }
        
        init(items: [MenuItem], resumeHandler: @escaping () -> Void = {}, stopHandler: @escaping () -> Void = {})
        {
            self.resumeHandler = resumeHandler
            self.stopHandler = stopHandler
            
            super.init(rootView: AnyView(EmptyView()))
            
            let pauseView = PauseView(items: items, resumeHandler: resumeHandler, stopHandler: stopHandler).environment(self)
            self.rootView = AnyView(pauseView)
        }
        
        override func viewDidLoad()
        {
            super.viewDidLoad()
            
            self.view.backgroundColor = .clear
            self.navigationItem.standardAppearance = nil
        }
        
        func showItems(animated: Bool = true)
        {
            self.isAnimated = animated
            self.isHidden = false
        }
        
        func hideItems(animated: Bool = true)
        {
            self.isAnimated = animated
            self.isHidden = true
        }
    }
}

@available(iOS 26, *)
struct PauseView: View
{
    var items: [MenuItem] = []
    
    var resumeHandler: () -> Void = {}
    var stopHandler: () -> Void = {}
    
    @Environment(HostingController.self)
    private var hostingViewController
    
    @State
    private var isHidden: Bool = true
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView(.horizontal) {
                GlassEffectContainer {
                    ContainerRelativeGrid(pageWidth: geometry.size.width, itemWidth: MenuItemButton.preferredSize.width) {
                        if !isHidden
                        {
                            ForEach(items, id: \.text) { item in
                                MenuItemButton(item: item, isHidden: isHidden)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity) // Fill proposed frame with glass effect
                            }
                        }
                    }
                    .frame(height: geometry.size.height) // Match grid height to scroll view height, but allow width to grow.
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity) // Fill proposed frame with ScrollView.
        }
        .ignoresSafeArea(edges: [.top, .bottom])
        .navigationTitle(Text("")) // HACK: Fixes UI glitch when transitioning to SaveStatesViewController.
        .navigationBarTitleDisplayMode(.large)
        .toolbarVisibility(isHidden ? .hidden : .visible, for: .bottomBar)
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                Button("Main Menu", systemImage: "house.fill", role: .close, action: stopHandler)
                    .glassEffect()
                    .glassEffectTransition(.materialize)
                
                Spacer()
                
                Button("Resume", systemImage: "play.fill", role: .confirm, action: resumeHandler)
                    //.glassEffect(.regular.tint(Color(uiColor: .deltaPurple))) // Doesn't work as expected :(
                    .glassEffect()
                    .tint(Color(uiColor: .deltaPurple))
                    .glassEffectTransition(.materialize)
            }
        }
        .onAppear {
            isHidden = hostingViewController.isHidden
        }
        .onChange(of: hostingViewController.isHidden) { oldValue, newValue in
            guard oldValue != newValue else { return }
            
            if hostingViewController.isAnimated
            {
                withAnimation {
                    isHidden = newValue
                }
            }
            else
            {
                isHidden = newValue
            }
        }
    }
}

@available(iOS 26, *)
#Preview {
    let saveStateItem = MenuItem(text: NSLocalizedString("Save State", comment: ""), image: #imageLiteral(resourceName: "SaveSaveState"), action: { $0.isSelected.toggle() })
    let loadStateItem = MenuItem(text: NSLocalizedString("Load State", comment: ""), image: #imageLiteral(resourceName: "LoadSaveState"), action: { $0.isSelected.toggle() })
    let cheatCodesItem = MenuItem(text: NSLocalizedString("Cheat Codes", comment: ""), image: #imageLiteral(resourceName: "CheatCodes"), action: { $0.isSelected.toggle() })
    let fastForwardItem = MenuItem(text: NSLocalizedString("Fast Forward", comment: ""), image: #imageLiteral(resourceName: "FastForward"), action: { $0.isSelected.toggle() })
    let sustainButtonsItem = MenuItem(text: NSLocalizedString("Hold Buttons", comment: ""), image: #imageLiteral(resourceName: "SustainButtons"), action: { $0.isSelected.toggle() })
    let screenshotItem = MenuItem(text: NSLocalizedString("Screenshot", comment: ""), image: #imageLiteral(resourceName: "Screenshot"), action: { $0.isSelected.toggle() })
    
    let optionA = MenuItem(text: NSLocalizedString("Option A", comment: ""), image: #imageLiteral(resourceName: "Screenshot"), action: { $0.isSelected.toggle() })
    let optionB = MenuItem(text: NSLocalizedString("Option B", comment: ""), image: #imageLiteral(resourceName: "Screenshot"), action: { $0.isSelected.toggle() })
    let optionC = MenuItem(text: NSLocalizedString("Option C", comment: ""), image: #imageLiteral(resourceName: "Screenshot"), action: { $0.isSelected.toggle() })
    let optionD = MenuItem(text: NSLocalizedString("Option D", comment: ""), image: #imageLiteral(resourceName: "Screenshot"), action: { $0.isSelected.toggle() })
    let optionE = MenuItem(text: NSLocalizedString("Option E", comment: ""), image: #imageLiteral(resourceName: "Screenshot"), action: { $0.isSelected.toggle() })
    let optionF = MenuItem(text: NSLocalizedString("Option F", comment: ""), image: #imageLiteral(resourceName: "Screenshot"), action: { $0.isSelected.toggle() })
    let optionG = MenuItem(text: NSLocalizedString("Option G", comment: ""), image: #imageLiteral(resourceName: "Screenshot"), action: { $0.isSelected.toggle() })
    let optionH = MenuItem(text: NSLocalizedString("Option H", comment: ""), image: #imageLiteral(resourceName: "Screenshot"), action: { $0.isSelected.toggle() })
    
    let menuItems = [saveStateItem, loadStateItem, cheatCodesItem, fastForwardItem, sustainButtonsItem, screenshotItem, optionA, optionB, optionC, optionD, optionE, optionF, optionG, optionH]
    
    let hostingController = PauseView.HostingController(items: menuItems)
    hostingController.view.backgroundColor = .systemMint
    hostingController.showItems(animated: false)
    return hostingController
}
