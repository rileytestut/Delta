//
//  ManageDonationView.swift
//  Delta
//
//  Created by Riley Testut on 9/23/26.
//  Copyright © 2026 Riley Testut. All rights reserved.
//

import SwiftUI
import StoreKit

struct ManageDonationView: View
{
    @State
    private var service: PurchaseManager.Service = .iap
    
    @State
    private var activeDonation: PurchaseManager.Donation?
    
    @Environment(\.openURL)
    private var openURL
    
    @State
    private var isManagingIAPSubscription: Bool = false
    
    @State
    private var isShowingErrorAlert: Bool = false
    
    @State
    private var patreonError: Error? = nil
    
    @State
    private var isShowingSigningOutAlert: Bool = false
    
    var body: some View {
        Form {
            Section {
                // Limit to IAP because there is a bug preventing us from fetching donation amount from Patreon API.
                if service == .iap
                {
                    LabeledContent("Amount") {
                        if let donation = activeDonation
                        {
                            Text(donation.amount, format: .currency(code: donation.currency).precision(.fractionLength(0...2))) +
                            Text("/month")
                        }
                        else
                        {
                            ProgressView()
                        }
                    }
                }
                
                LabeledContent("Service") {
                    Text(service.localizedTitle)
                }
                
                switch service
                {
                case .patreon:
                    Button("Unlink Patreon Account", role: .destructive) {
                        isShowingSigningOutAlert = true
                    }
                    
                case .iap:
                    Button("Manage Subscription") {
                        isManagingIAPSubscription = true
                    }
                }
            } footer: {
                if service == .patreon
                {
                    Text("To manage your pledge, please visit [patreon.com](https://www.patreon.com/rileyshane)")
                }
            }
            
            FriendZonePatronsView()
                .listRowBackground(Color.clear) // Disable inset grouped appearance
                .environment(\.managedObjectContext, DatabaseManager.shared.viewContext)
        }
        .alert("Are you sure you want to unlink your Patreon account?", isPresented: $isShowingSigningOutAlert) {
            if #available(iOS 26, *)
            {
                Button(role: .cancel) {}
                Button("Unlink Account", role: .destructive, action: signOut)
            }
            else
            {
                Button("Cancel") {}
                Button("Unlink Account", action: signOut)
            }
        }
        .alert("Unable to Unlink Patreon Account", item: $patreonError, actions: { error in
            Button("OK") {}
        }, message: { error in
            Text(error.localizedDescription)
        })
        .navigationTitle(Text("Donation"))
        .navigationBarTitleDisplayMode(.inline)
        .manageSubscriptionsSheet(isPresented: $isManagingIAPSubscription)
        .onAppear {
            if RevenueCatManager.shared.hasBetaAccess
            {
                service = .iap
            }
            else
            {
                service = .patreon
            }
        }
        .task {
            activeDonation = await PurchaseManager.shared.activeDonation
        }
    }
}

private extension ManageDonationView
{
    func signOut()
    {
        Task<Void, Never> {
            do
            {
                try await withCheckedThrowingContinuation { continuation in
                    PatreonAPI.shared.signOut { (result) in
                        continuation.resume(with: result)
                    }
                }
            }
            catch
            {
                self.isShowingErrorAlert = true
                self.patreonError = error
            }
        }
    }
}

#Preview {
    NavigationStack {
        ManageDonationView()
    }
}
