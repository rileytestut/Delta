//
//  SettingsView.swift
//  Delta
//
//  Created by Caroline Moore on 3/31/26.
//  Copyright © 2026 Riley Testut. All rights reserved.
//

import SwiftUI

import DeltaCore
import Harmony

struct SettingsBadge: View
{
    let text: String
    var color: Color = .accentColor

    var body: some View {
        Text(text)
            .font(.caption.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color, in: Capsule())
            .foregroundStyle(.white)
    }
}

struct SettingsView: View
{
    @Environment(\.dismiss)
    private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                ControlsSection()
                EmulationSection()
                ServicesSection()
                PatreonSection()
                DisplaySection()
                BehaviorSection()
                CreditsSection()
                SupportSection()
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if #available(iOS 26, *)
                    {
                        Button(role: .close) {
                            NotificationCenter.default.post(name: Settings.didCloseNotification, object: nil)
                            dismiss()
                        }
                    }
                    else
                    {
                        Button("Done") {
                            NotificationCenter.default.post(name: Settings.didCloseNotification, object: nil)
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Controls

private struct ControlsSection: View
{
    @SwiftUI.State
    private var gameControllerManager: ExternalGameControllerManager = .shared

    var body: some View {
        Section("Controls") {
            NavigationLink {
                ControllerSettingsView()
            } label: {
                SettingsRow(label: Text("Controllers"), systemImage: "gamecontroller", color: .purple) {
                    if !gameControllerManager.connectedControllers.isEmpty
                    {
                        Text("\(gameControllerManager.connectedControllers.count) Connected")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            NavigationLink {
                SkinSettingsView()
            } label: {
                SettingsRow(label: Text("Skins"), systemImage: "paintpalette", color: .pink)
            }

            NavigationLink {
                TouchHapticsView()
            } label: {
                SettingsRow(label: Text("Touch & Haptics"), systemImage: "hand.tap", color: .red)
            }
        }
    }
}

// MARK: - Emulation

private struct EmulationSection: View
{
    var body: some View {
        Section("Emulation") {
            NavigationLink {
                AudioSettingsView()
            } label: {
                SettingsRow(label: Text("Audio"), systemImage: "speaker.wave.2", color: .green)
            }

            NavigationLink {
                VideoSettingsView()
            } label: {
                SettingsRow(label: Text("Video"), systemImage: "display", color: .teal)
            }

            NavigationLink {
                CoresListView()
            } label: {
                SettingsRow(label: Text("Cores"), systemImage: "cpu", color: .cyan)
            }
        }
    }
}

// MARK: - Services

private struct ServicesSection: View
{
    @SwiftUI.State
    private var syncingServiceName: String? = Settings.syncingService?.localizedName
    
    @SwiftUI.State
    private var syncConflictsCount: Int = 0
    
    @SwiftUI.State
    private var isAccountConnected: Bool = SyncManager.shared.coordinator?.account != nil

    var body: some View {
        Section {
            NavigationLink {
                SyncingServicesViewController.ViewRepresentable()
            } label: {
                SettingsRow(label: Text("Delta Sync"), systemImage: "arrow.triangle.2.circlepath", color: .blue) {
                    if let name = syncingServiceName {
                        Text(name).foregroundStyle(.secondary)
                    }
                }
            }
            
            NavigationLink {
                EmptyView() // TODO: UIKit bridge
            } label: {
                SettingsRow(label: Text("RetroAchievements"), systemImage: "medal", color: .blue) {
                    // TODO: Show username if logged in
                }
            }

            // TODO: decide whether to add back for beta
//            if isAccountConnected
//            {
//                NavigationLink {
//                    EmptyView() // TODO: UIKit bridge
//                } label: {
//                    SettingsRow(label: "Sync Status", systemImage: "checkmark.icloud", color: .blue) {
//                        SettingsBadge(text: "\(syncConflictsCount) conflicts",
//                                      color: syncConflictsCount > 0 ? .red : .green)
//                    }
//                }
//            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Settings.didChangeNotification)) { notification in
            guard let name = notification.userInfo?[Settings.NotificationUserInfoKey.name] as? Settings.Name else { return }

            if name == .syncingService
            {
                syncingServiceName = Settings.syncingService?.localizedName
                isAccountConnected = SyncManager.shared.coordinator?.account != nil
                refreshSyncConflicts()
            }
        }
        .onAppear {
            refreshSyncConflicts()
        }
    }

    private func refreshSyncConflicts()
    {
        do {
            let records = try SyncManager.shared.recordController?.fetchConflictedRecords() ?? []
            syncConflictsCount = records.count
        } catch {
            print(error)
        }
    }
}

// MARK: - Patreon

private struct PatreonSection: View
{
    var body: some View {
        if PurchaseManager.shared.supportsExperimentalFeatures
        {
            Section {
                NavigationLink {
                    PatreonViewController.ViewRepresentable()
                } label: {
                    SettingsRow(
                        label: Text(PurchaseManager.shared.isActivePatron
                            ? "Manage Subscription" : "Join Our Patreon"),
                        systemImage: "heart",
                        color: .accentColor
                    )
                }
            }
        }
    }
}

// MARK: - App Icon

private struct DisplaySection: View
{
    var body: some View {
        Section("Display") {
            NavigationLink {
                AltAppIconsViewController.ViewRepresentable()
            } label: {
                SettingsRow(label: Text("App Icon"), systemImage: "square.grid.2x2", color: .indigo)
            }
        }
    }
}

// MARK: - Experimental, Minor, & Advanced

private struct BehaviorSection: View
{
    var body: some View {
        Section {
            NavigationLink {
                ExperimentalFeaturesView()
            } label: {
                SettingsRow(label: Text("Experimental"), systemImage: "flask", color: .gray) {
                    SettingsBadge(text: "Patrons")
                }
            }

            NavigationLink {
                MinorSettingsView()
            } label: {
                SettingsRow(label: Text("Minor"), systemImage: "slider.horizontal.3", color: .gray)
            }

            NavigationLink {
                AdvancedSettingsView()
            } label: {
                SettingsRow(label: Text("Advanced"), systemImage: "gearshape", color: .gray)
            }
        }
    }
}

// MARK: - Credits

private struct CreditsSection: View
{
    var body: some View {
        Section("Credits") {
            NavigationLink {
                ContributorsView()
            } label: {
                Text("Contributors")
            }

            NavigationLink {
                LicensesViewController.ViewRepresentable()
            } label: {
                Text("Software Licenses")
            }
        }
    }
}

// MARK: - Support

private struct SupportSection: View
{
    var body: some View {
        Section {
            Button("Contact Us") { } // TODO: implement
            
            Link("Privacy Policy", destination: URL(string: "https://altstore.io/privacy")!)
            
            Link("Terms of Use", destination: URL(string: "https://altstore.io/terms")!)
        } header: {
            Text("Support")
        } footer: {
            RepresentedFooterView()
                .containerRelativeFrame(.horizontal)
        }
    }
}

// MARK: - Footer

struct RepresentedFooterView: UIViewRepresentable
{
    func makeUIView(context: Context) -> FollowUsFooterView
    {
        let view = FollowUsFooterView(prefersFullColorIcons: false)
        view.stackView.spacing = 20
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.directionalLayoutMargins.top = 8
        view.stackView.directionalLayoutMargins.bottom = 20
        return view
    }

    func updateUIView(_ uiView: FollowUsFooterView, context: Context) {}

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: FollowUsFooterView, context: Context) -> CGSize?
    {
        let width = proposal.width ?? UIScreen.main.bounds.width

        return uiView.systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
    }
}

#Preview {
    SettingsView()
}
