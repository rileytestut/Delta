//
//  ContributionsView.swift
//  Delta
//
//  Created by Riley Testut on 2/2/23.
//  Copyright © 2023 Riley Testut. All rights reserved.
//

import SwiftUI

private extension NavigationLink where Label == EmptyView, Destination == EmptyView
{
    // Copied from https://stackoverflow.com/a/66891173
    static var empty: NavigationLink {
        self.init(destination: EmptyView(), label: { EmptyView() })
    }
}

extension ContributorsView
{
    fileprivate class ViewModel: ObservableObject
    {
        @Published
        var contributors: [Contributor]?
        
        @Published
        var error: Error?
        
        func loadContributors()
        {
            guard self.contributors == nil else { return }
            
            do
            {
                let fileURL = Bundle.main.url(forResource: "Contributors", withExtension: "plist")!
                let data = try Data(contentsOf: fileURL)
                
                let contributors = try PropertyListDecoder().decode([Contributor].self, from: data)
                self.contributors = contributors
            }
            catch
            {
                self.error = error
            }
        }
    }
    
    static func makeViewController() -> UIHostingController<some View>
    {
        let contributorsView = ContributorsView()
        
        let hostingController = UIHostingController(rootView: contributorsView)
        hostingController.navigationItem.largeTitleDisplayMode = .never
        hostingController.navigationItem.title = contributorsView.localizedTitle
        
        return hostingController
    }
}

struct ContributorsView: View
{
    @StateObject
    private var viewModel: ViewModel
    
    @State
    private var showErrorAlert: Bool = false
    
    @Environment(\.openURL)
    private var openURL

    @Environment(\.dismiss)
    private var dismiss

    private var localizedTitle: String { NSLocalizedString("Contributors", comment: "") }
    
    var body: some View {
        List {
            Section(content: {}, footer: {
                Text("These individuals have contributed to the open-source Delta project on GitHub.\n\nThank you to all our contributors, your help is much appreciated 💜")
                    .font(.subheadline)
            })
            
            ForEach(viewModel.contributors ?? []) { contributor in
                Section {
                    // First row = contributor
                    ContributionCell(name: Text(contributor.name).bold(), url: contributor.url, linkName: contributor.linkName) { openURL($0) }

                    // Remaining rows = contributions
                    ForEach(contributor.contributions) { contribution in
                        ContributionCell(name: Text(contribution.name), url: contribution.url) { openURL($0) }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(localizedTitle)
        .navigationBarTitleDisplayMode(.inline)
        .environmentObject(viewModel)
        .alert(isPresented: $showErrorAlert) {
            Alert(title: Text("Unable to Load Contributors"), message: Text(viewModel.error?.localizedDescription ?? ""), dismissButton: .default(Text("OK")) {
                dismiss()
            })
        }
        .onReceive(viewModel.$error) { error in
            guard error != nil else { return }
            showErrorAlert = true
        }
        .onAppear {
            viewModel.loadContributors()
        }
    }
    
    init()
    {
        self._viewModel = StateObject(wrappedValue: ViewModel())
    }

    fileprivate init(contributors: [Contributor]? = nil, viewModel: ViewModel = ViewModel())
    {
        if let contributors
        {
            // Don't overwrite passed-in viewModel.contributors if contributors is nil.
            viewModel.contributors = contributors
        }
        
        self._viewModel = StateObject(wrappedValue: viewModel)
    }
}

struct ContributionCell: View
{
    var name: Text
    var url: URL?
    var linkName: String?
    
    var action: (URL) -> Void
    
    var body: some View {
        
        let body = Button {
            guard let url else { return }
            
            Task { @MainActor in
                // Dispatch Task to avoid "Publishing changes from within view updates is not allowed, this will cause undefined behavior." runtime error on iOS 16.
                self.action(url)
            }
            
        } label: {
            HStack {
                self.name
                    .font(.system(size: 17)) // Match Settings screen
                
                Spacer()
                
                if let linkName
                {
                    Text(linkName)
                        .font(.system(size: 17)) // Match Settings screen
                        .foregroundColor(.gray)
                }
                
                if url != nil
                {
                    NavigationLink.empty
                        .fixedSize()
                }
            }
        }
        .accentColor(.primary)
        
        if url != nil
        {
            body
        }
        else
        {
            // No URL to open, so disable cell highlighting.
            body.buttonStyle(.plain)
        }
    }
}
