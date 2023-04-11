//
//  OptionalProtocol.swift
//  Delta
//
//  Created by Riley Testut on 4/11/23.
//  Copyright © 2023 Riley Testut. All rights reserved.
//

import Foundation

protocol OptionalProtocol
{
    associatedtype Wrapped
    
    static var none: Self { get }
    
    static var wrappedType: Wrapped.Type { get }
}

extension Optional: OptionalProtocol
{
    static var wrappedType: Wrapped.Type { return Wrapped.self }
}
