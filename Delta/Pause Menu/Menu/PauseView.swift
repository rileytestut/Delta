//
//  PauseView.swift
//  Delta
//
//  Created by Riley Testut on 3/9/26.
//  Copyright © 2026 Riley Testut. All rights reserved.
//

import SwiftUI

@available(iOS 26, *)
@Observable
class PauseViewHostingController: UIHostingController<AnyView>
{
    fileprivate var isHidden: Bool = true
    fileprivate var isAnimated: Bool = true
    
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
        
        super.init(rootView: AnyView(PauseView()))
        
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

@available(iOS 26, *)
struct PauseView: View
{
    var items: [MenuItem] = []
    
    var resumeHandler: () -> Void = {}
    var stopHandler: () -> Void = {}
    
    @Environment(PauseViewHostingController.self)
    var hostingViewController
    
    @SwiftUI.State
    private var isHidden = true
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView(.horizontal) {
                GlassEffectContainer {
                    ContainerRelativeGrid(pageWidth: geometry.size.width, itemWidth: 145) {
                        if !isHidden
                        {
                            ForEach(items, id: \.text) { item in
                                MenuItemButton(item: item, isHidden: isHidden)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
//                                    .glassEffectTransition(.materialize)
//                                    .transition(.identity)
                            }
                        }
                    }
                    .frame(height: geometry.size.height)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
//            .ignoresSafeArea(edges: [.top, .bottom])
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
                
                Button("Resume", systemImage: "play.fill", role: .confirm, action: { DispatchQueue.main.async { resumeHandler() } })
                    .glassEffect()
                    .tint(Color(uiColor: .deltaPurple))
                    .glassEffectTransition(.materialize)
            }
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
struct MenuItemButton: View
{
    @State
    var item: MenuItem
    
    @State
    var isHidden: Bool = false
    
    @Namespace
    private var glassNamespace
    
    var body: some View {
        Menu {
            ForEach(item.menuOptions, id: \.title) { action in
                let role: ButtonRole? = switch action.style {
                case .default: nil
                case .cancel: ButtonRole.cancel
                case .destructive: ButtonRole.destructive
                case .selected: nil
                }
                
                Button(role: role) {
                    action.action?(action)
                } label: {
                    Label {
                        Text(action.title)
                    } icon: {
                        action.image.map { Image(uiImage: $0) }
                    }
                }
            }
        } label: {
            VStack(spacing: 10) {
                if let image = item.image
                {
                    Image(uiImage: image)
                        .frame(width: 44, height: 44)
                }
                
                Text(item.text)
                    .font(.headline)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } primaryAction: {
            item.action(item)
        }
        .buttonStyle(.plain) // Glass buttons don't work with clear appearance :(
        .frame(width: 145, height: 115)
        .buttonBorderShape(.roundedRectangle(radius: 32.0))
        
        .glassEffect(isHidden ? .identity : .clear.interactive(), in: .rect(cornerRadius: 32.0))
        .glassEffectTransition(.materialize)
        //glassEffectID("button", in: glassNamespace)
        
        // Apply white highlight if selected
        .background(!isHidden && item.isSelected ? Color.white.opacity(0.7) : .clear, in: .rect(cornerRadius: 32.0))
        .foregroundStyle(item.isSelected ? .black : .white)
    }
    
    var contextMainBody: some View {
        Button {
            item.action(item)
        } label: {
            VStack(spacing: 10) {
                if let image = item.image
                {
                    Image(uiImage: image)
                        .frame(width: 44, height: 44)
                }
                
                Text(item.text)
                    .font(.headline)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 145, height: 115)
        .buttonStyle(.glass(.clear))
        .buttonBorderShape(.roundedRectangle(radius: 32.0))
        
        // Apply white highlight if selected
        .background(!isHidden && item.isSelected ? Color.white.opacity(0.7) : .clear, in: .rect(cornerRadius: 32.0))
        .foregroundStyle(item.isSelected ? .black : .white)
        
        // Animate in with glass materialize effect
        .glassEffectID("button", in: glassNamespace)
        
        // Configure context menu
        .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 32.0))
        .contextMenu {
            ForEach(item.menuOptions, id: \.title) { action in
                let role: ButtonRole? = switch action.style {
                case .default: nil
                case .cancel: ButtonRole.cancel
                case .destructive: ButtonRole.destructive
                case .selected: nil
                }
                
                Button(role: role) {
                    action.action?(action)
                } label: {
                    Label {
                        Text(action.title)
                    } icon: {
                        action.image.map { Image(uiImage: $0) }
                    }
                }
            }
        }
    }
    
    var legacyBody: some View {
        Button {
            item.action(item)
        } label: {
            VStack(spacing: 10) {
                if let image = item.image
                {
                    Image(uiImage: image)
                        .frame(width: 44, height: 44)
                }
                
                Text(item.text)
                    .font(.headline)
            }
            .foregroundStyle(item.isSelected ? .black : .white)
            .opacity(isHidden ? 0.0 : 1.0)
        }
        .frame(width: 145, height: 115)
        .glassEffect(isHidden ? .identity : .clear.interactive(), in: .rect(cornerRadius: 32.0))
        .glassEffectTransition(.materialize)
        .background(!isHidden && item.isSelected ? Color.white.opacity(0.7) : .clear, in: .rect(cornerRadius: 32.0))
        .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 32.0))
        .contextMenu {
            ForEach(item.menuOptions, id: \.self) { action in
                let role: ButtonRole? = switch action.style {
                case .default: nil
                case .cancel: ButtonRole.cancel
                case .destructive: ButtonRole.destructive
                case .selected: nil
                }
                
                Button(role: role) {
                    action.action?(action)
                } label: {
                    Label {
                        Text(action.title)
                    } icon: {
                        action.image.map { Image(uiImage: $0) }
                    }
                }
            }
            
//            ForEach(items, id: \.self) { action in
//                Text(action.title)
////                let role: ButtonRole = switch action.style {
////                case .default: ButtonRole.normal
////                case .cancel: ButtonRole.cancel
////                case .destructive: ButtonRole.destructive
////                case .selected: ButtonRole.primary
////                }
////
////                Button(action.title, image: Image(uiImage: action.image), role: role) {
////                    action.action(action)
////                }
//            }
            
            Button("Order Now", action: {})
            Button("Adjust Order", action: {})
        }
    }
    
