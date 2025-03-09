//
//  RetroAchievementsOptions.swift
//  Delta
//
//  Created by Riley Testut on 3/3/25.
//  Copyright © 2025 Riley Testut. All rights reserved.
//

import Foundation
import SwiftUI

import DeltaFeatures

struct RetroAchievementsOptions
{
    @Option(name: "Manage Account", detailView: { _ in AccountView() })
    var manageAccount: String = ""
}

private extension AccountView
{
    class ViewModel: ObservableObject
    {
        @Published
        var username: String
        
        @Published
        var password: String = ""
        
        @Published
        var authToken: String?
        
        init()
        {
            self.username = Keychain.shared.retroAchievementsUsername ?? ""
            self.authToken = Keychain.shared.retroAchievementsAuthToken
        }
    }
}

struct AccountView: View
{
    @StateObject
    private var viewModel = ViewModel()
    
    @State
    private var isSigningOut: Bool = false
    
    @State
    private var isShowingAuthError: Bool = false
    
    @State
    private var authError: Error?
    
    var body: some View {
        guard #available(iOS 15, *) else { return Text("RetroAchievements requires iOS 15 or later.") }
        
        return List {
            Section("Username") {
                TextField("Username", text: $viewModel.username)
                    .keyboardType(.default)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .disabled(viewModel.authToken != nil)
            }
            
            if viewModel.authToken == nil
            {
                Section("Password") {
                    SecureField("Password", text: $viewModel.password)
                        .onSubmit {
                            signIn()
                        }
                }
            }
            
            Section {
                if viewModel.authToken != nil
                {
                    Button("Sign Out", action: { isSigningOut = true })
                        .foregroundStyle(.red)
                }
                else
                {
                    Button("Sign In", action: signIn)
                        .disabled(viewModel.username.isEmpty || viewModel.password.isEmpty)
                }
            }
        }
        .confirmationDialog("Are you sure you'd like to sign out?", isPresented: $isSigningOut, titleVisibility: .visible) {
            Button("Sign Out", role: .destructive, action: signOut)
        }
        .textCase(.none) // I have NO idea why this is necessary...without it the buttons will *randomly* appear in all-caps
        .alert("Unable to Sign In", isPresented: $isShowingAuthError, presenting: authError) { error in
            Button("OK", role: .cancel) {}
        } message: { error in
            Text(verbatim: error.localizedDescription)
        }
    }
}

private extension AccountView
{
    func signIn()
    {
        Task<Void, Never> {
            do
            {
                _ = try await AchievementsManager.shared.authenticate(username: self.viewModel.username, password: self.viewModel.password)
                self.viewModel.authToken = Keychain.shared.retroAchievementsAuthToken
            }
            catch
            {
                self.authError = error
                self.isShowingAuthError = true
            }
        }
    }
    
    func signOut()
    {
        AchievementsManager.shared.signOut()
        
        self.viewModel.username = ""
        self.viewModel.password = ""
        self.viewModel.authToken = nil
    }
}
