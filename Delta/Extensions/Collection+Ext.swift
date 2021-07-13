//
//  Collection+Ext.swift
//  Delta
//
//  Created by Ian Clawson on 7/12/21.
//  Copyright © 2021 Riley Testut. All rights reserved.
//

import Foundation

public extension Collection
{
    subscript (safe index: Index) -> Element?
    {
        return indices.contains(index) ? self[index] : nil
    }
}
