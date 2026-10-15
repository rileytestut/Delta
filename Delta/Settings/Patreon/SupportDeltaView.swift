//
//  SupportDeltaView.swift
//  Delta
//
//  Created by Riley Testut on 9/28/26.
//  Copyright © 2026 Riley Testut. All rights reserved.
//

import SwiftUI

private struct DonationPerk: Decodable, Identifiable
{
    var title: String
    var subtitle: String
    var iconName: String
    
    var id: String { self.title }
}

extension SupportDeltaView
{
    @Observable @MainActor
    fileprivate class ViewModel
    {
        var perks: [DonationPerk] = [
            DonationPerk(title: String(localized: "Experimental Features"), subtitle: String(localized: "Be the first to try new Delta features like Custom Filters and AirPlay Skins."), iconName: "flask"),
            DonationPerk(title: String(localized: "Exclusive app icons"), subtitle: String(localized: "Designed for Patrons by prominent members of the community."), iconName: "app.gift")
        ]
        
        var patreonTier: PatreonAPI.Tier?
        var patreonTierOffering: PurchaseManager.PatreonTierOffering?
        
        var iapSubscription: RevenueCatManager.IAPSubscription?
        
        var donateError: Error?
        var isShowingErrorAlert: Bool = false
        
        func prepare() async
        {
            if PurchaseManager.shared.supportsInAppPurchase
            {
                let subscription = await RevenueCatManager.shared.fetch(.level1)
                self.iapSubscription = subscription
            }
            
            if PurchaseManager.shared.supportsExternalPurchases, let region = PurchaseManager.shared.externalPurchaseRegion
            {
                do
                {
                    async let offering = PurchaseManager.shared.fetchPatreonOffering(tierID: PatreonAPI.Tier.earlyAdopterTierID, region: region)
                    async let tiers = PatreonAPI.shared.fetchTiers()
                    
                    self.patreonTierOffering = try await offering
                    
                    // Await tiers 2nd because it doesn't actually drive UI
                    let tier = try await tiers.first(where: { $0.identifier == PatreonAPI.Tier.earlyAdopterTierID })
                    self.patreonTier = tier
                }
                catch
                {
                    Logger.main.error("Failed to fetch Patreon tiers. \(error.localizedDescription, privacy: .public)")
                }
            }
        }
    }
}

struct SupportDeltaView: View
{
    var showsCloseButton: Bool = false
    
    @State
    private var viewModel: ViewModel = ViewModel()
    
    @Environment(\.verticalSizeClass)
    private var verticalSizeClass
    
    @Environment(\.hostingController)
    private var hostingController
    
