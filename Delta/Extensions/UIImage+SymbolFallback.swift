//
//  UIImage+SymbolFallback.swift
//  Delta
//
//  Created by Riley Testut on 2/5/20.
//  Copyright © 2020 Riley Testut. All rights reserved.
//

import UIKit

extension UIImage
{
    convenience init?(symbolNameIfAvailable name: String)
    {
        if #available(iOS 13, *)
        {
            self.init(systemName: name)
        }
        else
        {
            return nil
        }
    }
}
