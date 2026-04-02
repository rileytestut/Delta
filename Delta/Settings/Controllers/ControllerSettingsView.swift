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
    private var gameControllerManager: ExternalGameControllerManager = .shared

    var body: some View {
        Form {
            ForEach(0..<4) { playerIndex in
                NavigationLink(destination: ControllersSettingsViewController.ViewRepresentable(playerIndex: playerIndex)
                    .navigationTitle("Player \(playerIndex + 1)")
                    .navigationBarTitleDisplayMode(.inline)
                    .ignoresSafeArea()) {
                    LabeledContent("Player \(playerIndex + 1)") {
                        Text(controllerName(for: playerIndex))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .tint(.accentColor)
        .navigationTitle("Controllers")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func controllerName(for playerIndex: Int) -> String
    {
        if playerIndex == (Settings.localControllerPlayerIndex ?? -1)
        {
            return LocalDeviceController().name
        }
        else if let controller = gameControllerManager.connectedControllers.first(where: { $0.playerIndex == playerIndex })
        {
            return controller.name
        }
        
        return ""
    }
}
