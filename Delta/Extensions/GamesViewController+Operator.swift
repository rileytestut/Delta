//
//  GamesViewController+Operator.swift
//  Delta
//
//  Created by Epilogue on 3/27/26.
//  Copyright © 2026 Epilogue. All rights reserved.
//

import Combine
import CoreData
import UIKit
import ObjectiveC.runtime

import DeltaCore
import DeltaFeatures
import OperatorKit

private var operatorOverlayKey: UInt8 = 0
private var operatorSlotObserverKey: UInt8 = 0

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
        self.startOperatorImportObserver()
        self.operatorOverlay.install(in: self.view, placeholderStackView: placeholderStackView)
    }

    func updateOperatorPlaceholderVisibility(sectionCount: Int, isLibraryHidden: Bool)
    {
        guard ExperimentalFeatures.shared.operatorDevice.isEnabled else { return }
        self.operatorOverlay.isPlaceholderVisible = (sectionCount == 0) || (self.isOperatorImportTransferring && isLibraryHidden)
    }

    var isOperatorImportTransferring: Bool
    {
        guard ExperimentalFeatures.shared.operatorDevice.isEnabled else { return false }
        if case .transferring = OperatorKitController.shared.slotState { return true }
        return false
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

    var operatorSlotCancellable: AnyCancellable? {
        get { objc_getAssociatedObject(self, &operatorSlotObserverKey) as? AnyCancellable }
        set { objc_setAssociatedObject(self, &operatorSlotObserverKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    func startOperatorImportObserver()
    {
        guard self.operatorSlotCancellable == nil else { return }
        self.operatorSlotCancellable = OperatorKitController.shared.$slotState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard case .imported = state else { return }
                self?.updateSections(animated: false)
                self?.switchToImportedOperatorCollection()
            }
    }

    func switchToImportedOperatorCollection()
    {
        guard let signature = OperatorKitController.shared.publishedSignature, !signature.isEmpty,
              let identifier = GameType(fileExtension: signature.romExtension)?.rawValue,
              let pageViewController = self.children.first(where: { $0 is UIPageViewController }) as? UIPageViewController
        else { return }

        let currentViewController = pageViewController.viewControllers?.first as? GameCollectionViewController
        guard currentViewController?.gameCollection?.identifier != identifier else { return }

        let fetchRequest = GameCollection.fetchRequest() as NSFetchRequest<GameCollection>
        let collectionCount = (try? DatabaseManager.shared.viewContext.count(for: fetchRequest)) ?? 0

        var target: (index: Int, viewController: GameCollectionViewController)?
        for index in 0..<(collectionCount + 2)
        {
            guard let viewController = self.viewControllerForIndex(index) else { break }
            guard viewController.gameCollection?.identifier == identifier else { continue }
            target = (index, viewController)
            break
        }
        guard let target else { return }

        let currentIndex = currentViewController.flatMap { self.indexForViewController($0) } ?? 0
        let direction: UIPageViewController.NavigationDirection = target.index > currentIndex ? .forward : .reverse

        pageViewController.setViewControllers([target.viewController], direction: direction, animated: true) { [weak self] _ in
            self?.updateSections(animated: false)
        }
        self.title = target.viewController.title
        if let collection = target.viewController.gameCollection
        {
            Settings.previousGameCollection = collection
        }
    }
}