    @Environment(\.dismiss)
    private var dismiss
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 35) {
                if verticalSizeClass != .compact
                {
                    header
                }
                
                content
                
                FriendZonePatronsView()
                    .padding([.horizontal, .bottom])
                    .environment(\.managedObjectContext, DatabaseManager.shared.viewContext)
            }
        }
        .safeAreaInset(edge: .bottom, content: {
            footer
                .padding(.horizontal, 30)
                .ignoresSafeArea(edges: verticalSizeClass == .regular ? .horizontal : [])
        })
        .toolbar {
            if showsCloseButton
            {
                ToolbarItem(placement: .cancellationAction) {
                    if #available(iOS 26, *)
                    {
                        Button(role: .close) {
                            dismiss()
                        }
                    }
                    else
                    {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }
            }
            
            ToolbarItemGroup(placement: .secondaryAction) {
                if PurchaseManager.shared.supportsExternalPurchases
                {
                    if PatreonAPI.shared.isAuthenticated, let patreonAccount = DatabaseManager.shared.patreonAccount()
                    {
                        Button("Unlink “\(patreonAccount.name)”", systemImage: "person.fill", action: unlinkPatreonAccount)
                    }
                    else
                    {
                        Button("Link Patreon Account", systemImage: "person.fill", action: linkPatreonAccount)
                    }
                }
                
                if PurchaseManager.shared.supportsInAppPurchase
                {
                    Button("Restore Purchases", systemImage: "purchased", action: restorePurchases)
                }
                
                Link(destination: URL(string: "https://altstore.io/privacy")!) {
                    Label("Privacy Policy", systemImage: "hand.raised")
                }
                
                Link(destination: URL(string: "https://altstore.io/terms")!) {
                    Label("Terms of Use", systemImage: "book.pages")
                }
            }
        }
        .ignoresSafeArea(.all, edges: verticalSizeClass == .regular ? [.top, .leading, .trailing] : [.top])
        .interactiveDismissDisabled()
        .alert("Unable to Donate", isPresented: $viewModel.isShowingErrorAlert, presenting: viewModel.donateError, actions: { error in
            if #available(iOS 26, *)
            {
                Button(role: .confirm, action: {})
            }
            else
            {
                Button("OK", action: {})
            }
            
        }, message: { error in
            Text(error.localizedDescription)
        })
        .task {
            await viewModel.prepare()
        }
    }
    
    private var header: some View {
        Image(.donateHeader)
            .resizable()
            .scaledToFill()
            .listRowInsets(EdgeInsets())
            .offset(y: -5) // Make sure it goes completely to top of screen
    }
    
    @ViewBuilder
    private var content: some View {
        // Section Header
        VStack {
            Text("Become a Patron")
                .font(.largeTitle)
                .foregroundStyle(Color(.label))
                .bold()
            
            Text("Your support helps keep Delta free for everyone, and unlocks extra features as thanks.")
                .font(.callout)
                .foregroundStyle(.secondary)
            
            HStack {
                HStack(spacing: -4) {
                    Image(.riley)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 22, height: 22)
                        .clipShape(.circle)
                        .overlay(
                            Circle()
                                .stroke(.white, lineWidth: 1)
                            )
                    
                    Image(.shane)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 22, height: 22)
                        .clipShape(.circle)
                        .overlay(
                            Circle()
                                .stroke(.white, lineWidth: 1)
                            )
                        .zIndex(-10)
                }
                
                Text("Riley & Shane")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .bold()
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
        .padding(.top, verticalSizeClass == .compact ? 30 : -5) // Add 30pts margin in vertical compact environments
        
        // Perks
        VStack(spacing: 20) {
            ForEach(viewModel.perks) { perk in
                DonationPerkRow(perk: perk)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 30)
        .padding(.bottom, 15)
    }
    
    private var footer: some View {
        VStack(spacing: 15) {
            // Patreon
            if PurchaseManager.shared.supportsExternalPurchases
            {
                if let offering = viewModel.patreonTierOffering
                {
                    // Only show comparison price if both Patreon and IAP have the same currency.
                    let comparisonPrice = (offering.currency == viewModel.iapSubscription?.currency) ? viewModel.iapSubscription?.price : nil
                    DonateButton(service: .patreon, price: offering.price, currency: offering.currency,
                                 comparisonPrice: comparisonPrice, freeTrialLength: .init(weekOfMonth: 1)) {
                        donate(service: .patreon)
                    }
                }
                else
                {
                    DonateButton(service: .patreon, freeTrialLength: .init(weekOfMonth: 1))
                }
            }
            
            // In-App Purchase
            if PurchaseManager.shared.supportsInAppPurchase
            {
                if let iapSubscription = viewModel.iapSubscription
                {
                    DonateButton(service: .iap, price: iapSubscription.price, currency: iapSubscription.currency, comparisonPrice: nil) {
                        donate(service: .iap)
                    }
                }
                else
                {
                    DonateButton(service: .iap)
                }
            }
        }
    }
}

private extension SupportDeltaView
{
    func donate(service: PurchaseManager.Service)
    {
        Task<Void, Never> {
            do
            {
                switch service
                {
                case .patreon:
                    guard let tier = viewModel.patreonTier, let hostingController else { return }
                    
                    _ = try await PurchaseManager.shared.join(tier, presentingViewController: hostingController)
                    
                case .iap:
                    guard let subscription = viewModel.iapSubscription else { return }
                    
                    try await RevenueCatManager.shared.purchase(subscription)
                }
            }
            catch is CancellationError {}
            catch
            {
                Logger.main.error("Failed to perform donation for service \(service.localizedTitle, privacy: .public). \(error.localizedDescription, privacy: .public)")
                
                self.viewModel.donateError = error
                self.viewModel.isShowingErrorAlert = true
            }
        }
    }
    
    func linkPatreonAccount()
    {
        Task<Void, Never> {
            do
            {
                guard let hostingController else { return }
                try await PatreonAPI.shared.authenticate(presentingViewController: hostingController)
            }
            catch is CancellationError {}
            catch
            {
                Logger.main.error("Failed to link Patreon Account. \(error.localizedDescription, privacy: .public)")
                
                self.viewModel.donateError = error
                self.viewModel.isShowingErrorAlert = true
            }
        }
    }
    
    func unlinkPatreonAccount()
    {
        Task<Void, Never> {
            do
            {
                try await PatreonAPI.shared.signOut()
            }
            catch is CancellationError {}
            catch
            {
                Logger.main.error("Failed to sign out of Patreon Account. \(error.localizedDescription, privacy: .public)")
                
                self.viewModel.donateError = error
                self.viewModel.isShowingErrorAlert = true
            }
        }
    }
    
