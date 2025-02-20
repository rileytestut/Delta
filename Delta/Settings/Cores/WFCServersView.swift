//
//  WFCServersView.swift
//  Delta
//
//  Created by Riley Testut on 1/16/25.
//  Copyright © 2025 Riley Testut. All rights reserved.
//

import SwiftUI

@available(iOS 15, *)
extension WFCServersView
{
    fileprivate class ViewModel: ObservableObject
    {
        @Published
        var customDNS: String
        
        @Published
        var preferredDNS: String?
        
        init()
        {
            self.customDNS = Settings.customWFCServer ?? ""
            self.preferredDNS = Settings.preferredWFCServer
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
                    Text("• Devices on the same Wi-Fi network may not be able to connect to each other\n")
                    Text("For more help, check out our [Troubleshooting Guide](https://faq.deltaemulator.com/using-delta/online-multiplayer)")
                }
            }
            
            Section("Popular") {
                ForEach(WFCServer.knownServers) { server in
                    Button {
                        viewModel.preferredDNS = server.dns
                    } label: {
                        knownServerRow(for: server)
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
            Settings.preferredWFCServer = newValue
        }
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
                
                Button {
                    UIApplication.shared.open(server.url, completionHandler: nil)
                } label: {
                    Image(systemName: "info.circle")
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
