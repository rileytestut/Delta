//
//  OnlineMultiplayer.swift
//  Delta
//
//  Created by Riley Testut on 12/13/24.
//  Copyright © 2024 Riley Testut. All rights reserved.
//

import SwiftUI
import SafariServices

import DeltaFeatures

private struct InstructionsWebView: UIViewControllerRepresentable
{
    func makeUIViewController(context: Context) -> SFSafariViewController
    {
        let faqURL = URL(string: "https://faq.deltaemulator.com/using-delta/online-multiplayer")!
        
        let viewController = SFSafariViewController(url: faqURL)
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context)
    {
    }
}

struct OnlineMultiplayerOptions
{
    @Option(name: "View Instructions on the Delta FAQ", detailView: { _ in InstructionsWebView() })
    var viewInstructions: String = ""
}
