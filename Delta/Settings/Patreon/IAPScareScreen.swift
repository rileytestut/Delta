//
//  IAPScareScreen.swift
//  Delta
//
//  Created by Riley Testut on 5/8/25.
//  Copyright © 2025 Riley Testut. All rights reserved.
//

import SwiftUI

@available(iOS 17.5, *)
struct IAPScareScreen: View
{
    var completionHandler: ((Result<Void, CancellationError>) -> Void)?
    
    var body: some View {
        VStack(alignment: .leading) {
            Label {
                Text("Delta").font(.headline)
            } icon: {
                Image("AppIcon", bundle: Bundle(for: PurchaseManager.self))
                    .resizable()
                    .frame(width: 30, height: 30)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            }
            .labelStyle(.titleAndIcon)
            .padding()
            
            VStack {
                ScrollView {
                    VStack(spacing: 30) {
                        VStack(spacing: 15) {
                            Text("You’re about to use Apple’s In-App Purchase system.\nPatreon is not responsible for the privacy or security of purchases made with In-App Purchase.")
                                .font(.largeTitle)
                                .bold()
                            
                            Text("Any accounts or purchases made outside of Patreon will be managed by the company “Apple, Inc.”. Your Patreon account, stored payment method, and related features, such as subscription management and refund requests, will not be available. Patreon can't verify any pricing or promotions offered by the company.")
                        }
                        .multilineTextAlignment(.center)
                        
                        Button("Learn More", action: learnMore)
                    }
                }
                
                Spacer()
                
                VStack(spacing: 5) {
                    Button(action: `continue`) {
                        Text("Continue")
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                    }
                    
                    Button(action: cancel) {
                        Text("Cancel")
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                    }
                }
                .bold()
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle(radius: 15))
                .frame(minWidth: 0, maxWidth: .infinity)
            }
            .padding(.horizontal)
        }
        .frame(minHeight: 0, maxHeight: .infinity, alignment: .top)
    }
}

@available(iOS 17.5, *)
private extension IAPScareScreen
{
    func learnMore()
    {
        let url = URL(string: "https://fingfx.thomsonreuters.com/gfx/legaldocs/znpnjodxapl/Epic%20-%20Apple%20contempt%20order%20-%20Gonzalez%20Rogers%20-%2020250430.pdf")!
        UIApplication.shared.open(url, options: [:])
    }
    
    func `continue`()
    {
        self.completionHandler?(.success(()))
    }
    
    func cancel()
    {
        self.completionHandler?(.failure(CancellationError()))
    }
}

@available(iOS 17.5, *)
#Preview {
    Text("Hello World")
        .sheet(isPresented: .constant(true)) {
            NavigationView {
                IAPScareScreen()
            }
        }
}
