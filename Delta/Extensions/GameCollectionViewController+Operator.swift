//
//  GameCollectionViewController+Operator.swift
//  Delta
//
//  Created by Epilogue on 3/27/26.
//  Copyright © 2026 Epilogue. All rights reserved.
//

import UIKit
import ObjectiveC.runtime

import DeltaFeatures
import OperatorKit

private var operatorCoordinatorKey: UInt8 = 0

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
}