    var menuBody: some View {
        Menu {
            ForEach(item.menuOptions, id: \.self) { action in
                let role: ButtonRole? = switch action.style {
                case .default: nil
                case .cancel: ButtonRole.cancel
                case .destructive: ButtonRole.destructive
                case .selected: nil
                }
                
                Button(role: role) {
                    action.action?(action)
                } label: {
                    Label {
                        Text(action.title)
                    } icon: {
                        action.image.map { Image(uiImage: $0) }
                    }
                }
            }
            
            Button("Order Now", action: {})
            Button("Adjust Order", action: {})
        } label: {
            VStack(spacing: 10) {
                if let image = item.image
                {
                    Image(uiImage: image)
                        .frame(width: 44, height: 44)
                }
                
                Text(item.text)
                    .font(.headline)
            }
            .foregroundStyle(item.isSelected ? .black : .white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } primaryAction: {
            item.action(item)
        }
        .buttonStyle(.glass)
        .glassEffectTransition(.materialize)
        .frame(width: 145, height: 115)
        .buttonBorderShape(.roundedRectangle(radius: 32.0))
    }
    
    var body3: some View {
        Button {
            item.action(item)
        } label: {
            VStack(spacing: 10) {
                if let image = item.image
                {
                    Image(uiImage: image)
                        .frame(width: 44, height: 44)
                }
                
                Text(item.text)
                    .font(.headline)
            }
            .foregroundStyle(item.isSelected ? .black : .white)
            .opacity(isHidden ? 0.0 : 1.0)
        }
        
        .frame(width: 145, height: 115)
        .containerShape(.circle)
        
        .buttonStyle(.glass)
//        .glassEffect(isHidden ? .identity : .clear.interactive(), in: .rect(cornerRadius: 32.0))
        .glassEffectTransition(.materialize)
//        .background(!isHidden && item.isSelected ? Color.white.opacity(0.7) : .clear, in: .rect(cornerRadius: 32.0))
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
    
    let pauseViewController = PauseViewHostingController(items: menuItems, resumeHandler: {}, stopHandler: {})
    pauseViewController.view.backgroundColor = .red
    pauseViewController.showItems(animated: false)
    return pauseViewController
}
