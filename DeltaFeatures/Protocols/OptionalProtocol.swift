//
//  OptionalProtocol.swift
//  Delta
//
//  Created by Riley Testut on 4/11/23.
//  Copyright © 2023 Riley Testut. All rights reserved.
//

import Foundation

// Public so we can use as generic constraint.
public protocol OptionalProtocol
{
    associatedtype Wrapped
    
    static var none: Self { get }
    
    static var wrappedType: Wrapped.Type { get }
}

extension Optional: OptionalProtocol
{
    public static var wrappedType: Wrapped.Type { return Wrapped.self }
}
