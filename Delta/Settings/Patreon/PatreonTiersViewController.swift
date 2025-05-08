//
//  PatreonTiersViewController.swift
//  Delta
//
//  Created by Riley Testut on 12/11/24.
//  Copyright © 2024 Riley Testut. All rights reserved.
//

import SwiftUI
import StoreKit

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
                String(localized: "Exclusive icons from our favorite indie designers")
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
extension PatreonTiersViewController
{
    private struct NaughtyWordError: LocalizedError
    {
        var errorDescription: String? {
            NSLocalizedString("This name is not allowed.", comment: "")
        }
    }
}

@available(iOS 17.5, *)
class PatreonTiersViewController: UIHostingController<PatreonTiersView>
{
    var completionHandler: ((Result<RevenueCatManager.Subscription, CancellationError>) -> Void)?
    
    private var isUpdatingRevenueCatPatrons: Bool = false
    
    private weak var confirmEditAction: UIAlertAction?
    
    private var editNameAction: UIAction!
    private var editEmailAction: UIAction!
    private var manageSubscriptionAction: UIAction!
    
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
        
        self.editNameAction = UIAction(title: NSLocalizedString("Change Name", comment: ""), image: UIImage(systemName: "person")) { [weak self] action in
            self?.editPatronName(action)
        }
        
        self.editEmailAction = UIAction(title: NSLocalizedString("Change Email", comment: ""), image: UIImage(systemName: "envelope")) { [weak self] action in
            self?.editPatronEmail(action)
        }
        
        self.manageSubscriptionAction = UIAction(title: NSLocalizedString("Manage Subscription", comment: ""), image: UIImage(systemName: "gear")) { [weak self] _ in
            self?.manageSubscription()
        }
        
        let restorePurchaseAction = UIAction(title: NSLocalizedString("Restore Purchase", comment: ""), image: UIImage(systemName: "arrow.clockwise")) { [weak self] _ in
            self?.restorePurchase()
        }
        
        let deferredMenuElement = UIDeferredMenuElement.uncached { [weak self] completion in
            guard let self else { return completion([]) }
            completion([self.editNameAction, self.editEmailAction, self.manageSubscriptionAction, restorePurchaseAction])
        }
        
        let moreMenu = UIMenu(title: "", children: [deferredMenuElement])
        
        let moreButton = UIBarButtonItem(image: UIImage(systemName: "ellipsis.circle"), style: .plain, target: nil, action: nil)
        moreButton.menu = moreMenu
        self.navigationItem.rightBarButtonItem = moreButton
        
        self.update()
    }
    
    @MainActor @preconcurrency required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // YOLO
    func process(_ subscription: RevenueCatManager.Subscription)
    {
        switch subscription
        {
        case .earlyAdopter: break
        case .communityMember: self.editPatronEmail(nil)
        case .friendZone: self.editPatronName(nil)
        }
        
        let alertController = UIAlertController(title: NSLocalizedString("Thanks for Supporting Us!", comment: ""),
                                                message: NSLocalizedString("You can now access patron-exclusive features like alternate app icons and Experimental Features.", comment: ""), preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default) { [weak self] _ in
            self?.update()
        })
        self.present(alertController, animated: true)
            
        self.update()
    }
}

@available(iOS 17.5, *)
private extension PatreonTiersViewController
{
    func update()
    {
        if let entitlement = RevenueCatManager.shared.entitlements[.discord], entitlement.isActive
        {
            self.editEmailAction.attributes.remove(.hidden)
        }
        else
        {
            self.editEmailAction.attributes.insert(.hidden)
        }
        
        if let entitlement = RevenueCatManager.shared.entitlements[.credits], entitlement.isActive
        {
            self.editNameAction.attributes.remove(.hidden)
        }
        else
        {
            self.editNameAction.attributes.insert(.hidden)
        }
        
        if RevenueCatManager.shared.hasBetaAccess
        {
            self.manageSubscriptionAction.attributes.remove(.hidden)
        }
        else
        {
            self.manageSubscriptionAction.attributes.insert(.hidden)
        }
    }
    
    @objc func cancel()
    {
        self.completionHandler?(.failure(CancellationError()))
    }
    
    @objc func manageSubscription()
    {
        guard let windowScene = self.view.window?.windowScene else { return }
        
        Task<Void, Never> {
            do
            {
                try await AppStore.showManageSubscriptions(in: windowScene, subscriptionGroupID: PurchaseManager.friendZoneSubscriptionGroupID)
            }
            catch
            {
                let alertController = UIAlertController(title: String(localized: "Unable to Manage Subscription"), error: error)
                self.present(alertController, animated: true)
            }
        }
    }
    
    @objc func restorePurchase()
    {        
        Task<Void, Never> {
            do
            {
                try await RevenueCatManager.shared.requestRestorePurchases()
            }
            catch is CancellationError
            {
                // Ignore
            }
            catch
            {
                let alertController = UIAlertController(title: NSLocalizedString("Unable to Restore Purchase", comment: ""), error: error)
                self.present(alertController, animated: true)
            }
        }
    }
    
