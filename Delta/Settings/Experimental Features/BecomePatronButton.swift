//
//  BecomePatronButton.swift
//  Delta
//
//  Created by Riley Testut on 3/24/25.
//  Copyright © 2025 Riley Testut. All rights reserved.
//

import SwiftUI

extension BecomePatronButton
{
    static let didPressNotification = Notification.Name("DLTADidPressBecomePatronButtonNotification")
}

struct BecomePatronButton: View
{
    var body: some View {
        Button(action: showPatreonSettings) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(Color.accentColor)
                    .frame(minWidth: 0, maxWidth: .infinity)
                
                Text("You must be an active patron to use Experimental Features.")
                    .foregroundColor(.white)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .textCase(nil)
                    .padding(.vertical, 12)
                    .padding(.leading, 16)
                    .padding(.trailing, 16)
            }
            .frame(minWidth: 0, maxWidth: .infinity)
            .padding(.horizontal, -16) // Expand beyond header bounds
            .multilineTextAlignment(.leading)
        }
    }
}

private extension BecomePatronButton
{
    func showPatreonSettings()
    {
        NotificationCenter.default.post(name: Self.didPressNotification, object: nil)
    }
}
