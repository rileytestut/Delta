//
//  CheatProtocol.swift
//  DeltaCore
//
//  Created by Riley Testut on 5/19/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import Foundation

public protocol CheatProtocol
{
    var code: String { get }
    var type: CheatType { get }
}
