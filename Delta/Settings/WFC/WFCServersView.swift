//
//  WFCServersView.swift
//  Delta
//
//  Created by Riley Testut on 1/16/25.
//  Copyright © 2025 Riley Testut. All rights reserved.
//

import SwiftUI

import MelonDSDeltaCore

@available(iOS 15, *)
extension WFCServersView
{
    fileprivate class ViewModel: ObservableObject
    {
        @Published
        var customDNS: String
        
        @Published
        var preferredDNS: String?
        
        @Published
        var isAskingForConfirmation: Bool = false
        
        @Published
        var knownServers: [WFCServer]?
        
        @Published
        var isInitialSetup: Bool = false
        
        init()
        {
            self.customDNS = Settings.customWFCServer ?? ""
            self.preferredDNS = Settings.preferredWFCServer
            
            self.setKnownServers(UserDefaults.standard.wfcServers)
            
            self.isInitialSetup = (Settings.preferredWFCServer == nil)
        }
        
        func setKnownServers(_ knownServers: [WFCServer]?)
        {
            if var knownServers
            {
                if
                    FileManager.default.fileExists(atPath: MelonDSEmulatorBridge.shared.bios7URL.path) ||
                        FileManager.default.fileExists(atPath: MelonDSEmulatorBridge.shared.bios9URL.path) ||
                        FileManager.default.fileExists(atPath: MelonDSEmulatorBridge.shared.firmwareURL.path)
                {
                    // User is using BIOS files, so make Wiimmfi the 2nd option.
                    if let wiimmfi = knownServers.first(where: { $0.dns == "167.235.229.36" }), knownServers.count > 1
                    {
                        knownServers.removeFirst()
                        knownServers.insert(wiimmfi, at: 1)
                    }
                }
                
                self.knownServers = knownServers
            }
            else
            {
                self.knownServers = nil
            }
        }
    }
}

@available(iOS 15, *)
struct WFCServersView: View
{
    @StateObject
    private var viewModel = ViewModel()
    
    private var localizedTitle: String { String(localized: "Choose WFC Server", comment: "") }
    
    var body: some View {
        List {
            Section {
            } header: {
                Text("Troubleshooting Tips")
            } footer: {
                VStack(alignment: .leading) {
                    Text("• You can only connect to players on the same server")
                    Text("• Devices on the same Wi-Fi network may not be able to connect to each other")
                    Text("• When using BIOS files, you may need to “Erase Nintendo WFC Configuration” in-game\n")
                    Text("For more help, check out our [Troubleshooting Guide](https://faq.deltaemulator.com/using-delta/online-multiplayer)")
                }
            }
            
            if let knownServers = viewModel.knownServers
            {
                Section("Popular") {
                    ForEach(knownServers) { server in
                        Button {
                            viewModel.preferredDNS = server.dns
                        } label: {
                            knownServerRow(for: server)
                        }
                    }
                }
            }
            
            Section("Custom") {
                customServerRow()
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(localizedTitle)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: viewModel.customDNS) { newValue in
            Settings.customWFCServer = newValue
            
            // Automatically update preferredDNS to customDNS whenever it's changed.
            viewModel.preferredDNS = newValue
        }
        .onChange(of: viewModel.preferredDNS) { newValue in
            guard newValue != Settings.preferredWFCServer else { return }
            
            if !viewModel.isInitialSetup && UserDefaults.standard.object(forKey: MelonDS.wfcIDUserDefaultsKey) != nil
            {
                // User has previously chosen server and successfully connected at least once, so ask for confirmation before changing.
                viewModel.isAskingForConfirmation = true
            }
            else
            {
                Settings.preferredWFCServer = newValue
            }
        }
        .task(priority: .medium) {
            if let knownServers = try? await WFCManager.shared.updateKnownWFCServers().value
            {
                viewModel.setKnownServers(knownServers)
            }
        }
        .alert("Are you sure you want to change WFC servers?",
               isPresented: $viewModel.isAskingForConfirmation,
               presenting: viewModel.preferredDNS,
               actions: { preferredDNS in
            
            Button("Change Server", role: .destructive) {
                // Reset configuration, then assign Settings.preferredWFCServer to new server
                WFCManager.shared.resetWFCConfiguration()
                Settings.preferredWFCServer = preferredDNS
                viewModel.isInitialSetup = true // Prevent confirmation alert from appearing again.
            }
            
            Button("Cancel", role: .cancel) {
                // Revert viewModel to previous server
                viewModel.preferredDNS = Settings.preferredWFCServer
            }
        }, message: { _ in Text("You may need to re-add any friend codes you’ve previously registered.") })
    }
    
    @ViewBuilder
    func knownServerRow(for server: WFCServer) -> some View
    {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(server.name)
                    .foregroundColor(.primary)
                
                HStack {
                    Text(server.dns)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            HStack {
                if server.dns == viewModel.preferredDNS
                {
                    Image(systemName: "checkmark")
                        .foregroundColor(.accentColor)
                }
                
                if let url = server.url
                {
                    Button {
                        UIApplication.shared.open(url, completionHandler: nil)
                    } label: {
                        Image(systemName: "info.circle")
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    func customServerRow() -> some View
    {
        HStack {
            TextField(text: $viewModel.customDNS, prompt: Text("0.0.0.0")) {
                Text("Custom DNS")
            }
            .onSubmit {
                // Manually update preferredDNS to save it.
                viewModel.preferredDNS = viewModel.customDNS
            }
            .keyboardType(.decimalPad)
            .submitLabel(.done)
            
            Spacer()
            
            if viewModel.customDNS == viewModel.preferredDNS
            {
                Image(systemName: "checkmark")
                    .foregroundColor(.accentColor)
            }
        }
    }
}

@available(iOS 15, *)
extension WFCServersView
{
    static func makeViewController() -> UIHostingController<some View>
    {
        let wfcServersView = WFCServersView()
        
        let hostingController = UIHostingController(rootView: wfcServersView)
        hostingController.navigationItem.largeTitleDisplayMode = .never
        hostingController.navigationItem.title = wfcServersView.localizedTitle
        return hostingController
    }
}

@available(iOS 15, *)
#Preview {
    NavigationView {
        WFCServersView()
    }
}
