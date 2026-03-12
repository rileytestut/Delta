//
//  GamesViewController+Operator.swift
//  Delta
//
//  Created by Epilogue on 3/27/26.
//  Copyright © 2026 Epilogue. All rights reserved.
//

import UIKit
import ObjectiveC.runtime

import DeltaFeatures

private var operatorOverlayKey: UInt8 = 0

extension GamesViewController
{
    override func viewDidLayoutSubviews()
    {
        super.viewDidLayoutSubviews()
        guard ExperimentalFeatures.shared.operatorDevice.isEnabled else { return }
        self.operatorOverlay.layoutChanged()
    }

    func configureOperatorOverlay(placeholderStackView: UIStackView)
    {
        guard ExperimentalFeatures.shared.operatorDevice.isEnabled else { return }
        self.operatorOverlay.install(in: self.view, placeholderStackView: placeholderStackView)
    }

    func updateOperatorPlaceholderVisibility(sectionCount: Int)
    {
        guard ExperimentalFeatures.shared.operatorDevice.isEnabled else { return }
        self.operatorOverlay.isPlaceholderVisible = (sectionCount == 0)
    }
}

private extension GamesViewController
{
    var operatorOverlay: OperatorOverlayCoordinator {
        get {
            if let overlay = objc_getAssociatedObject(self, &operatorOverlayKey) as? OperatorOverlayCoordinator
            {
                return overlay
            }

            let overlay = OperatorOverlayCoordinator()
            objc_setAssociatedObject(self, &operatorOverlayKey, overlay, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            return overlay
        }
    }
}
