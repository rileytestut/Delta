//
//  GameCollectionViewController+Operator.swift
//  Delta
//
//  Created by Epilogue on 3/27/26.
//  Copyright © 2026 Epilogue. All rights reserved.
//

import Combine
import UIKit
import ObjectiveC.runtime

import DeltaFeatures
import OperatorKit

private var operatorCoordinatorKey: UInt8 = 0
private var operatorLaunchCoordinatorKey: UInt8 = 0
private var pendingLaunchGameKey: UInt8 = 0
private var slotStateCancellableKey: UInt8 = 0

extension GameCollectionViewController
{
    func startOperatorCoordinator()
    {
        guard ExperimentalFeatures.shared.operatorDevice.isEnabled else { return }

        let frc = self.dataSource.fetchedResultsController
        frc.delegate = nil
        let operatorDataSource = OperatorSlotDataSource(fetchedResultsController: frc)
        operatorDataSource.cellConfigurationHandler = self.dataSource.cellConfigurationHandler
        operatorDataSource.prefetchHandler = self.dataSource.prefetchHandler
        operatorDataSource.prefetchCompletionHandler = self.dataSource.prefetchCompletionHandler
        self.dataSource = operatorDataSource

        self.operatorCoordinator.start(collectionView: self.collectionView!, dataSource: operatorDataSource)
        self.operatorCoordinator.gameCollectionIdentifier = self.gameCollection?.identifier
    }

    func updateOperatorGameCollection()
    {
        guard ExperimentalFeatures.shared.operatorDevice.isEnabled else { return }
        self.operatorCoordinator.gameCollectionIdentifier = self.gameCollection?.identifier
    }

    func operatorCellSize(for width: CGFloat) -> CGSize
    {
        return self.operatorCoordinator.operatorCellSize(for: width)
    }

    func isOperatorSlotIndexPath(_ indexPath: IndexPath) -> Bool
    {
        guard let operatorDataSource = self.dataSource as? OperatorSlotDataSource else { return false }
        return operatorDataSource.isOperatorSlotIndexPath(indexPath)
    }

    func isOperatorStatusCell(_ cell: UICollectionViewCell) -> Bool
    {
        return cell is OperatorStatusCell
    }

    func isOperatorImportedGame(_ game: Game) -> Bool
    {
        return OperatorKitController.shared.importedGameIdentifier == game.identifier
    }

    func isOperatorImportInProgress(for game: Game) -> Bool
    {
        let controller = OperatorKitController.shared
        guard controller.importedGameIdentifier == game.identifier else { return false }
        if case .imported = controller.slotState { return false }
        return true
    }

    func deferLaunchIfOperatorImporting(_ game: Game) -> Bool
    {
        guard ExperimentalFeatures.shared.operatorDevice.isEnabled else { return false }

        if self.isOperatorImportInProgress(for: game)
        {
            self.pendingOperatorLaunchGame = game
            self.startOperatorLaunchObserver()
            return true
        }
        self.pendingOperatorLaunchGame = nil

        guard self.isOperatorImportedGame(game) else { return false }
        return self.operatorLaunchCoordinator.deferLaunchIfSaveUnverified(of: game)
    }
}

private extension GameCollectionViewController
{
    var operatorCoordinator: OperatorCollectionCoordinator {
        get {
            if let coordinator = objc_getAssociatedObject(self, &operatorCoordinatorKey) as? OperatorCollectionCoordinator
            {
                return coordinator
            }

            let coordinator = OperatorCollectionCoordinator()
            objc_setAssociatedObject(self, &operatorCoordinatorKey, coordinator, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            return coordinator
        }
    }

    var pendingOperatorLaunchGame: Game? {
        get { objc_getAssociatedObject(self, &pendingLaunchGameKey) as? Game }
        set { objc_setAssociatedObject(self, &pendingLaunchGameKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    var operatorLaunchCancellable: AnyCancellable? {
        get { objc_getAssociatedObject(self, &slotStateCancellableKey) as? AnyCancellable }
        set { objc_setAssociatedObject(self, &slotStateCancellableKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    var operatorLaunchCoordinator: OperatorLaunchCoordinator {
        get {
            if let coordinator = objc_getAssociatedObject(self, &operatorLaunchCoordinatorKey) as? OperatorLaunchCoordinator
            {
                return coordinator
            }

            let coordinator = OperatorLaunchCoordinator()
            coordinator.start(collectionViewController: self)
            objc_setAssociatedObject(self, &operatorLaunchCoordinatorKey, coordinator, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            return coordinator
        }
    }

    func startOperatorLaunchObserver()
    {
        guard self.operatorLaunchCancellable == nil else { return }
        self.operatorLaunchCancellable = OperatorKitController.shared.$slotState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in self?.launchPendingOperatorGameIfReady(state) }
    }

    func launchPendingOperatorGameIfReady(_ state: OperatorSlotState)
    {
        guard case .imported(let id) = state,
              let game = self.pendingOperatorLaunchGame, game.identifier == id
        else { return }
        self.pendingOperatorLaunchGame = nil

        DispatchQueue.main.async { [weak self] in
            guard let self, let collectionView = self.collectionView,
                  let indexPath = self.dataSource.fetchedResultsController.indexPath(forObject: game)
            else { return }
            self.collectionView(collectionView, didSelectItemAt: indexPath)
        }
    }
}
