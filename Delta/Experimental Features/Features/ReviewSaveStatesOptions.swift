//
//  LinkSaveStatesOptions.swift
//  Delta
//
//  Created by Riley Testut on 8/7/23.
//  Copyright © 2023 Riley Testut. All rights reserved.
//

import SwiftUI

import DeltaFeatures

struct ReviewSaveStatesView: UIViewControllerRepresentable
{
    func makeUIViewController(context: Context) -> ReviewSaveStatesViewController
    {
        let viewController = ReviewSaveStatesViewController()
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: ReviewSaveStatesViewController, context: Context)
    {
    }
}

struct ReviewSaveStatesOptions
{
    @Option(name: "View Save States", detailView: { _ in ReviewSaveStatesView() })
    private var reviewSaveStates: String = "" // Hack until I figure out how to support Void properties...
}