    func restorePurchases()
    {
        Task<Void, Never> {
            do
            {
                try await RevenueCatManager.shared.requestRestorePurchases()
            }
            catch is CancellationError {}
            catch
            {
                Logger.main.error("Failed to restore IAP purchases. \(error.localizedDescription, privacy: .public)")
                
                self.viewModel.donateError = error
                self.viewModel.isShowingErrorAlert = true
            }
        }
    }
}

private struct DonationPerkRow: View
{
    var perk: DonationPerk
    
    var body: some View {
        HStack(alignment: .center, spacing: 15) {
            Image(systemName: perk.iconName)
                .resizable()
                .scaledToFit()
                .frame(width: 35, height: 35)
                .foregroundStyle(Color(.deltaPurple))
            
            VStack(alignment: .leading) {
                Text(perk.title)
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text(perk.subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .multilineTextAlignment(.leading)
            // Fill the remaining width so the icon box stays pinned to the leading edge.
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.leading)
    }
}

private struct DonateButton: View
{
    var service: PurchaseManager.Service
    
    var price: Decimal?
    var currency: String?
    var comparisonPrice: Decimal? // In same currency as donation
    var freeTrialLength: DateComponents?
    
    var action: (() -> Void)?
    
    @Environment(\.colorScheme)
    private var colorScheme
    
    private static let formatter: DateComponentsFormatter = {
        let dateFormatter = DateComponentsFormatter()
        dateFormatter.allowedUnits = [.weekOfMonth, .month, .day, .year]
        dateFormatter.unitsStyle = .full
        return dateFormatter
    }()
    
    var body: some View {
        let buttonColor = (service == .iap ? Color(.label) : Color(.deltaPurple))
        let invertedColorScheme: ColorScheme = (colorScheme == .dark ? .light : .dark)
        
        let button = Button(action: { action?() }) {
            HStack {
                wordmark
                
                Spacer()
                
                priceLabel
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .colorScheme(service == .iap ? invertedColorScheme : .dark)
            .tint(nil)
        }
        .frame(maxWidth: .infinity)
        .buttonBorderShape(.capsule)
        
        ZStack {
            if #available(iOS 26, *)
            {
                button
                    .buttonStyle(.glassProminent)
                    .tint(buttonColor)
            }
            else
            {
                button
                    .buttonStyle(.plain)
                    .background {
                        Rectangle().fill(.regularMaterial)
                        Rectangle().fill(buttonColor)
                    }
                    .clipShape(.capsule)
                    .shadow(color: .gray.opacity(0.3), radius: 10) //TODO: Verify w/ Caroline
            }
        }
        .shadow(color: .black.opacity(0.1), radius: 30)
    }
    
    @ViewBuilder
    private var wordmark: some View {
        switch service
        {
        case .iap:
            // Single IAP image
            Image(service.imageResource)
                .resizable()
                .scaledToFit()
                .frame(height: 34)
                .foregroundStyle(Color(.label))
                .offset(y: -2) // Visually center the body of Apple and ignore leaf
            
        case .patreon:
            // Patreon logo + "Patreon" title
            HStack {
                Image(service.imageResource)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 26, height: 34)
                    .foregroundStyle(.white)
                
                VStack(alignment: .leading) {
                    Text("Patreon")
                        .font(.system(size: 16))
                        .bold()
                        
                    if let freeTrialLength, let formattedString = Self.formatter.string(from: freeTrialLength)
                    {
                        Text("\(formattedString) free")
                            .font(.system(size: 16))
                            .bold()
                            .foregroundStyle(.secondary)
                    }
                    else
                    {
                        Text("Riley + Shane")
                            .font(.system(size: 16))
                            .bold()
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var priceLabel: some View {
        if let price, let currency
        {
            let priceLabel = (
                Text(price, format: .currency(code: currency).precision(.fractionLength(0...2))).font(.title2).foregroundStyle(Color(.label)).bold() +
                Text(" / month").font(.subheadline).foregroundStyle(Color(.secondaryLabel))
            )
            
            if let comparisonPrice
            {
                ViewThatFits {
                    // Show comparison price if it can fit
                    HStack(alignment: .firstTextBaseline) {
                        Text(comparisonPrice, format: .currency(code: currency).precision(.fractionLength(0...2)))
                            .font(.subheadline)
                            .bold()
                            .foregroundStyle(.secondary)
                            .strikethrough(color: .secondary)
                        
                        priceLabel
                    }
                    
                    // Otherwise just show the price without comparison
                    priceLabel
                }
            }
            else
            {
                priceLabel
            }
        }
        else
        {
            ProgressView()
        }
    }
}

#Preview {
    NavigationStack {
        SupportDeltaView()
    }
}
