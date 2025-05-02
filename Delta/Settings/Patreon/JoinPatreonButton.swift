//
//  JoinPatreonButton.swift
//  Delta
//
//  Created by Riley Testut on 5/1/25.
//  Copyright © 2025 Riley Testut. All rights reserved.
//

import SwiftUI

struct JoinPatreonButton: View
{
    @Environment(\.colorScheme)
    var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Join our Patreon")
                .font(.headline)
            
            Text("Unlock exclusive app icons and receive early access to new features by donating.")
                .font(.subheadline)
        }
        .foregroundColor(colorScheme == .dark ? .white : .accentColor)
    }
}
