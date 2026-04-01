//
//  SettingsRow.swift
//  Delta
//
//  Created by Caroline Moore on 3/31/26.
//  Copyright © 2026 Riley Testut. All rights reserved.
//

import SwiftUI

struct SettingsRow<Content: View>: View
{
    private let label: Text
    private let systemImage: String
    private let color: Color
    private let content: Content

    init(label: Text, systemImage: String, color: Color, @ViewBuilder content: () -> Content)
    {
        self.label = label
        self.systemImage = systemImage
        self.color = color
        self.content = content()
    }

    var body: some View {
        LabeledContent {
            content
        } label: {
            Label {
                label
            } icon: {
                if #available(iOS 26, *)
                {
                    Image(systemName: systemImage)
                        .imageScale(.medium)
                        .foregroundStyle(.white)
                        .frame(width: 29, height: 29)
                        .glassEffect(.regular.tint(color), in: RoundedRectangle(cornerRadius: 7))
                }
                else
                {
                    Image(systemName: systemImage)
                        .imageScale(.medium)
                        .foregroundStyle(.white)
                        .frame(width: 29, height: 29)
                        .background(color, in: RoundedRectangle(cornerRadius: 7))
                }
            }
        }
    }
}

extension SettingsRow where Content == EmptyView
{
    init(label: Text, systemImage: String, color: Color)
    {
        self.init(label: label, systemImage: systemImage, color: color) { EmptyView() }
    }
}
