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

    @SwiftUI.State
    private var localControllerPlayerIndex: Int? = Settings.localControllerPlayerIndex

    var body: some View {
        Form {
            ForEach(0..<4) { playerIndex in
                NavigationLink(destination: ControllersSettingsViewController.ViewRepresentable(playerIndex: playerIndex).ignoresSafeArea()) {
                    LabeledContent("Player \(playerIndex + 1)", value: controllerName(for: playerIndex) ?? "")
                }
            }
        }
        .tint(.accentColor)
        .navigationTitle("Controllers")
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(NotificationCenter.default.publisher(for: Settings.didChangeNotification)) { notification in
            guard let name = notification.userInfo?[Settings.NotificationUserInfoKey.name] as? Settings.Name,
                  name == .localControllerPlayerIndex else { return }
            localControllerPlayerIndex = Settings.localControllerPlayerIndex
        }
    }

    private func controllerName(for playerIndex: Int) -> String?
    {
        if localControllerPlayerIndex == playerIndex
        {
            return LocalDeviceController().name
        }
        else if let controller = gameControllerManager.connectedControllers.first(where: { $0.playerIndex == playerIndex })
        {
            return controller.name
        }
        
        return nil
    }
}
