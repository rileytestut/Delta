//
//  AppDelegate+Operator.swift
//  Delta
//
//  Created by Epilogue on 3/27/26.
//  Copyright © 2026 Epilogue. All rights reserved.
//

import ObjectiveC.runtime

import DeltaFeatures

private var operatorFacadeKey: UInt8 = 0

extension AppDelegate
{
    func startOperator()
    {
        guard ExperimentalFeatures.shared.operatorDevice.isEnabled else { return }

        DispatchQueue.main.async {
            self.operatorFacade.start()
        }
    }

    func handleOperatorDatabaseReady()
    {
        guard ExperimentalFeatures.shared.operatorDevice.isEnabled else { return }
        self.operatorFacade.onDatabaseReady()
    }
}

private extension AppDelegate
{
    var operatorFacade: DeltaOperatorFacade {
        get {
            if let facade = objc_getAssociatedObject(self, &operatorFacadeKey) as? DeltaOperatorFacade
            {
                return facade
            }

            let facade = DeltaOperatorFacade()
            objc_setAssociatedObject(self, &operatorFacadeKey, facade, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            return facade
        }
    }
}
