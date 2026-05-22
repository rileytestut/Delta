//
//  ControllerSettingsView.swift
//  Delta
//
//  Created by Caroline Moore on 3/30/26.
//  Copyright © 2026 Riley Testut. All rights reserved.
//

import SwiftUI
import DeltaCore

struct ControllerSettingsView: View
{
    @SwiftUI.State
    private var playerControllerNames: [String?] = Self.currentPlayerControllerNames()

    var body: some View {
        Form {
            ForEach(0..<4) { playerIndex in
                NavigationLink(destination: ControllersSettingsViewController.ViewRepresentable(playerIndex: playerIndex).ignoresSafeArea()) {
                    LabeledContent("Player \(playerIndex + 1)", value: playerControllerNames[playerIndex] ?? "")
                }
            }
        }
        .tint(.accentColor)
        .navigationTitle("Controllers")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            playerControllerNames = Self.currentPlayerControllerNames()
        }
    }

    private static func currentPlayerControllerNames() -> [String?]
    {
        (0..<4).map { playerIndex in
            if Settings.localControllerPlayerIndex == playerIndex
            {
                return LocalDeviceController().name
            }
            else if let controller = ExternalGameControllerManager.shared.connectedControllers.first(where: { $0.playerIndex == playerIndex })
            {
                return controller.name
            }

            return nil
        }
    }
}
