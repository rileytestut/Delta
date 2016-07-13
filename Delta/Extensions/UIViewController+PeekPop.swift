//
//  UIViewController+PeekPop.swift
//  Delta
//
//  Created by Riley Testut on 5/27/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import Foundation

extension UIViewController
{
    var isPreviewing: Bool
    {
        guard let presentationController = self.presentationController else { return false }
        return NSStringFromClass(presentationController.dynamicType).contains("PreviewPresentation")
    }
}
