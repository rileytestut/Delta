//
//  AchievementGameBanner.swift
//  Delta
//
//  Created by Natalie Pekker on 3/4/26.
//  Copyright © 2026 Riley Testut. All rights reserved.
//

import SwiftUI

@available(iOS 26, *)
struct AchievementGameBanner: View
{
    let game: AchievementsManager.Game
    
    private var bannerContent: some View
    {
        HStack(alignment: .center, spacing: 10) {
            
            AchievementToastIcon(url: game.imageURL, size: 54, fallbackImageName: "gamecontroller.fill")
                .clipShape(.rect(cornerRadius: 6))
            
            VStack(alignment: .leading, spacing: 5) {
                Text(game.title)
                    .font(.headline)
                    .lineLimit(2)
                
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "medal.fill")
                        
                        HStack(spacing: 0) {
                            Text(game.unlockedAchievements.formatted())
                            Text("/\(game.totalAchievements.formatted())")
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Text("\(game.currentPoints.formatted()) \(game.currentPoints == 1 ? "pt" : "pts")")
                        .padding(.vertical, 2)
                        .padding(.horizontal, 6)
                        .background(Color(uiColor: .deltaLightPurple).opacity(0.3), in: .capsule)
                }
                .font(.callout)
            }
            Spacer()
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 18)
        .frame(maxWidth: AchievementToastView.preferredExpandedWidth)
    }
    
    var body: some View
    {
        AchievementToast(glassShape: .rect(cornerRadius: 26)) {
            bannerContent
        }
    }
}
