//
//  IAPDisclosureSheet.swift
//  Delta
//
//  Created by Riley Testut on 9/22/26.
//  Copyright © 2026 Riley Testut. All rights reserved.
//

import SwiftUI

private extension IAPDisclosureSheet
{
    // Provided by Apple alongside the design specs.
    static let learnMoreURL = URL(string: "https://apps.apple.com/story/id1760810284")!
    
    // Metrics from the design specs
    enum Metrics
    {
        static let sheetMargin = 38.0
        static let titleTopMargin = 90.0
        static let sectionSpacing = 24.0
        
        static let bulletSpacing = 16.0
        static let bulletIconSize = 40.0
        static let bulletIconLeadingInset = 4.0
        static let bulletIconSpacing = 16.0
        
        static let checkboxSpacing = 8.0
        
        static let buttonSpacing = 14.0
        static let buttonHeight = 50.0
    }
}

struct IAPDisclosureSheet: View
{
    // Must exactly match the developer name shown on the App Store.
    var developerName: String = "Yvette Testut"
    
    var continueHandler: ((_ showNextTime: Bool) -> Void)?
    
    var cancelHandler: (() -> Void)?
    
    @State
    private var showNextTime: Bool = true
    
    @Environment(\.openURL)
    private var openURL
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("By continuing, you’ll be transacting with the developer and not Apple.")
                        .font(.title2)
                        .bold()
                        .foregroundStyle(.primary)
                        .padding(.top, Metrics.titleTopMargin)
                    
                    VStack(alignment: .leading, spacing: Metrics.bulletSpacing) {
                        bullet(image: "PersonBadgeCreditCardFill",
                               title: Text("External Accounts and Purchases"),
                               description: Text("Any accounts or purchases made in this transaction, including their privacy and security, will be managed by the developer “\(developerName)”."))
                        
                        bullet(image: "InfoCircleFill",
                               title: Text("Unavailable App Store Features"),
                               description: Text("You won’t use your App Store account, stored payment method, or other Apple-related features for this transaction. For refund requests, contact the developer."))
                    }
                    .padding(.top, Metrics.sectionSpacing)
                    
                    Button {
                        openURL(Self.learnMoreURL)
                    } label: {
                        Text("Learn More")
                            .font(.body)
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, Metrics.sectionSpacing)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Metrics.sheetMargin)
            }
            .scrollBounceBehavior(.basedOnSize)
            
            VStack(spacing: 0) {
                Button {
                    showNextTime.toggle()
                } label: {
                    HStack(spacing: Metrics.checkboxSpacing) {
                        if showNextTime
                        {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.blue)
                        }
                        else
                        {
                            Image(systemName: "circle")
                                .foregroundStyle(.secondary)
                        }
                        
                        Text("Show this next time")
                            .foregroundStyle(.primary)
                    }
                    .font(.body)
                    .imageScale(.large)
                }
                .buttonStyle(.plain)
                
                actionButton(Text("Continue")) {
                    continueHandler?(showNextTime)
                }
                .padding(.top, Metrics.bulletSpacing)
                
                actionButton(Text("Cancel")) {
                    cancelHandler?()
                }
                .padding(.top, Metrics.buttonSpacing)
            }
            .padding(.horizontal, Metrics.sheetMargin)
            .padding(.bottom, Metrics.sheetMargin)
        }
    }
}

private extension IAPDisclosureSheet
{
    func bullet(image: String, title: Text, description: Text) -> some View
    {
        HStack(alignment: .top, spacing: Metrics.bulletIconSpacing) {
            Image(image)
                .resizable()
                .frame(width: Metrics.bulletIconSize, height: Metrics.bulletIconSize)
                .padding(.leading, Metrics.bulletIconLeadingInset)
            
            VStack(alignment: .leading, spacing: 0) {
                title
                    .font(.body)
                    .bold()
                    .foregroundStyle(.primary)
                
                description
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    @ViewBuilder
    func actionButton(_ title: Text, action: @escaping () -> Void) -> some View
    {
        // Styled by hand rather than with .glass/.bordered so the capsule is exactly `buttonHeight` tall.
        Button(action: action) {
            let label = title
                .font(.headline)
                .foregroundStyle(.blue)
                .frame(maxWidth: .infinity, minHeight: Metrics.buttonHeight)

            if #available(iOS 26, *)
            {
                label.glassEffect(.regular, in: Capsule())
            }
            else
            {
                label.background(Color(uiColor: .quaternarySystemFill), in: Capsule())
            }
        }
        .buttonStyle(.plain)
        .contentShape(Capsule())
    }
}

#Preview("Sheet") {
    Color(uiColor: .systemGroupedBackground)
        .ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            IAPDisclosureSheet()
        }
}

#Preview("Dark Mode") {
    Color(uiColor: .systemGroupedBackground)
        .ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            IAPDisclosureSheet()
        }
        .preferredColorScheme(.dark)
}

#Preview("Content") {
    IAPDisclosureSheet()
}