    @IBAction func editPatronName(_ sender: UIAction?)
    {
        let alertTitle = (sender == nil) ? String(localized: "Thanks For Supporting Us!") : String(localized: "Edit Name")
        
        let alertController = UIAlertController(title: alertTitle, message: String(localized: "Please enter your full name so we can credit you on this page."), preferredStyle: .alert)
        alertController.addTextField { [weak self] textField in
            textField.textContentType = .name
            textField.autocapitalizationType = .words
            textField.autocorrectionType = .no
            textField.placeholder = String(localized: "Full Name")
            textField.returnKeyType = .done
            textField.enablesReturnKeyAutomatically = true
            textField.addTarget(self, action: #selector(PatreonTiersViewController.editTextFieldChanged(_:)), for: .editingChanged)
            
            if let displayName = RevenueCatManager.shared.displayName
            {
                textField.text = displayName
            }
        }
        
        let cancelTitle = (sender == nil) ? String(localized: "Maybe Later") : String(localized: "Cancel")
        let cancelAction = UIAlertAction(title: cancelTitle, style: .cancel)
        
        let editAction = UIAlertAction(title: String(localized: "Confirm"), style: .default) { [weak alertController] _ in
            guard let textField = alertController?.textFields?.first, let displayName = textField.text, !displayName.isEmpty else { return }
            
            Task<Void, Never> {
                do
                {
                    guard !displayName.containsProfanity else { throw NaughtyWordError() }
                    
                    try await RevenueCatManager.shared.setDisplayName(displayName)
                    
                    self.isUpdatingRevenueCatPatrons = true
                    // self.collectionView.reloadData()
                    
                    defer {
                        self.isUpdatingRevenueCatPatrons = false
                        
                        // Automatically reloads data due to didUpdatePatronsNotification.
                        // self.collectionView.reloadData()
                    }
                    
                    try await FriendZoneManager.shared.updateRevenueCatPatrons()
                }
                catch
                {
                    let alertController = UIAlertController(title: String(localized: "Unable to Update Display Name"), error: error)
                    self.present(alertController, animated: true)
                }
            }
        }
        self.confirmEditAction = editAction
        
        alertController.addAction(cancelAction)
        alertController.addAction(editAction)
        
        self.present(alertController, animated: true)
    }
    
    @IBAction func editPatronEmail(_ sender: UIAction?)
    {
        let alertTitle = (sender == nil) ? String(localized: "Thanks For Supporting Us!") : String(localized: "Edit Email")
        
        let alertController = UIAlertController(title: alertTitle, message: String(localized: "Please enter your email so we can send you an invitation to our Discord server."), preferredStyle: .alert)
        alertController.addTextField { [weak self] textField in
            textField.textContentType = .emailAddress
            textField.autocapitalizationType = .none
            textField.autocorrectionType = .no
            textField.placeholder = String(localized: "me@example.com")
            textField.returnKeyType = .done
            textField.enablesReturnKeyAutomatically = true
            textField.addTarget(self, action: #selector(PatreonTiersViewController.editTextFieldChanged(_:)), for: .editingChanged)
            
            if let emailAddress = RevenueCatManager.shared.emailAddress
            {
                textField.text = emailAddress
            }
        }
        
        let cancelTitle = (sender == nil) ? String(localized: "Maybe Later") : String(localized: "Cancel")
        let cancelAction = UIAlertAction(title: cancelTitle, style: .cancel)
        
        let editAction = UIAlertAction(title: String(localized: "Confirm"), style: .default) { [weak alertController] _ in
            guard let textField = alertController?.textFields?.first, let emailAddress = textField.text, !emailAddress.isEmpty else { return }
            
            Task<Void, Never> {
                do
                {
                    try await RevenueCatManager.shared.setEmailAddress(emailAddress)
                    
                    let alertController = UIAlertController(title: NSLocalizedString("Discord Invite Link", comment: ""), message: "https://discord.gg/QqmM3gPtbA", preferredStyle: .alert)
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("Copy to Clipboard", comment: ""), style: .default) { _ in
                        UIPasteboard.general.url = URL(string: "https://discord.gg/QqmM3gPtbA")
                    })
                    alertController.addAction(.cancel)
                    
                    self.present(alertController, animated: true)
                }
                catch
                {
                    let alertController = UIAlertController(title: String(localized: "Unable to Update Email"), error: error)
                    self.present(alertController, animated: true)
                }
            }
        }
        self.confirmEditAction = editAction
        
        alertController.addAction(cancelAction)
        alertController.addAction(editAction)
        
        self.present(alertController, animated: true)
    }
    
    @objc func editTextFieldChanged(_ sender: UITextField)
    {
        let text = sender.text ?? ""
        self.confirmEditAction?.isEnabled = !text.isEmpty
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
    
    @State
    private var warningSubscription: RevenueCatManager.Subscription?
    
    @State
    private var pendingSubscription: RevenueCatManager.Subscription?
    
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
        .sheet(item: $warningSubscription) { subscription in
            IAPScareScreen() { result in
                switch result
                {
                case .success: pendingSubscription = subscription
                case .failure: pendingSubscription = nil
                }
                
                warningSubscription = nil
            }
        }
        .onChange(of: pendingSubscription) { oldValue, newValue in
            guard let newValue else { return }
            purchase(newValue)
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
        Button(action: { warningSubscription = subscription }) {
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
            
            self.pendingSubscription = nil
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
