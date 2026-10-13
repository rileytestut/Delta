//
//  GlassBadge.swift
//  Delta
//
//  Created by Caroline Moore on 10/1/26.
//  Copyright © 2026 Riley Testut. All rights reserved.
//

import SwiftUI

struct GlassBadge: View
{
    let content: Text
    let color: Color
    
    var body: some View {
        let content = content
            .font(.footnote.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        
        let background = ZStack {
            color
            Color.white.opacity(0.3)
        }
        
        if #available(iOS 26, *)
        {
            content
                .glassEffect(.regular)
                .background {
                    background
                }
                .clipShape(.capsule)
                .colorScheme(.dark)
        }
        else
        {
            content
                .background {
                    background
                }
                .clipShape(.capsule)
        }
    }
}
