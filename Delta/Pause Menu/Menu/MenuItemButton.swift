//
//  MenuItemButton.swift
//  Delta
//
//  Created by Riley Testut on 3/17/26.
//  Copyright © 2026 Riley Testut. All rights reserved.
//

import SwiftUI

@available(iOS 26, *)
extension MenuItemButton
{
    static let preferredSize: CGSize = CGSize(width: 145, height: 115)
    static let preferredCornerRadius: Double = 32.0
}

@available(iOS 26, *)
struct MenuItemButton: View
{
    @State
    var item: MenuItem
    
    @State
    var isHidden: Bool = false
    
    var body: some View {
        // This probably should be a .contextMenu() View modifier instead of Menu...
        // but the animation when presenting the context menu is kinda jank on iOS 26 :(
        Menu {
            ForEach(item.menuOptions, id: \.title) { action in
                button(for: action)
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
            item.isSelected.toggle() // Match previous behavior which set isSelected before calling action
            item.action(item)
        }
        .buttonStyle(.plain) // Glass buttons don't work with clear appearance :(
        .frame(width: MenuItemButton.preferredSize.width, height: MenuItemButton.preferredSize.height)
        .buttonBorderShape(.roundedRectangle(radius: MenuItemButton.preferredCornerRadius))
        
        // Glass effect
        .glassEffect(isHidden ? .identity : .clear.interactive(), in: .rect(cornerRadius: MenuItemButton.preferredCornerRadius))
        .glassEffectTransition(.materialize)
        
        // Apply white highlight if selected
        .background(!isHidden && item.isSelected ? Color.white.opacity(0.7) : .clear, in: .rect(cornerRadius: MenuItemButton.preferredCornerRadius))
        .foregroundStyle(item.isSelected ? .black : .white)
    }
    
    @ViewBuilder
    private func button(for action: Action) -> some View
    {
        let role: ButtonRole? = switch action.style {
        case .default: nil
        case .cancel: ButtonRole.cancel
        case .destructive: ButtonRole.destructive
        case .selected: nil
        }
        
        let isSelected = (action.style == .selected)
        
        Button(role: role) {
            action.action?(action)
        } label: {
            Toggle(isOn: .constant(isSelected)) { // Show checkmark if isSelected
                Label {
                    Text(action.title)
                } icon: {
                    action.image.map { Image(uiImage: $0) }
                }
            }
        }
    }
}

@available(iOS 26, *)
#Preview {
    let item = MenuItem(text: NSLocalizedString("Fast Forward", comment: ""), image: #imageLiteral(resourceName: "FastForward"), action: { $0.isSelected.toggle() })
    MenuItemButton(item: item)
        .background(Color.red)
}
