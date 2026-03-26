//
//  AchievementNotification.swift
//  Delta
//
//  Created by Natalie Pekker on 3/4/26.
//  Copyright © 2026 Riley Testut. All rights reserved.
//

import SwiftUI

@available(iOS 26, *)
struct AchievementNotification: View
{
    let achievement: Achievement

    @State
    private var isExpanded = false
    
    @Environment(AchievementToastView.self)
    private var hostingView

    var body: some View {
        AchievementToast(glassShape: .rect(cornerRadius: 26)) {
            Button {
                withAnimation(.spring(duration: 0.3)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(alignment: .center, spacing: 10) {
                    AchievementToastIcon(url: achievement.imageURL, size: isExpanded ? 54 : 34, fallbackImageName: "medal.fill")
                        .clipShape(.rect(cornerRadius: 6))

                    VStack(alignment: .leading, spacing: isExpanded ? 4 : 0) {
                        if !isExpanded {
                            Text("New Achievement")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        HStack {
                            Text(achievement.title)
                                .font(.subheadline)
                                .bold()

                            if isExpanded {
                                Spacer()
                                Text("\(achievement.points) \(achievement.points == 1 ? "pt" : "pts")")
                                    .font(.caption)
                                    .padding(.vertical, 2)
                                    .padding(.horizontal, 5)
                                    .background(Color(uiColor: .deltaLightPurple).opacity(0.3), in: Capsule())
                            }
                        }

                        if isExpanded, let description = achievement.description {
                            Text(description)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if !isExpanded {
                        Spacer()
                            .frame(width: 20)

                        Text("\(achievement.points)")
                            .font(.caption)
                            .padding(.vertical, 2)
                            .padding(.horizontal, 5)
                            .background(Color(uiColor: .deltaLightPurple).opacity(0.3), in: Capsule())
                    }
                }
                .padding(.vertical, isExpanded ? 16 : 10)
                .padding(.horizontal, isExpanded ? 18 : 14)
                .frame(maxWidth: isExpanded ? AchievementToastView.preferredExpandedWidth : nil)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .fixedSize(horizontal: false, vertical: true) // Always display at our preferred height
        }
        .onChange(of: isExpanded) { _, _ in
            // Cancel existing hide timer
            hostingView._timer?.invalidate()
            
            // Create new hide timer
            let duration = isExpanded ? 8.0 : 4.0
            hostingView._timer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak hostingView] _ in
                hostingView?.hide()
            }
        }
    }
}
