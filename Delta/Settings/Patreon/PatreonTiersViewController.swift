//
//  PatreonTiersViewController.swift
//  Delta
//
//  Created by Riley Testut on 12/11/24.
//  Copyright © 2024 Riley Testut. All rights reserved.
//

import SwiftUI

@available(iOS 17.5, *)
private extension RevenueCatManager.Subscription
{
    var price: Decimal {
        switch self
        {
        case .earlyAdopter: return 10
        case .communityMember: return 15
        case .friendZone: return 30
        }
    }
    
    var features: [String] {
        switch self
        {
        case .earlyAdopter:
            return [
                String(localized: "Early access to new features"),
                String(localized: "Exclusive icons designed by community members")
            ]
            
        case .communityMember:
            return [
                String(localized: "Invitation to patron-exclusive Discord"),
                String(localized: "All benefits from Early Adopter tier")
            ]
            
        case .friendZone:
            return [
                String(localized: "Name listed in Delta in “Special Thanks” section"),
                String(localized: "All benefits from Early Adopter and Community Member tiers")
            ]
        }
    }
}

@available(iOS 17.5, *)
class PatreonTiersViewController: UIHostingController<PatreonTiersView>
{
    var completionHandler: ((Result<RevenueCatManager.Subscription, CancellationError>) -> Void)?
    
    init(completionHandler: ((Result<RevenueCatManager.Subscription, CancellationError>) -> Void)?)
    {
        self.completionHandler = completionHandler
        
        super.init(rootView: PatreonTiersView(completionHandler: completionHandler))
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        guard let sheetController = self.navigationController?.sheetPresentationController else { return }
        sheetController.detents = [.medium(), .large()]
        sheetController.selectedDetentIdentifier = .medium
        sheetController.prefersGrabberVisible = true
        
        let cancelButton = UIBarButtonItem(systemItem: .cancel)
        cancelButton.target = self
        cancelButton.action = #selector(PatreonTiersViewController.cancel)
        self.navigationItem.leftBarButtonItem = cancelButton
    }
    
    @MainActor @preconcurrency required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func cancel()
    {
        self.completionHandler?(.failure(CancellationError()))
    }
}

@available(iOS 17.5, *)
struct PatreonTiersView: View
{
    let completionHandler: ((Result<RevenueCatManager.Subscription, CancellationError>) -> Void)?
    
    @State
    private var subscriptionError: Error?
    
    @State
    private var isShowingError: Bool = false
    
    var body: some View {
        List {
            Section {
                subscriptionRow(for: .earlyAdopter)
            } header: {
                VStack {
                    Text("All subscriptions are billed monthly.\n")
                        .textCase(nil)
                }
                .frame(minWidth: nil, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                .listRowInsets(EdgeInsets()) // Minimize header size
            }
            
            Section {
                subscriptionRow(for: .communityMember)
            }
            
            Section {
                subscriptionRow(for: .friendZone)
            }
        }
        .environment(\.defaultMinListHeaderHeight, 0) // Minimize header size
        .navigationTitle("Choose Patron Tier")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Unable to Purchase Subscription", isPresented: $isShowingError, presenting: subscriptionError) { _ in
            Button("OK", role: .cancel) {}
        } message: { error in
            Text(error.localizedDescription)
        }
    }
    
    private func subscriptionRow(for subscription: RevenueCatManager.Subscription) -> some View
    {
        Button(action: { purchase(subscription) }) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(subscription.title)
                        
                    Spacer()
                    
                    Text("$\(subscription.price)/month")
                        
                }
                .bold()
                
                VStack(alignment: .leading) {
                    ForEach(subscription.features, id: \.self) { feature in
                        Text("• \(feature)")
                            .foregroundStyle(Color(uiColor: .label))
                    }
                }
                .font(.footnote)
                .foregroundStyle(.primary)
            }
        }
    }
    
    private func purchase(_ subscription: RevenueCatManager.Subscription)
    {
        Task<Void, Never> {
            do
            {
                try await RevenueCatManager.shared.purchase(subscription)
                self.completionHandler?(.success(subscription))
            }
            catch is CancellationError
            {
                // Ignore
            }
            catch
            {
                self.subscriptionError = error
                self.isShowingError = true
            }
        }
    }
}

@available(iOS 17.5, *)
#Preview(traits: .portrait) {
    Text("Hello World")
        .sheet(isPresented: .constant(true)) {
            NavigationStack {
                PatreonTiersView(completionHandler: nil)
            }
            .presentationDetents([.medium])
        }
}
