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

private struct SettingsBadge: View
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
                PatreonSection()
                ControlsSection()
                EmulationSection()
                OnlineMultiplayerSection()
                DisplaySection()
                ServicesSection()
                MiscellaneousSection()
                CreditsSection()
                SupportSection()
            }
            .safeAreaPadding(.top, 8)
            .navigationTitle("Settings")
            .toolbar {
                if #available(iOS 26, *)
                {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(role: .close) {
                            // dismiss() skips presentationControllerDidDismiss, so explicitly sync on close.
                            SyncManager.shared.sync()
                            dismiss()
                        }
                    }
                }
                else
                {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            // dismiss() skips presentationControllerDidDismiss, so explicitly sync on close.
                            SyncManager.shared.sync()
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

// MARK: - Online Multiplayer

private struct OnlineMultiplayerSection: View
{
    var body: some View {
        Section {
            NavigationLink {
                OnlineMultiplayerView()
            } label: {
                SettingsRow(label: Text("Online Multiplayer"), systemImage: "globe", color: .orange)
            }
        }
    }
}

// MARK: - Online Multiplayer Detail

struct OnlineMultiplayerView: View
{
    @SwiftUI.State
    private var preferredWFCServer: String? = Settings.preferredWFCServer

    @SwiftUI.State
    private var isConfirmingReset: Bool = false

    var body: some View {
        Form {
            Section {
                NavigationLink {
                    WFCServersView()
                } label: {
                    LabeledContent {
                        if let serverName = preferredServerName
                        {
                            Text(serverName)
                        }
                    } label: {
                        Text("WFC Server")
                    }
                }

                if preferredWFCServer != nil
                {
                    Button("Reset Online Settings", role: .destructive) {
                        isConfirmingReset = true
                    }
                    .confirmationDialog("Are you sure you want to reset your online settings?", isPresented: $isConfirmingReset, titleVisibility: .visible) {
                        Button("Reset Online Settings", role: .destructive) {
                            WFCManager.shared.resetWFCConfiguration()
                        }
                    } message: {
                        Text("You may need to re-add any friend codes you’ve previously registered.")
                    }
                }
            } header: {
                Text("Nintendo DS")
            } footer: {
                if preferredWFCServer == nil
                {
                    Text("Choose the 3rd-party Nintendo WFC server Delta should use for online play in Nintendo DS games.")
                }
            }
        }
        .navigationTitle("Online Multiplayer")
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(NotificationCenter.default.publisher(for: Settings.didChangeNotification)) { notification in
            guard let name = notification.userInfo?[Settings.NotificationUserInfoKey.name] as? Settings.Name,
                  name == .preferredWFCServer else { return }

            preferredWFCServer = Settings.preferredWFCServer
        }
        .onAppear {
            preferredWFCServer = Settings.preferredWFCServer
        }
    }

    private var preferredServerName: String? {
        guard let preferredWFCServer else { return nil }

        if let servers = UserDefaults.standard.wfcServers, let knownServer = servers.first(where: { $0.dns == preferredWFCServer })
        {
            return knownServer.name
        }

        return preferredWFCServer
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

    @SwiftUI.State
    private var retroAchievementsUsername: String? = Keychain.shared.retroAchievementsUsername

    var body: some View {
        Section {
            NavigationLink {
                SyncingServicesViewController.ViewRepresentable()
                    .ignoresSafeArea()
            } label: {
                SettingsRow(label: Text("Delta Sync"), systemImage: "arrow.triangle.2.circlepath", color: .indigo) {
                    if let name = syncingServiceName {
                        Text(name).foregroundStyle(.secondary)
                    }
                }
            }

            if isAccountConnected
            {
                NavigationLink {
                    SyncStatusViewController.ViewRepresentable()
                        .ignoresSafeArea()
                } label: {
                    SettingsRow(label: Text("Sync Status"), systemImage: "checkmark.icloud", color: .indigo) {
                        if syncConflictsCount > 0
                        {
                            SettingsBadge(text: "\(syncConflictsCount) conflicts", color: .red)
                        }
                        else
                        {
                            SettingsBadge(text: "Up-to-date", color: .green)
                        }
                    }
                }
            }

            NavigationLink {
                AchievementAccount()
            } label: {
                SettingsRow(label: Text("RetroAchievements"), systemImage: "medal", color: .indigo) {
                    if let username = retroAchievementsUsername {
                        Text(username).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Settings.didChangeNotification)) { notification in
            guard let name = notification.userInfo?[Settings.NotificationUserInfoKey.name] as? Settings.Name,
                  name == .syncingService else { return }
            
            syncingServiceName = Settings.syncingService?.localizedName
            isAccountConnected = SyncManager.shared.coordinator?.account != nil
            refreshSyncConflicts()
        }
        .onReceive(NotificationCenter.default.publisher(for: SyncCoordinator.didFinishSyncingNotification).receive(on: DispatchQueue.main)) { _ in
            refreshSyncConflicts()
        }
        .onReceive(NotificationCenter.default.publisher(for: AchievementsManager.didFinishAuthenticatingNotification).receive(on: DispatchQueue.main)) { _ in
            retroAchievementsUsername = Keychain.shared.retroAchievementsUsername
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
            Logger.main.error("Failed to refresh sync conflicts. \(error.localizedDescription, privacy: .public)")
        }
    }
}

// MARK: - Patreon

private struct PatreonSection: View
{
    var body: some View {
        if PurchaseManager.shared.supportsExternalPurchases
        {
            Section {
                NavigationLink {
                    PatreonViewController.ViewRepresentable()
                        .ignoresSafeArea()
                } label: {
                    SettingsRow(
                        label: Text(PurchaseManager.shared.isActivePatron
                            ? "Manage Subscription" : "Become a Patron"),
                        systemImage: "heart",
                        color: .accentColor
                    )
                }
            } footer: {
                Text("Get early access to new features and unlock exclusive app icons.")
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
                    .navigationBarTitleDisplayMode(.large)
                    .ignoresSafeArea()
            } label: {
                SettingsRow(label: Text("App Icon"), systemImage: "square.grid.2x2", color: .blue)
            }
        }
    }
}

// MARK: - Experimental, Minor, & Advanced

private struct MiscellaneousSection: View
{
    var body: some View {
        Section {
            NavigationLink {
                MinorSettingsView()
            } label: {
                SettingsRow(label: Text("Lil’ Settings"), systemImage: "slider.horizontal.3", color: .gray)
            }

            NavigationLink {
                AdvancedSettingsView()
            } label: {
                SettingsRow(label: Text("Advanced"), systemImage: "gearshape", color: .gray)
            }
            
            NavigationLink {
                ExperimentalFeaturesView()
            } label: {
                SettingsRow(label: Text("Experimental"), systemImage: "flask", color: .gray) {
                    SettingsBadge(text: "Patrons")
                }
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
                    .ignoresSafeArea()
            } label: {
                Text("Software Licenses")
            }
        }
    }
}

// MARK: - Support

private struct SupportSection: View
{
    @Environment(\.openURL)
    var openURL
    
    @SwiftUI.State
    private var showMailError = false

    var body: some View {
        Section {
            Button("Contact Us") {
                // TODO: support attachments
                let email = "support@altstore.io"
                let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
                let subject = "Delta \(version) Feedback"
                let urlString = "mailto:\(email)?subject=\(subject)"
                
                if let url = URL(string: urlString)
                {
                    openURL(url) { success in
                        if !success { showMailError = true }
                    }
                }
            }
            .alert("Cannot Send Mail", isPresented: $showMailError) {}
            
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

private struct RepresentedFooterView: UIViewRepresentable
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
        guard let width = proposal.width ?? uiView.window?.bounds.width else { return nil }

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
