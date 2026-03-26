//
//  AchievementGreeting.swift
//  Delta
//
//  Created by Natalie Pekker on 3/2/26.
//  Copyright © 2026 Riley Testut. All rights reserved.
//

import SwiftUI

@available(iOS 26, *)
struct AchievementGreeting: View
{
    let account: AchievementsManager.Account
    
    private var greetingContent: some View
    {
        HStack(alignment: .center, spacing: 8) {
            
            AchievementToastIcon(url: account.avatarURL, size: 34, fallbackImageName: "person.fill")
                .clipShape(.circle)
            
            VStack(alignment: .leading, spacing: 0) {
                Text("Welcome back")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text(account.username)
                    .font(.subheadline)
                    .bold()
            }
            
            Spacer(minLength: 20)
            
            Text(account.totalPoints.formatted())
                .font(.caption)
                .padding(.vertical, 2)
                .padding(.horizontal, 5)
                .background(Color(uiColor: .deltaLightPurple).opacity(0.3), in: .capsule)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
    }
    
    var body: some View {
        AchievementToast(glassShape: .capsule) {
            greetingContent
        }
    }
}
