//
//  CheatsButton.swift
//  Delta
//
//  Created by Caroline Moore on 3/23/26.
//  Copyright © 2026 Riley Testut. All rights reserved.
//

import SwiftUI

import DeltaCore

@available(iOS 26, *)
struct CheatsButton: View
{
    @ObservedObject
    var cheat: Cheat

    var onEdit: (() -> Void)? = nil
    
    @Environment(\.horizontalSizeClass)
    private var horizontalSizeClass
    
    var onToggle: (() -> Void)? = nil

    var body: some View {
        Button {
            onToggle?()
        } label: {
            HStack(spacing: 6) {
                let isCompact = horizontalSizeClass == .compact
                
                Image(systemName: cheat.symbolName ?? "bolt.fill")
                    .foregroundStyle(cheat.isEnabled ? Color(uiColor: .deltaPurple) : Color.white)
                    .frame(width: isCompact ? 40 : 44, height: isCompact ? 40 : 44)
                    .font(.system(size: isCompact ? 20 : 24)) // Explicit size since we don't want to scale with Dynamic Type
                    .accessibilityHidden(true)

                VStack(alignment: .leading) {
                    Text(cheat.name)
                        .font(isCompact ? .callout : .body)
                        .bold()
                        .minimumScaleFactor(0.8)

                    Text(cheat.type.rawValue) // TODO: replace with localized property @Riley
                        .font(isCompact ? .caption : .footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                if !isCompact, let onEdit
                {
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.body)
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.clear.interactive(), in: .circle)
                    .accessibilityLabel("Edit")
                }
            }
            .padding(14)
            .contentShape(.rect) // Makes entire button tappable
        }
        .buttonStyle(.plain)
        .foregroundStyle(cheat.isEnabled ? Color.black : .white)
        .accessibilityValue(cheat.isEnabled ? "On" : "Off")
        .accessibilityLabel(cheat.name)

        // Glass effect
        .glassEffect(cheat.isEnabled ? .clear.tint(.white).interactive() : .clear.interactive(), in: .capsule)
        .glassEffectTransition(.materialize)
    }
}
